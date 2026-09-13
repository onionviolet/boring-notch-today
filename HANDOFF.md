# HANDOFF

GOAL: Ship a buildable Boring Notch fork with a read-only Today tab that displays validated MCP-published snapshots promptly.

OWNER: Weibao decides product scope and any account or release decision.

SCOPE: `boringNotch/components/Today`, its Xcode wiring, the shared publisher, narrow stdio MCP server, focused tests, and Today documentation.

DO NOT TOUCH: The planning vault, its `_daily/` directory, collected coursework, credentials, unrelated upstream code, or canonical task completion state.

CONTEXT: The app reads one versioned JSON payload at `~/Library/Application Support/boring.notch/Today/payload.json`. MCP is the AI-facing control plane; bounded atomic files are the app-facing data plane. The app never speaks MCP or reads the vault. Git remotes are `origin` for the authenticated fork and `upstream` for TheBoredTeam/boring.notch.

EVIDENCE: The pre-MCP baseline was clean at commit `83847f4`. Seven Python contract tests, the official-SDK stdio MCP handshake/tool smoke test, strict Swift payload/status tests, project-file lint, diff check, the supported signed Release build, and the unsigned runtime build pass. A real `publish_today` call changed the visible production `TodayView` without reopening it and showed `MCP live`. Clicking Refresh produced an owner-only 130-byte fixed-schema UUID request and showed `MCP refresh pending`; stopping the MCP client retained the valid snapshot and showed offline/stale fallback. Moving the payload aside immediately showed the empty state; republishing it immediately restored the view. The local Codex config contains the enabled `boring-notch-today` stdio server entry.

AUDITS: Parallel transport, Swift watcher, and security lanes agreed to keep MCP outside the app, use stdio rather than an unauthenticated local port, treat watcher events as hints, retain atomic file authority, preserve last-known-good content, expose sanitized connection states, and state clearly that Refresh cannot wake an idle agent. Security hardening adds unknown-key rejection, three-action maximum, text bounds, future-date limits, UUID refresh requests, click coalescing, owner-only status storage, and fixed tools with no arbitrary command/path/prompt/vault input.

NEXT ACTION: Restart Codex before expecting the newly configured server in a fresh tool catalog. A genuinely automatic response to Refresh still requires an explicitly scheduled or already-running authorized AI workflow. Signed distribution separately requires reconciling the upstream `MediaRemoteAdapter` Team ID.

GATE: PASS for the MCP/live bridge. Python contract tests pass 7/7; the actual stdio MCP smoke and Swift tests pass; the supported Release build succeeds; live, pending, stale/offline, empty, and restored states were visibly verified; the actual diff passed independent watcher and security reviews. Signed local launch remains limited by the upstream `MediaRemoteAdapter` Team-ID mismatch and is not claimed as verified.

RETURN: Commit and fork URL, changed paths, exact commands and results, visual evidence, remaining limits, and disposition of every audit finding.
