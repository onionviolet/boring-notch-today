# HANDOFF

GOAL: Ship a buildable Boring Notch fork with a read-only, locally published Today tab.

OWNER: Weibao decides product scope and any account or release decision.

SCOPE: `boringNotch/components/Today`, tab/view wiring, `scripts/boring-notch-today.py`, tests, and Today documentation.

DO NOT TOUCH: The planning vault, its `_daily/` directory, collected coursework, credentials, unrelated upstream code, or canonical task completion state.

CONTEXT: The app reads one versioned JSON payload at `~/Library/Application Support/boring.notch/Today/payload.json`. It has no vault integration. Git remotes are `origin` for the authenticated fork and `upstream` for TheBoredTeam/boring.notch.

EVIDENCE: On 2026-09-13, focused Swift payload tests passed, the permanent Python publisher suite passed 3/3, and a valid sample published atomically with `0700` directory and `0600` payload. The exact supported Release build command succeeded on this Mac. An unsigned developer build visibly rendered the sample through the production `TodayView`; its fixed Itembank action launched `/Applications/itembank.app`, and Refresh wrote an owner-only local marker.

AUDITS: Upstream architecture audit reconciled. It found the relevant enum, tab, content switch, release command, and no upstream XCTest target. Bridge/privacy audit reconciled: fixed local transport, 64 KiB bound on both sides, owner-only files, parent and direct symlink rejection, whole-file validator parity, HTTPS-only sources, fixed `dev.itembank` launch, and no canonical write action are implemented. The independent verifier's timestamp, Anki, duplicate-ID, malformed-host, dead-branch, and symlink findings were fixed and promoted into tests.

NEXT ACTION: If distributing a signed app, reconcile the upstream embedded `MediaRemoteAdapter` framework's Team ID with the app signing identity, then repeat the runtime check.

GATE: PASS for the requested fork integration. `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release build` succeeds; focused tests pass; an unsigned build visibly renders the published sample; source, Itembank, and refresh boundaries are checked; the actual diff received independent review. Signed local launch remains limited by an upstream `MediaRemoteAdapter` Team-ID mismatch and is not claimed as verified.

RETURN: Commit and fork URL, changed paths, exact commands and results, visual evidence, remaining limits, and disposition of every audit finding.
