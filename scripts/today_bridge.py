"""Shared, bounded storage contract for the Boring Notch Today bridge."""

from __future__ import annotations

import datetime as dt
import fcntl
import json
import os
import pathlib
import re
import stat
import tempfile
import urllib.parse
import uuid
from contextlib import contextmanager
from typing import Any

MAX_PAYLOAD_BYTES = 64 * 1024
MAX_STATUS_BYTES = 4 * 1024
MAX_ACTIONS = 3
MAX_TEXT = 500
BRIDGE_STALE_SECONDS = 15
_KEEP_LAST_PUBLISH = object()
RFC3339 = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")
ROOT_KEYS = {"schemaVersion", "generatedAt", "rows", "next", "protected", "start", "anki", "actions"}
ROW_KEYS = {"id", "work", "purpose", "studyMethod", "doneWhen", "time", "whyNow", "basis"}
ANKI_KEYS = {"status", "reviewedToday", "newCards"}
ACTION_KEYS = {"id", "label", "kind", "url"}
REQUIRED_ROW_KEYS = ("id", "work", "purpose", "studyMethod", "doneWhen", "time", "whyNow", "basis")


def storage_paths() -> tuple[pathlib.Path, pathlib.Path, pathlib.Path, pathlib.Path]:
    root = pathlib.Path.home() / "Library/Application Support/boring.notch/Today"
    return root, root / "payload.json", root / "refresh-request.json", root / "bridge-status.json"


def now_string() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def invalid(message: str) -> None:
    raise ValueError(message)


def bounded_text(value: Any, name: str) -> None:
    if not isinstance(value, str) or not value.strip() or len(value) > MAX_TEXT:
        invalid(f"invalid {name}")


def reject_unknown(value: dict[str, Any], allowed: set[str], name: str) -> None:
    unknown = set(value) - allowed
    if unknown:
        invalid(f"unknown {name} field")


def validate_payload(data: Any, *, now: dt.datetime | None = None) -> dict[str, Any]:
    if not isinstance(data, dict) or data.get("schemaVersion") != 1:
        invalid("schemaVersion must be 1")
    reject_unknown(data, ROOT_KEYS, "payload")
    if not {"generatedAt", "rows", "actions"}.issubset(data):
        invalid("payload is missing required fields")
    try:
        generated = data["generatedAt"]
        if not isinstance(generated, str) or not RFC3339.fullmatch(generated):
            invalid("generatedAt must include time and timezone")
        generated_date = dt.datetime.fromisoformat(generated.replace("Z", "+00:00"))
        if generated_date > (now or dt.datetime.now(dt.timezone.utc)) + dt.timedelta(minutes=5):
            invalid("generatedAt is too far in the future")
    except (TypeError, ValueError):
        invalid("generatedAt must be ISO-8601")
    rows = data["rows"]
    if not isinstance(rows, list) or len(rows) > 5:
        invalid("rows must contain zero to five entries")
    for row in rows:
        if not isinstance(row, dict):
            invalid("each row must be an object")
        reject_unknown(row, ROW_KEYS, "row")
        for key in REQUIRED_ROW_KEYS:
            bounded_text(row.get(key), f"row.{key}")
        if row["basis"] not in ("OFFICIAL", "PLAN", "INFERENCE"):
            invalid("row.basis is invalid")
    if len({row["id"] for row in rows}) != len(rows):
        invalid("row ids must be unique")
    for key in ("next", "protected", "start"):
        if key in data and data[key] is not None:
            bounded_text(data[key], key)
    anki = data.get("anki")
    if anki is not None:
        if not isinstance(anki, dict):
            invalid("anki must be an object")
        reject_unknown(anki, ANKI_KEYS, "anki")
        if anki.get("status") not in ("available", "unavailable"):
            invalid("anki.status is invalid")
        counts = (anki.get("reviewedToday"), anki.get("newCards"))
        if anki["status"] == "available" and any(type(value) is not int or value < 0 for value in counts):
            invalid("available Anki requires nonnegative integer counts")
        if anki["status"] == "unavailable" and any(value is not None for value in counts):
            invalid("unavailable Anki must omit counts")
    actions = data["actions"]
    if not isinstance(actions, list) or len(actions) > MAX_ACTIONS:
        invalid("actions must contain zero to three entries")
    for action in actions:
        if not isinstance(action, dict):
            invalid("each action must be an object")
        reject_unknown(action, ACTION_KEYS, "action")
        for key in ("id", "label", "kind"):
            bounded_text(action.get(key), f"action.{key}")
        url, kind = action.get("url"), action["kind"]
        if kind == "source":
            bounded_text(url, "action.url")
        parsed = urllib.parse.urlsplit(url) if isinstance(url, str) else None
        if kind == "source" and (
            parsed is None
            or parsed.scheme != "https"
            or not parsed.hostname
            or parsed.username is not None
            or parsed.password is not None
        ):
            invalid("source actions require safe https")
        if kind == "itembank" and url is not None:
            invalid("itembank actions do not accept a URL")
        if kind not in ("source", "itembank"):
            invalid("action.kind is invalid")
    if len({action["id"] for action in actions}) != len(actions):
        invalid("action ids must be unique")
    encoded = json.dumps(data, separators=(",", ":"), ensure_ascii=False).encode()
    if len(encoded) > MAX_PAYLOAD_BYTES:
        invalid("payload exceeds 64 KiB")
    return data


def _reject_unsafe_storage(path: pathlib.Path, *, regular_file: bool = False) -> None:
    try:
        info = path.lstat()
    except FileNotFoundError:
        return
    if stat.S_ISLNK(info.st_mode) or info.st_uid != os.getuid():
        invalid("refusing unsafe Today storage")
    if regular_file and (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1):
        invalid("refusing unsafe Today file")


def ensure_storage() -> pathlib.Path:
    root, payload, refresh, status_path = storage_paths()
    _reject_unsafe_storage(root.parent)
    _reject_unsafe_storage(root)
    for path in (payload, refresh, status_path):
        _reject_unsafe_storage(path, regular_file=True)
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    root.chmod(0o700)
    return root


def atomic_write(path: pathlib.Path, data: bytes, *, maximum: int) -> None:
    if len(data) > maximum:
        invalid("bridge record exceeds size limit")
    root = ensure_storage()
    if path.parent != root:
        invalid("bridge path is not allowed")
    _reject_unsafe_storage(path, regular_file=True)
    temp_path: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=root, prefix=f"{path.stem}.", delete=False) as handle:
            temp_path = pathlib.Path(handle.name)
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        temp_path.chmod(0o600)
        os.replace(temp_path, path)
        directory_fd = os.open(root, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if temp_path is not None and temp_path.exists():
            temp_path.unlink()


def _open_lock_file(name: str) -> int:
    root = ensure_storage()
    path = root / name
    flags = os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags, 0o600)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
            invalid("refusing unsafe Today lock")
        os.fchmod(fd, 0o600)
        return fd
    except Exception:
        os.close(fd)
        raise


@contextmanager
def bridge_status_lock():
    fd = _open_lock_file(".bridge-status.lock")
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def try_acquire_heartbeat_leader() -> int | None:
    """Hold the returned descriptor for as long as this server owns heartbeat writes."""
    fd = _open_lock_file(".heartbeat.lock")
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fd
    except BlockingIOError:
        os.close(fd)
        return None


def release_heartbeat_leader(fd: int) -> None:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)


def publish_payload(data: Any, *, refresh_request_id: str | None = None) -> pathlib.Path:
    validated = validate_payload(data)
    if refresh_request_id is not None:
        request = read_refresh_request()
        if request is None or request["id"] != refresh_request_id:
            invalid("refresh request does not match")
    _, payload, _, _ = storage_paths()
    encoded = json.dumps(validated, separators=(",", ":"), ensure_ascii=False).encode()
    atomic_write(payload, encoded, maximum=MAX_PAYLOAD_BYTES)
    if refresh_request_id is not None:
        acknowledge_refresh(refresh_request_id)
    return payload


def read_bounded_json(path: pathlib.Path, maximum: int) -> Any | None:
    if not path.exists():
        return None
    _reject_unsafe_storage(path, regular_file=True)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1 or info.st_size > maximum:
            invalid("unsafe bridge record")
        raw = os.read(fd, maximum + 1)
    finally:
        os.close(fd)
    if len(raw) > maximum:
        invalid("bridge record exceeds size limit")
    return json.loads(raw)


def validate_refresh_request(data: Any) -> dict[str, str]:
    if not isinstance(data, dict) or set(data) != {"schemaVersion", "id", "requestedAt", "source"}:
        invalid("invalid refresh request")
    if data["schemaVersion"] != 1 or data["source"] != "Boring Notch Today":
        invalid("invalid refresh request")
    try:
        uuid.UUID(data["id"])
    except (ValueError, TypeError, AttributeError):
        invalid("invalid refresh request id")
    bounded_text(data["requestedAt"], "requestedAt")
    if not RFC3339.fullmatch(data["requestedAt"]):
        invalid("invalid refresh request timestamp")
    return data


def read_refresh_request() -> dict[str, str] | None:
    _, _, refresh, _ = storage_paths()
    data = read_bounded_json(refresh, MAX_STATUS_BYTES)
    return None if data is None else validate_refresh_request(data)


def acknowledge_refresh(request_id: str) -> bool:
    _, _, refresh, _ = storage_paths()
    request = read_refresh_request()
    if request is None or request["id"] != request_id:
        return False
    _reject_unsafe_storage(refresh, regular_file=True)
    refresh.unlink()
    return True


def write_bridge_status(
    state: str,
    *,
    last_publish_at: str | None | object = _KEEP_LAST_PUBLISH,
) -> None:
    if state not in {"connected", "refreshing", "error", "disconnected"}:
        invalid("invalid bridge state")
    root, _, _, status_path = storage_paths()
    try:
        pending = read_refresh_request()
    except (OSError, ValueError, json.JSONDecodeError):
        pending = None
    with bridge_status_lock():
        if last_publish_at is _KEEP_LAST_PUBLISH:
            preserved_publish_at = None
            try:
                previous = read_bounded_json(status_path, MAX_STATUS_BYTES)
                candidate = previous.get("lastPublishAt") if isinstance(previous, dict) else None
                if candidate is None or (isinstance(candidate, str) and RFC3339.fullmatch(candidate)):
                    preserved_publish_at = candidate
            except (OSError, ValueError, json.JSONDecodeError):
                pass
            effective_publish_at = preserved_publish_at
        else:
            effective_publish_at = last_publish_at

        body = {
            "schemaVersion": 1,
            "state": state,
            "updatedAt": now_string(),
            "lastPublishAt": effective_publish_at,
            "refreshRequestId": pending["id"] if pending else None,
        }
        encoded = json.dumps(body, separators=(",", ":"), ensure_ascii=False).encode()
        if status_path.parent != root:
            invalid("bridge path is not allowed")
        atomic_write(status_path, encoded, maximum=MAX_STATUS_BYTES)


def bridge_summary() -> dict[str, Any]:
    _, payload_path, _, _ = storage_paths()
    try:
        request = read_refresh_request()
        refresh_error = False
    except (OSError, ValueError, json.JSONDecodeError):
        request = None
        refresh_error = True
    try:
        payload = read_bounded_json(payload_path, MAX_PAYLOAD_BYTES)
        if payload is not None:
            payload = validate_payload(payload)
        payload_valid = True
    except (OSError, ValueError, json.JSONDecodeError):
        payload = None
        payload_valid = False
    return {
        "connected": True,
        "pendingRefresh": request,
        "refreshRequestInvalid": refresh_error,
        "payloadValid": payload_valid,
        "payload": None if payload is None else {"generatedAt": payload["generatedAt"], "rowCount": len(payload["rows"])},
    }
