# Local nightly build

The Mac LaunchAgent `local.weibao.boring-notch-nightly` runs the unsigned
Release build at 03:10 local time while the user session is available. The
script fetches the fork's remote `main` into a separate bare repository and
builds an immutable source snapshot. It does not use or change the development
worktree, sign the app, install it, publish artifacts, or run the full CI test
matrix. Network access, Xcode, Swift packages, disk space and an awake Mac
remain prerequisites. Logs and artifacts are under `~/Library/Logs/boring-notch-local-build/`
and `~/Library/Application Support/boring-notch-local-build/` respectively.

Run it manually with `python3 scripts/local-nightly-build.py`. Check the last
exit status with `launchctl print gui/$(id -u)/local.weibao.boring-notch-nightly`.
Old source snapshots and build data consume disk space; no automatic cleanup
is configured. An unsigned build is not an installed or signed release.
