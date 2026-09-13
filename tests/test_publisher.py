import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).parents[1] / "scripts/boring-notch-today.py"


class PublisherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = pathlib.Path(self.temp.name)
        self.input = self.home / "input.json"
        self.env = {**os.environ, "HOME": str(self.home)}
        self.base = {
            "schemaVersion": 1,
            "generatedAt": "2026-09-13T16:00:00Z",
            "rows": [],
            "anki": {"status": "unavailable"},
            "actions": [],
        }

    def tearDown(self): self.temp.cleanup()

    def publish(self, data):
        self.input.write_text(json.dumps(data))
        return subprocess.run(["python3", str(SCRIPT), "publish", "--input", str(self.input)], env=self.env, capture_output=True)

    def test_valid_publish_is_private_and_atomic_on_failure(self):
        self.assertEqual(self.publish(self.base).returncode, 0)
        payload = self.home / "Library/Application Support/boring.notch/Today/payload.json"
        before = hashlib.sha256(payload.read_bytes()).digest()
        self.assertEqual(payload.stat().st_mode & 0o777, 0o600)
        self.assertEqual(payload.parent.stat().st_mode & 0o777, 0o700)
        invalid = {**self.base, "rows": [{}]}
        self.assertEqual(self.publish(invalid).returncode, 2)
        self.assertEqual(hashlib.sha256(payload.read_bytes()).digest(), before)

    def test_rejects_reader_parity_failures(self):
        cases = []
        cases.append({key: value for key, value in self.base.items() if key != "actions"})
        cases.append({**self.base, "generatedAt": "2026-09-13T16:00:00"})
        cases.append({**self.base, "generatedAt": "2026-09-13"})
        cases.append({**self.base, "anki": {"status": "available", "reviewedToday": "1", "newCards": 0}})
        cases.append({**self.base, "actions": [{"id": "bad", "label": "Bad", "kind": "source", "url": "https:///missing-host"}]})
        for case in cases: self.assertEqual(self.publish(case).returncode, 2)

    def test_rejects_direct_and_parent_storage_symlinks(self):
        application_support = self.home / "Library/Application Support"
        application_support.mkdir(parents=True)
        redirected = self.home / "redirected"
        redirected.mkdir()
        (application_support / "boring.notch").symlink_to(redirected, target_is_directory=True)
        self.assertEqual(self.publish(self.base).returncode, 2)

        (application_support / "boring.notch").unlink()
        product = application_support / "boring.notch"
        product.mkdir()
        (product / "Today").symlink_to(redirected, target_is_directory=True)
        self.assertEqual(self.publish(self.base).returncode, 2)


if __name__ == "__main__": unittest.main()
