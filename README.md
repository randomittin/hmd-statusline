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
| `conformance/statusline/` | the invariants ledger and the 21 goldens (12 density, 9 sigil) the journeys compare against. |

## Run it

```bash
printf '{"workspace":{"current_dir":"."},"model":{"display_name":"Opus 4.8"}}' | COLUMNS=124 bash hooks/statusline.sh
bash scripts/lint.sh                 # the `lint` check
bash tests/use_cases/run.sh          # the `use-cases` check; add a word to run only the journeys named like it
```

`.heimdall/repo-checks.json` declares those two checks; heimdall's `bin/heimdall-repo-checks run` runs both and records the receipt a push gate reads. The checks are recommended before a merge or a release, never started by an agent on its own.

## Journeys (`tests/use_cases/`)

Each journey is one thing a user does with the bar, run through the real entry point with an empty environment, a frozen clock and a new HOME, and compared with the goldens this repository carries: a fresh session; the context filling up (gold past 70%, red past 90%); a shrinking terminal; the same bar on 3 colour classes x 4 widths; teammates on the wall; parallel agents and subagent rows; Cursor's width; no python3; installing without replacing a status line the user already has; the sigil in the terminal and as a PNG. The list, one line each, is the header of `tests/use_cases/run.sh`.

## Stands alone

No heimdall file is needed to draw the bar: the journeys run with a PATH of system tools and python3 only, and refuse to run where a host entry point sits next to the renderer. What the host adds, and what a clone does without it, is in [HOST-CONTRACT.md](HOST-CONTRACT.md) (section 7 says which parts are measured). The files the host writes and the bar reads (`.heimdall/.roster-cache.json`, `~/.heimdall/agent-pool.json`, ...) are seeded by the journeys in the shapes that contract names.

## Shared libraries

`sentinels/hmd_sigil.py`, `hmd_layout.py`, `hmd_ledger.py` and `hmd_termcaps.py` are also imported by heimdall's own banner, board, UI, identity and status-json code. Renaming or removing something they import breaks heimdall at its next sync; heimdall's integration suites (statusline parity, sigil, status-json) are the check on that side.

## The carried suites

`test/*.test.sh` and `conformance/statusline/*.fixture.sh` came with the history. They are not the gate: several name heimdall files (`bin/heimdall`, the identity and tier tools, `test/fixtures`, `conformance/_lib.sh`) that were not carried, and none was run when this repository was cut. Treat them as history until a journey replaces them.
