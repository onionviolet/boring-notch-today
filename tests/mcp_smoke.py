"""End-to-end stdio MCP smoke test. Run with: uv run --with 'mcp>=2,<3' python tests/mcp_smoke.py"""

import asyncio
import datetime as dt
import json
import os
import pathlib
import tempfile
import uuid

from mcp import Client, StdioServerParameters


async def main() -> None:
    repository = pathlib.Path(__file__).parents[1]
    with tempfile.TemporaryDirectory() as home:
        parameters = StdioServerParameters(
            command="uv",
            args=["run", str(repository / "scripts/boring-notch-today-mcp.py")],
            cwd=repository,
            env={"HOME": home, "PATH": os.environ["PATH"], "UV_CACHE_DIR": os.environ.get("UV_CACHE_DIR", str(pathlib.Path.home() / ".cache/uv"))},
        )
        async with Client(parameters) as client:
            listed = await client.list_tools()
            names = {tool.name for tool in listed.tools}
            assert names == {"publish_today", "today_status", "pending_today_refresh"}

            payload = {
                "schemaVersion": 1,
                "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
                "rows": [],
                "anki": {"status": "unavailable"},
                "actions": [],
            }
            result = await client.call_tool("publish_today", {"payload": payload})
            assert result.structured_content["ok"] is True
            today_root = pathlib.Path(home) / "Library/Application Support/boring.notch/Today"
            assert (today_root / "payload.json").exists()

            request_id = str(uuid.uuid4())
            request = {
                "schemaVersion": 1,
                "id": request_id,
                "requestedAt": payload["generatedAt"],
                "source": "Boring Notch Today",
            }
            (today_root / "refresh-request.json").write_text(json.dumps(request))
            os.chmod(today_root / "refresh-request.json", 0o600)
            pending = await client.call_tool("pending_today_refresh", {})
            assert pending.structured_content["request"]["id"] == request_id
            mismatch = await client.call_tool("publish_today", {"payload": payload, "refresh_request_id": str(uuid.uuid4())})
            assert mismatch.structured_content["ok"] is False
            assert (today_root / "refresh-request.json").exists()
            result = await client.call_tool("publish_today", {"payload": payload, "refresh_request_id": request_id})
            assert result.structured_content["ok"] is True
            assert not (today_root / "refresh-request.json").exists()
    print("MCP smoke test passed")


if __name__ == "__main__":
    asyncio.run(main())
