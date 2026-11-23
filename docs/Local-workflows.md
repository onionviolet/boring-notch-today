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
An unsigned build is not an installed or signed release.

# Local Release candidate

Run `python3 scripts/build-local-release.py` from a Git checkout. It builds the
unsigned Release app, sets the build revision visible in Today connection
details, and writes `Boring Notch.build.json` next to the app. The receipt stores
the checkout commit, any pending merge parents, a fingerprint of source
changes, the build configuration and Xcode version, and the executable hash.
A source change during the build prevents a receipt from being written.

The installer checks a supplied candidate receipt against the executable hash
and embedded revision. Older candidates built without a receipt can still be
installed, with source identity recorded as unknown.

# Cleanup after an app update

User instruction, November 13, 2026: trimming is forced, not left to an agent
remembering at the end of a session. Two mechanisms:

1. **Install path.** `python3 scripts/install-local-update.py` is the way to
   replace `/Applications/Boring Notch.app`. It stages the candidate (default
   `work/DerivedData/Build/Products/Release/Boring Notch.app`), quits the
   running app, swaps, launches, watches for 20 s, checks for crash reports,
   deletes the previous copy, writes `work/install-<stamp>/receipt.json`, then
   runs the trim. On any failure it keeps the previous app in that folder and
   trims nothing.
2. **Nightly backstop.** The 03:10 LaunchAgent runs the trim with
   `--min-age-days 3` before its build, so leftovers from a session that never
   finished are still removed, and anything touched in the last three days is
   left for the task using it.

The trim on its own:

```bash
python3 scripts/trim-build-leftovers.py          # list only
python3 scripts/trim-build-leftovers.py --apply  # delete
```

It removes only what a build can recreate: extra `work/*DerivedData*` and
`work/*-build` folders, `work/*.app` copies, `work/local-app-backups/`
contents, `work/uv-cache`, top-level `work/*.log` older than 14 days, and
nightly source snapshots other than the current SHA. It keeps
`work/DerivedData` (so the next build stays incremental; `--all` removes it
too), the nightly DerivedData, registered git worktrees, evidence folders,
screenshots and patches. It refuses to run during an `xcodebuild` and skips
nightly snapshots while the nightly lock is held.

Do not run `--apply` by hand after a failed install; leave everything in place
for recovery. Older reports cite `work/` logs that this removes;
those reports keep the results, the raw logs are not retained.
