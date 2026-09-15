#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp>=2,<3"]
# ///
"""Narrow stdio MCP server for validated Boring Notch Today snapshots."""

from __future__ import annotations

import atexit
import threading
from typing import Any

from mcp.server import MCPServer

from today_bridge import (
    bridge_summary,
    now_string,
    publish_payload,
    read_refresh_request,
    release_heartbeat_leader,
    try_acquire_heartbeat_leader,
    write_bridge_status,
)

mcp = MCPServer(
    "Boring Notch Today",
    instructions=(
        "The planning vault remains canonical. Use this server only to read bounded refresh intent and publish "
        "schema-v1 display snapshots from sources the current task is authorized to read. Never infer or write "
        "task completion. When answering a refresh request, pass its exact ID to publish_today."
    ),
)


@mcp.tool()
def publish_today(payload: dict[str, Any], refresh_request_id: str | None = None) -> dict[str, Any]:
    """Publish one schema-v1 Today snapshot; optionally acknowledge its refresh request."""
    ensure_heartbeat()
    try:
        write_bridge_status("refreshing")
        publish_payload(payload, refresh_request_id=refresh_request_id)
        published_at = now_string()
        write_bridge_status("connected", last_publish_at=published_at)
        return {"ok": True, "publishedAt": published_at}
    except Exception:
        try:
            write_bridge_status("error")
        except Exception:
            pass
        return {"ok": False, "error": "The bounded Today payload was rejected."}


@mcp.tool()
def today_status() -> dict[str, Any]:
    """Return sanitized payload metadata and any bounded pending refresh request."""
    ensure_heartbeat()
    return bridge_summary()


@mcp.tool()
def pending_today_refresh() -> dict[str, Any]:
    """Return the current bounded refresh request, if one exists."""
    ensure_heartbeat()
    request = read_refresh_request()
    return {"pending": request is not None, "request": request}


@mcp.resource("boring-notch://today/status")
def today_status_resource() -> str:
    """Sanitized JSON status for the local Today bridge."""
    import json

    ensure_heartbeat()
    return json.dumps(bridge_summary(), separators=(",", ":"))


class Heartbeat:
    def __init__(self) -> None:
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self._run, name="today-mcp-heartbeat", daemon=True)
        self.started = False
        self.lock = threading.Lock()
        self.leader_fd: int | None = None

    def start(self) -> None:
        with self.lock:
            if self.started:
                return
            self.started = True
            self.thread.start()

    def _run(self) -> None:
        while not self.stop_event.is_set():
            if self.leader_fd is None:
                try:
                    self.leader_fd = try_acquire_heartbeat_leader()
                except Exception:
                    self.leader_fd = None
            if self.leader_fd is not None:
                try:
                    write_bridge_status("connected")
                except Exception:
                    pass
            self.stop_event.wait(5)

    def stop(self) -> None:
        if not self.started:
            return
        self.stop_event.set()
        self.thread.join(timeout=1)
        if self.leader_fd is not None:
            release_heartbeat_leader(self.leader_fd)
            self.leader_fd = None


heartbeat = Heartbeat()


def ensure_heartbeat() -> None:
    heartbeat.start()


if __name__ == "__main__":
    atexit.register(heartbeat.stop)
    heartbeat.start()
    mcp.run()
