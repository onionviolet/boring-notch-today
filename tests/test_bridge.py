import datetime as dt
import json
import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "scripts"))
import today_bridge


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = pathlib.Path(self.temp.name)
        self.environment = mock.patch.dict(os.environ, {"HOME": str(self.home)})
        self.environment.start()
        self.base = {
            "schemaVersion": 1,
            "generatedAt": today_bridge.now_string(),
            "rows": [],
            "anki": {"status": "unavailable"},
            "actions": [],
        }

    def tearDown(self):
        self.environment.stop()
        self.temp.cleanup()

    def test_status_and_payload_are_private_and_bounded(self):
        today_bridge.publish_payload(self.base)
        today_bridge.write_bridge_status("connected")
        root, payload, _, status = today_bridge.storage_paths()
        self.assertEqual(root.stat().st_mode & 0o777, 0o700)
        self.assertEqual(payload.stat().st_mode & 0o777, 0o600)
        self.assertEqual(status.stat().st_mode & 0o777, 0o600)
        self.assertEqual(today_bridge.bridge_summary()["payload"]["rowCount"], 0)

    def test_heartbeat_preserves_last_publish_time(self):
        published_at = "2026-09-15T04:00:00Z"
        today_bridge.write_bridge_status("connected", last_publish_at=published_at)
        today_bridge.write_bridge_status("connected")
        _, _, _, status = today_bridge.storage_paths()
        self.assertEqual(today_bridge.read_bounded_json(status, today_bridge.MAX_STATUS_BYTES)["lastPublishAt"], published_at)

    def test_only_one_heartbeat_writer_leads_at_a_time(self):
        first = today_bridge.try_acquire_heartbeat_leader()
        self.assertIsNotNone(first)
        self.assertIsNone(today_bridge.try_acquire_heartbeat_leader())
        today_bridge.release_heartbeat_leader(first)
        replacement = today_bridge.try_acquire_heartbeat_leader()
        self.assertIsNotNone(replacement)
        today_bridge.release_heartbeat_leader(replacement)

    def test_refresh_requires_fixed_schema_and_matching_ack(self):
        root, payload, refresh, _ = today_bridge.storage_paths()
        root.mkdir(parents=True, mode=0o700)
        request = {
            "schemaVersion": 1,
            "id": "ff4e555e-3c43-4d4a-8c16-d3e7652ad181",
            "requestedAt": today_bridge.now_string(),
            "source": "Boring Notch Today",
        }
        today_bridge.atomic_write(refresh, json.dumps(request).encode(), maximum=today_bridge.MAX_STATUS_BYTES)
        self.assertEqual(today_bridge.read_refresh_request(), request)
        self.assertFalse(today_bridge.acknowledge_refresh("00000000-0000-0000-0000-000000000000"))
        self.assertTrue(refresh.exists())
        with self.assertRaises(ValueError):
            today_bridge.publish_payload(self.base, refresh_request_id="00000000-0000-0000-0000-000000000000")
        self.assertFalse(payload.exists())
        today_bridge.publish_payload(self.base, refresh_request_id=request["id"])
        self.assertFalse(refresh.exists())

    def test_status_sanitizes_a_malformed_existing_payload(self):
        root, payload, _, _ = today_bridge.storage_paths()
        root.mkdir(parents=True, mode=0o700)
        payload.write_text("not json")
        payload.chmod(0o600)
        summary = today_bridge.bridge_summary()
        self.assertFalse(summary["payloadValid"])
        self.assertIsNone(summary["payload"])
        self.assertNotIn("not json", json.dumps(summary))

    def test_symlink_and_future_payload_are_rejected(self):
        root, payload, _, _ = today_bridge.storage_paths()
        root.mkdir(parents=True, mode=0o700)
        target = self.home / "elsewhere"
        target.write_text("x")
        payload.symlink_to(target)
        with self.assertRaises(ValueError):
            today_bridge.publish_payload(self.base)

        payload.unlink()
        future = {
            **self.base,
            "generatedAt": (dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
        }
        with self.assertRaises(ValueError):
            today_bridge.publish_payload(future)


if __name__ == "__main__":
    unittest.main()
