# hmd-statusline

The Heimdall statusline: the 4-row bar Claude Code and Cursor draw under the prompt (hero sigil, context gauge, gate verdict, team wall), the sigil renderer (terminal and PNG), and the two registrars that wire the bar into a user's settings. It was cut out of heimdall on 2026-11-22 with its history. This repository is the source of truth; heimdall keeps a path-identical vendored copy pinned by tag and tree hash, so edit here, tag, then sync there.

## Layout (the same relative paths as in heimdall: do not rename)

| Path | What |
|---|---|
| `hooks/statusline.sh` | Claude Code's `statusLine` command. Its path and the text `hooks/statusline.sh` are the marker inside every registered `settings.json`: never move it. |
| `hooks/subagent-statusline.sh` | Claude Code's `subagentStatusLine`: one progress row per running subagent. |
| `bin/heimdall-statusline` | the one renderer both hosts reach; Cursor's `statusLine` points at it directly. |
| `bin/heimdall-statusline-register`, `-register-cursor` | write the bar into `~/.claude/settings.json` / `~/.cursor/cli-config.json`, never over a status line the user already has. |
| `bin/heimdall-sigil`, `bin/heimdall-sigil-png` | `hmd sigil` and `hmd sigil-png`. |
| `sentinels/` | the renderers and the libraries they share: `hmd-statusline.py`, `hmd_sigil.py`, `hmd_layout.py`, `hmd_ledger.py`, `hmd_termcaps.py`, `hmd_gauge.py`, `hmd_wall.py`, `hmd_sigil_png.py`, `subagent-statusline.py`. |
| `conformance/statusline/` | the invariants ledger, the 21 goldens (12 density, 9 sigil) the journeys compare against, and the 4 `*.fixture.sh` fixtures. `conformance/_lib.sh` is their assertion helper, copied from heimdall. |
| `test/` | the 34 `*.test.sh` suites that came with the history, plus the helpers they read, copied from heimdall: `test/lib/` and `test/fixtures/`. |
| `scripts/` | `lint.sh` (the `lint` check) and `carried_suites.py` (the `suites` check). |

## Run it

```bash
printf '{"workspace":{"current_dir":"."},"model":{"display_name":"Opus 4.8"}}' | COLUMNS=124 bash hooks/statusline.sh
bash scripts/lint.sh                 # the `lint` check
bash tests/use_cases/run.sh          # the `use-cases` check; add a word to run only the journeys named like it
python3 scripts/carried_suites.py    # the `suites` check; add a word to run only the suites whose path contains it
```

`.heimdall/repo-checks.json` declares those three checks; heimdall's `bin/heimdall-repo-checks run` runs all of them and records the receipt a push gate reads. The checks are recommended before a merge or a release, never started by an agent on its own.

## Journeys (`tests/use_cases/`)

Each journey is one thing a user does with the bar, run through the real entry point with an empty environment, a frozen clock and a new HOME, and compared with the goldens this repository carries: a fresh session; the context filling up (gold past 70%, red past 90%); a shrinking terminal; the same bar on 3 colour classes x 4 widths; teammates on the wall; parallel agents and subagent rows; Cursor's width; no python3; installing without replacing a status line the user already has; the sigil in the terminal and as a PNG. The list, one line each, is the header of `tests/use_cases/run.sh`.

## Stands alone

No heimdall file is needed to draw the bar: the journeys run with a PATH of system tools and python3 only, and refuse to run where a host entry point sits next to the renderer. What the host adds, and what a clone does without it, is in [HOST-CONTRACT.md](HOST-CONTRACT.md) (section 7 says which parts are measured). The files the host writes and the bar reads (`.heimdall/.roster-cache.json`, `~/.heimdall/agent-pool.json`, ...) are seeded by the journeys in the shapes that contract names.

## Shared libraries

`sentinels/hmd_sigil.py`, `hmd_layout.py`, `hmd_ledger.py` and `hmd_termcaps.py` are also imported by heimdall's own banner, board, UI, identity and status-json code. Renaming or removing something they import breaks heimdall at its next sync; heimdall's integration suites (statusline parity, sigil, status-json) are the check on that side.

## The carried suites

`test/*.test.sh` (34) and `conformance/statusline/*.fixture.sh` (4) came with the history. Heimdall deleted 24 of the suites and most of the conformance files when it split, so they run nowhere else: the `suites` check runs every one, once, with a pass, skip or fail per suite, printed as it ends and recorded in `.heimdall/receipts/carried-suites.json`. The files the suites read that heimdall owns (`conformance/_lib.sh`, `test/lib/`, `test/fixtures/`) are copied here byte for byte.

28 of the 38 need nothing but python3 and system tools and run in place (one of them, `viral-statusline`, skips two sections without a host and says so). The other 10 need a heimdall file (`bin/heimdall`, `heimdall-tier`, `heimdall-agents`, `heimdall-ctx-meter`, `bin/lib/hmd_session_code.py` and `hmd_private_state.py`, `hooks/hooks.json`, `settings.json`, `sentinels/hmd-gate-anim.sh`; the table is [HOST-CONTRACT.md](HOST-CONTRACT.md) section 8): when a heimdall checkout is found (`HMD_HOST_DIR`, else `../heimdall`) they run in a scratch copy of it with this repository laid over it, and with none they are skipped, each saying which file it needs. `HMD_REQUIRE_HOST=1` makes every skip a failure (CI sets it); `HMD_NO_HOST=1` ignores any host, to see what a lone clone sees.

Two fixtures, `prefix-and-elements` and `viral-statusline`, assert 9 things the renderer no longer does: the `▐ ● ● ▌` eye bracket, three eye colours, the text `bifröst closed`, `invite your team`, the `●` roster pip, and two identity checks that the 5 s identity cache defeats. Heimdall never wired the fixtures into a gate, so nothing noticed. `STALE_ASSERTIONS` in `scripts/carried_suites.py` lists them with the reason; they print as STALE on every run and are counted apart from the passes, and any other failure in those fixtures still fails the run. Fix the assertion in the fixture, or delete the entry when the renderer should do it again.
