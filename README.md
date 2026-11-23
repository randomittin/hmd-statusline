# hmd-statusline

A terminal statusline for AI coding sessions: a context window meter, rate limits, gate verdict and team wall in a 4-row bar under the prompt.

Works with, today: Claude Code and Cursor

hmd-statusline is part of [hmd](https://runheimdall.dev), the CLI from [Heimdall](https://github.com/randomittin/heimdall). The bar runs on bash and Python 3 (standard library only), calls no model and makes no network request, and it never replaces a status line you already have. Use it on its own, or let hmd install it.

## What it shows

The bar reads the JSON that the tool running your session (the host) sends on stdin, plus a few local files.

| Where | What it shows | Where the data comes from |
|---|---|---|
| Row 2 | **Context window meter**: a filled bar behind `CTX 42% · ↓128k` (share of the window used, tokens in it) and the session cost, `$0.87`. The tip of the bar turns gold from 70% and red from 90%. Before the host has reported usage it says `CTX unavailable`, never a made-up `0%`. | the host's JSON |
| Row 4 | **Rate limits**: 5-hour and 7-day gauges with the hours left to reset, `5h ▓▓▓░░░░░ 42% ·2h │ 7d ▓░░░░░░░ 12%`. | the host's JSON |
| Row 1 | **Session**: the brand, your handle (`$USER` when hmd is absent), the model, and `repo:branch`. | the host's JSON |
| Row 3 | **Gate verdict**: `✓ gate 3/3`, how many of hmd's gates (the checks a change must pass before it is pushed) have passed. It says `gates offline` until one reports. | `.heimdall/statusline.json`, written by hmd |
| Right edge | **Team wall**: teammates working in the same repo, each with a state such as `⚡ wrk` or `✗ deny`; `+N` counts the ones that do not fit. You are never on your own wall, and a teammate who went quiet leaves it. | `.heimdall/.roster-cache.json` and `.heimdall/team/*.json`, written by hmd |
| Extra rows | **Parallel agents**: `swarm 2/4 active`, each live agent with its type and the file it claimed. An agent whose process has ended is not listed, and one live agent alone changes nothing. | `~/.heimdall/agent-pool.json` and `.planning/ledger/claims/`, written by hmd |
| Under the transcript | **Subagent rows**: one faint row per running subagent, `╰── hmd:coder implement auth · 4m10s ↓708k 71%` (its job, time running, tokens, context fill). | the host's subagent JSON |
| Left edge | **Sigil**: an 8×8 pixel-art face drawn from your identity. The same identity always gets the same face; there are 58 hand-authored hero faces to draw from. | your identity |

Without hmd, the meter, the rate limits, the session row, the subagent rows and the sigil all work from the host's JSON alone. The gate verdict, the team wall and the parallel-agents rows read files that hmd writes, so a bare clone shows `gates offline` and an empty wall. [HOST-CONTRACT.md](HOST-CONTRACT.md) lists every file the bar reads and writes.

**Fits the terminal.** The bar picks one of four layouts from its own width: 100 cells and up draws everything (up to three teammates), 60 to 99 shows up to two teammates and a `+N` for the rest, 40 to 59 turns the team into dots and the gauge into a bare bar, and under 40 it prints one line, `HMD 42% ✓`. It detects the colour depth (truecolor, 256 or 16 colours; tmux gets 256), and with `NO_COLOR` set the gauge becomes a plain `[####----]` bar. It always exits 0 and writes nothing to stderr, so it cannot break the prompt: input it cannot read draws one brand line, and with no python3 it prints `[ heimdall ]`.

## Example

```text
▄▄▄▄▄▄▄▄ ⛭ HEIMDALL │ rj · Opus 4.8 ◦ watching               ▄▄▄▄        ▄▄▄▄
▄▄▄▄▄▄▄▄  CTX 42% · ↓128k          $0.87                     ▄▄▄▄        ▄▄▄▄
▄▄▄▄▄▄▄▄ ✓ gate 3/3                                      nadia       priya    +1
▄▄▄▄▄▄▄▄ 5h ▓▓▓░░░░░ 42% ·2h │ 7d ▓░░░░░░░ 12%
```

Real output of `hooks/statusline.sh` with the colours stripped: an 80-cell bar, a session at 42% of its context window, gates 3/3 and three teammates online (two fit, the third is the `+1`). It is the carried golden [`conformance/statusline/goldens/density/rj_mid_truecolor.txt`](conformance/statusline/goldens/density/rj_mid_truecolor.txt), which the journey `the_same_bar_on_every_terminal` redraws and compares byte for byte. In a terminal the `▄` block at the left is the sigil in colour, and row 2 is the filled bar with its labels inside it.

## Install

### Standalone (no hmd)

You need bash and Python 3, on macOS or Linux.

```bash
git clone https://github.com/randomittin/hmd-statusline.git
cd hmd-statusline
bash bin/heimdall-statusline-register          # writes statusLine and subagentStatusLine into ~/.claude/settings.json
bash bin/heimdall-statusline-register-cursor   # writes statusLine into ~/.cursor/cli-config.json (run it only if you use that host)
```

Each registrar prints one word: `registered`, `current` (already wired, nothing written), `kept-custom` (you have your own status line, left alone) or `skipped` (no python3, or you opted out). The bar appears in your next session, redrawn every 2 seconds (every 3 in `~/.cursor/cli-config.json`). `bash bin/heimdall-statusline-register status` shows what it would do without writing. The settings store the absolute path of this clone, so clone it where it should stay; after moving it, run the registrar again to refresh the path.

Try the bar without installing anything:

```bash
printf '{"workspace":{"current_dir":"."},"model":{"display_name":"Opus 4.8"}}' | COLUMNS=124 bash hooks/statusline.sh
```

### With hmd

hmd installs the bar for you. Its installer writes the same two entries into `~/.claude/settings.json` (the step "Activating statusline HUD") and also registers `~/.cursor/cli-config.json` when it detects that host; `hmd init` does the second step too. Install hmd from the pinned, checksum-verified installer in the [heimdall README](https://github.com/randomittin/heimdall#install). Then:

- `hmd status` draws the bar by hand, in any shell.
- `hmd cursor-statusline register`, `status` or `unregister` manages the `~/.cursor/cli-config.json` entry.
- `hmd sigil` shows your sigil, and `hmd sigil-png` exports it as a PNG.
- `hmd uninstall` removes what the installer wrote.

hmd keeps a copy of this repository's files, pinned by tag and tree hash, so a standalone clone and hmd draw the same bar.

### Remove it

- `bash bin/heimdall-statusline-register-cursor unregister` (or `hmd cursor-statusline unregister`) removes the entry in `~/.cursor/cli-config.json`, and only if this bar wrote it.
- In `~/.claude/settings.json`, delete the `statusLine` and `subagentStatusLine` keys, or run `hmd uninstall` if hmd installed them.
- To stop both registrars from ever writing, set `HEIMDALL_NO_STATUSLINE_REGISTER=1` or create the file `~/.heimdall/no-statusline-register`; they then print `skipped`. For `~/.cursor/cli-config.json` alone, use `HEIMDALL_NO_CURSOR_STATUSLINE_REGISTER=1` or `~/.heimdall/no-cursor-statusline-register`.

## FAQ

### What is hmd-statusline?

hmd-statusline is a terminal statusline for AI coding sessions. It draws a four-row bar under the prompt: a context window meter with tokens and session cost, the 5-hour and 7-day rate limits, a gate verdict, a wall of teammates and the agents running in parallel, plus a pixel-art sigil for your identity. It is bash and Python 3, it comes from hmd, and it runs on its own or inside hmd.

### How do I show my context window usage in the terminal?

Install the bar (see Install) and open a new session. Row 2 is the meter: a filled bar behind `CTX 42% · ↓128k`, the share of the context window used and the tokens in it, with the session cost at the end of the bar. The tip turns gold from 70% and red from 90%, so a session that is filling up shows at a glance. Until the host reports usage it says `CTX unavailable`; it never shows a made-up `0%`.

### Does it need hmd?

No. A bare clone draws the context meter, the rate limits, the model, repo and branch, the subagent rows and the sigil from the JSON the host sends on stdin, using only bash, Python 3 and system tools. The repository's use-case journeys run that way, with an empty environment, and refuse to run where an hmd entry point sits next to the renderer. What hmd adds is the data behind three segments: the gate verdict, the team wall and the parallel-agents rows read files hmd writes.

### Will it replace the status line I already have?

No. Both registrars write only when the entry is absent or already points at this bar. If you have your own, they leave the file untouched and print `kept-custom`. The edit is atomic and every other key survives; the journeys check that the login data in `~/.cursor/cli-config.json` is untouched. Removal is under "Remove it" above.

### Does it send my code or session data anywhere?

The bar itself does not. Its Python modules import only the standard library, none opens a network connection, and it calls no model: it reads the host's JSON and local files and draws text. hmd's team presence is separate. When hmd is installed, the bar starts hmd's own presence tool in the background, and that tool sends your team's endpoint a signed heartbeat with your handle, verdict and current file name, never file contents; `hmd presence sever` stops it. The field-by-field contract is hmd's [DATA.md](https://github.com/randomittin/heimdall/blob/main/DATA.md).

### What does it look like in a narrow terminal or with few colours?

By the width of the bar it keeps four layouts: 100 cells and up draws everything (up to three teammates), 60 to 99 shows up to two teammates and a `+N` for the rest, 40 to 59 shows the team as dots and the gauge without labels, and under 40 it prints one line, `HMD 42% ✓`. It detects truecolor, 256 or 16 colours, gives tmux 256, and with `NO_COLOR` set the gauge becomes a plain `[####----]` bar.

## Part of hmd

hmd-statusline is the statusline half of [hmd](https://runheimdall.dev) (engine and repository name: Heimdall, [randomittin/heimdall](https://github.com/randomittin/heimdall)), the CLI that makes an AI coding agent's work pass a test it didn't write, and proves that test can fail, before the push lands. The gate verdict, the team wall and the parallel-agents rows show hmd's state. This repository is the source of truth for the bar; hmd vendors a copy of its runtime files.

## For contributors

This repository holds the bar, the sigil renderer (terminal and PNG) and the two registrars. It was cut out of heimdall on 2026-11-22 with its history. It is the source of truth: heimdall keeps a path-identical vendored copy pinned by tag and tree hash (`vendor/vendor.lock.json` in heimdall), so edit here, tag, then sync there. The root docs (`README.md`, `llms.txt`, `CITATION.cff`, `HOST-CONTRACT.md`) are not in that mirrored set, so changing them needs no lock bump; changing any file the lock lists does (tag, commit and `tree_sha256` together).

### Layout (the same relative paths as in heimdall: do not rename)

| Path | What |
|---|---|
| `hooks/statusline.sh` | the `statusLine` command written into `~/.claude/settings.json`. Its path and the text `hooks/statusline.sh` are the marker inside every registered `settings.json`: never move it. |
| `hooks/subagent-statusline.sh` | the `subagentStatusLine` command: one progress row per running subagent. |
| `bin/heimdall-statusline` | the one renderer both hosts reach; the `statusLine` in `~/.cursor/cli-config.json` points at it directly. |
| `bin/heimdall-statusline-register`, `-register-cursor` | write the bar into `~/.claude/settings.json` / `~/.cursor/cli-config.json`, never over a status line the user already has. |
| `bin/heimdall-sigil`, `bin/heimdall-sigil-png` | `hmd sigil` and `hmd sigil-png`. |
| `sentinels/` | the renderers and the libraries they share: `hmd-statusline.py`, `hmd_sigil.py`, `hmd_layout.py`, `hmd_ledger.py`, `hmd_termcaps.py`, `hmd_gauge.py`, `hmd_wall.py`, `hmd_sigil_png.py`, `subagent-statusline.py`. |
| `conformance/statusline/` | the invariants ledger, the 21 goldens (12 density, 9 sigil) the journeys compare against, and the 4 `*.fixture.sh` fixtures. `conformance/_lib.sh` is their assertion helper, copied from heimdall. |
| `test/` | the 34 `*.test.sh` suites that came with the history, plus the helpers they read, copied from heimdall: `test/lib/` and `test/fixtures/`. |
| `scripts/` | `lint.sh` (the `lint` check) and `carried_suites.py` (the `suites` check). |

### Run it

```bash
printf '{"workspace":{"current_dir":"."},"model":{"display_name":"Opus 4.8"}}' | COLUMNS=124 bash hooks/statusline.sh
bash scripts/lint.sh                 # the `lint` check
bash tests/use_cases/run.sh          # the `use-cases` check; add a word to run only the journeys named like it
python3 scripts/carried_suites.py    # the `suites` check; add a word to run only the suites whose path contains it
```

`.heimdall/repo-checks.json` declares those three checks; heimdall's `bin/heimdall-repo-checks run` runs all of them and records the receipt a push gate reads. The checks are recommended before a merge or a release, never started by an agent on its own.

### Journeys (`tests/use_cases/`)

Each journey is one thing a user does with the bar, run through the real entry point with an empty environment, a frozen clock and a new HOME, and compared with the goldens this repository carries: a fresh session; the context filling up (gold past 70%, red past 90%); a shrinking terminal; the same bar on 3 colour classes x 4 widths; teammates on the wall; parallel agents and subagent rows; a host that sends its own width; no python3; installing without replacing a status line the user already has; the sigil in the terminal and as a PNG. The list, one line each, is the header of `tests/use_cases/run.sh`.

### Stands alone

No heimdall file is needed to draw the bar: the journeys run with a PATH of system tools and python3 only, and refuse to run where a host entry point sits next to the renderer. What the host adds, and what a clone does without it, is in [HOST-CONTRACT.md](HOST-CONTRACT.md) (section 7 says which parts are measured). The files the host writes and the bar reads (`.heimdall/.roster-cache.json`, `~/.heimdall/agent-pool.json`, ...) are seeded by the journeys in the shapes that contract names.

### Shared libraries

`sentinels/hmd_sigil.py`, `hmd_layout.py`, `hmd_ledger.py` and `hmd_termcaps.py` are also imported by heimdall's own banner, board, UI, identity and status-json code. Renaming or removing something they import breaks heimdall at its next sync; heimdall's integration suites (statusline parity, sigil, status-json) are the check on that side.

### The carried suites

`test/*.test.sh` (34) and `conformance/statusline/*.fixture.sh` (4) came with the history. Heimdall deleted 24 of the suites and most of the conformance files when it split, so they run nowhere else: the `suites` check runs every one, once, with a pass, skip or fail per suite, printed as it ends and recorded in `.heimdall/receipts/carried-suites.json`. The files the suites read that heimdall owns (`conformance/_lib.sh`, `test/lib/`, `test/fixtures/`) are copied here byte for byte.

28 of the 38 need nothing but python3 and system tools and run in place (one of them, `viral-statusline`, skips two sections without a host and says so). The other 10 need a heimdall file (`bin/heimdall`, `heimdall-tier`, `heimdall-agents`, `heimdall-ctx-meter`, `bin/lib/hmd_session_code.py` and `hmd_private_state.py`, `hooks/hooks.json`, `settings.json`, `sentinels/hmd-gate-anim.sh`; the table is [HOST-CONTRACT.md](HOST-CONTRACT.md) section 8): when a heimdall checkout is found (`HMD_HOST_DIR`, else `../heimdall`) they run in a scratch copy of it with this repository laid over it, and with none they are skipped, each saying which file it needs. `HMD_REQUIRE_HOST=1` makes every skip a failure (CI sets it); `HMD_NO_HOST=1` ignores any host, to see what a lone clone sees.

Two fixtures, `prefix-and-elements` and `viral-statusline`, assert 9 things the renderer no longer does: the `▐ ● ● ▌` eye bracket, three eye colours, the text `bifröst closed`, `invite your team`, the `●` roster pip, and two identity checks that the 5 s identity cache defeats. Heimdall never wired the fixtures into a gate, so nothing noticed. `STALE_ASSERTIONS` in `scripts/carried_suites.py` lists them with the reason; they print as STALE on every run and are counted apart from the passes, and any other failure in those fixtures still fails the run. Fix the assertion in the fixture, or delete the entry when the renderer should do it again.

## License

MIT. See [LICENSE](LICENSE).
