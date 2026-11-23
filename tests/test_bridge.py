import datetime as dt
import fcntl
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

    def create_refresh(self):
        _, _, refresh, _ = today_bridge.storage_paths()
        request = {
            "schemaVersion": 1,
            "id": "ff4e555e-3c43-4d4a-8c16-d3e7652ad181",
            "requestedAt": today_bridge.now_string(),
            "source": "Boring Notch Today",
        }
        today_bridge.atomic_write(refresh, json.dumps(request).encode(), maximum=today_bridge.MAX_STATUS_BYTES)
        return request

    def test_refresh_requires_fixed_schema_and_matching_ack(self):
        _, payload, refresh, _ = today_bridge.storage_paths()
        request = self.create_refresh()
        self.assertEqual(today_bridge.read_refresh_request(), request)
        self.assertFalse(today_bridge.acknowledge_refresh("00000000-0000-0000-0000-000000000000"))
        self.assertTrue(refresh.exists())
        with self.assertRaises(ValueError):
            today_bridge.publish_payload(self.base, refresh_request_id="00000000-0000-0000-0000-000000000000")
        self.assertFalse(payload.exists())
        today_bridge.publish_payload(self.base, refresh_request_id=request["id"])
        self.assertFalse(refresh.exists())

    def test_refresh_validation_rejects_impossible_dates_and_noninteger_versions(self):
        request = self.create_refresh()
        for changed in (
            {"schemaVersion": True}, {"schemaVersion": 1.0},
            {"requestedAt": "2026-02-30T12:00:00Z"},
            {"requestedAt": "2026-11-18T12:00:00+01:60"},
            {"id": request["id"].replace("-", "")},
        ):
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                today_bridge.validate_refresh_request({**request, **changed})
        fractional = {**request, "requestedAt": "2026-11-18T12:00:00.12+05:30"}
        self.assertEqual(today_bridge.validate_refresh_request(fractional), fractional)

    def test_request_lock_is_held_through_write_and_unlink(self):
        root, payload, refresh, _ = today_bridge.storage_paths()
        request = self.create_refresh()
        original_write = today_bridge.atomic_write
        original_unlink = pathlib.Path.unlink

        def assert_locked():
            with (root / ".refresh-request.lock").open("rb") as fd:
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)

        def write(path, data, *, maximum):
            self.assertEqual(path, payload)
            assert_locked()
            original_write(path, data, maximum=maximum)

        def unlink(path, *args, **kwargs):
            if path == refresh:
                assert_locked()
            original_unlink(path, *args, **kwargs)

        with mock.patch.object(today_bridge, "atomic_write", side_effect=write), \
             mock.patch.object(pathlib.Path, "unlink", new=unlink):
            today_bridge.publish_payload(self.base, refresh_request_id=request["id"])

        replacement = self.create_refresh()
        replacement["id"] = "00000000-0000-0000-0000-000000000001"
        today_bridge.atomic_write(refresh, json.dumps(replacement).encode(), maximum=today_bridge.MAX_STATUS_BYTES)
        with self.assertRaises(ValueError):
            today_bridge.publish_payload(self.base, refresh_request_id=request["id"])
        self.assertEqual(today_bridge.read_refresh_request(), replacement)

    def test_can_retry_acknowledgement_after_a_published_snapshot(self):
        _, payload, refresh, _ = today_bridge.storage_paths()
        request = self.create_refresh()
        original_unlink = pathlib.Path.unlink

        def unlink(path, *args, **kwargs):
            if path == refresh:
                raise PermissionError("test acknowledgement failure")
            original_unlink(path, *args, **kwargs)

        with mock.patch.object(pathlib.Path, "unlink", new=unlink):
            with self.assertRaises(today_bridge.RefreshAcknowledgementError):
                today_bridge.publish_payload(self.base, refresh_request_id=request["id"])
        self.assertEqual(json.loads(payload.read_text()), self.base)
        self.assertEqual(today_bridge.read_refresh_request(), request)
        today_bridge.publish_payload(self.base, refresh_request_id=request["id"])
        self.assertFalse(refresh.exists())

    def test_status_distinguishes_missing_fresh_and_stale_plans(self):
        self.assertEqual(today_bridge.bridge_summary()["planState"], "missing")
        today_bridge.publish_payload(self.base)
        self.assertEqual(today_bridge.bridge_summary()["planState"], "fresh")
        old = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=13)).isoformat()
        today_bridge.publish_payload({**self.base, "generatedAt": old})
        summary = today_bridge.bridge_summary()
        self.assertTrue(summary["payloadValid"])
        self.assertEqual(summary["planState"], "stale")

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
