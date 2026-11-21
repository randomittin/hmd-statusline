#!/usr/bin/env bash
# lib.sh -- what every journey of tests/use_cases stands on: a world to live in, the doors a user's tools walk through, and the checks on what comes out.
#
# The doors are this repo's real entry points: hooks/statusline.sh (what Claude Code runs), bin/heimdall-statusline (what Cursor runs), hooks/subagent-statusline.sh,
# bin/heimdall-sigil, bin/heimdall-sigil-png and the two registrars. Each runs with `env -i` and a PATH that holds only the tools it needs (uc_init builds that
# directory), so nothing of the developer's machine leaks in, heimdall included: what passes here passes on a machine that has never heard of heimdall.
# Fakes: none. The clock is frozen (HMD_NOW) and every world has its own HOME and repository directory. The only files a journey writes are the ones the user
# or the host would have written (a settings file, a roster cache, an agent pool), in the shape HOST-CONTRACT.md names.
#
# bash 3.2 safe (macOS): no associative arrays, no mapfile, no ${var,,}.

UC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$UC_DIR/../.." && pwd)"
GOLD="$REPO/conformance/statusline/goldens"
CC_RESERVE=4          # Claude Code paints the bar 4 cells narrower than $COLUMNS (sentinels/hmd-statusline.py, CC_REGION_RESERVE)
UC_PASS=0
UC_FAIL=0
UC_SLEEPERS=""
export UC_DIR REPO GOLD CC_RESERVE UC_PASS UC_FAIL UC_SLEEPERS

# uc_init: the scratch directory, the tools directory and the interpreter every check uses; refuses to run where the host is next door
uc_init() {
  local t p py
  UC_TMP="$(mktemp -d)"
  UC_TOOLS="$UC_TMP/tools"
  UC_PY="$UC_TOOLS/python3"
  export UC_TMP UC_TOOLS UC_PY
  trap 'uc_stop_sleepers; rm -rf "$UC_TMP"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  mkdir -p "$UC_TOOLS" "$UC_TMP/tools-nopy" "$UC_TMP/cache"
  for t in awk bash cat cmp date dirname env find grep head mkdir mktemp perl readlink rm sed sleep sort stat tail tput tr uname wc; do
    p="$(command -v "$t" 2>/dev/null)"
    case "$p" in /*) ;; *) continue ;; esac
    ln -s "$p" "$UC_TOOLS/$t"
    ln -s "$p" "$UC_TMP/tools-nopy/$t"
  done
  py="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null)"
  if [ ! -x "$py" ]; then
    echo "use-cases: python3 is required (the renderers are python)" >&2
    return 1
  fi
  ln -s "$py" "$UC_PY"
  if ! "$UC_PY" -c 'import json, sqlite3' 2>/dev/null; then
    echo "use-cases: $py does not run from the tools directory (json and sqlite3 must import)" >&2
    return 1
  fi
  for t in heimdall-agents heimdall-identity heimdall-face heimdall-presence heimdall-tier heimdall-ctx-meter; do
    if [ -e "$REPO/bin/$t" ]; then
      echo "use-cases: $REPO/bin/$t exists, so the host is here and these journeys cannot show the repository stands alone; run them from a clone of hmd-statusline" >&2
      return 1
    fi
  done
  return 0
}

# ── the world of one journey: a repository directory, a HOME and a scratch directory, all new ─────────────────────────────────────────────────────────
uc_world() {
  WS="$(mktemp -d "$UC_TMP/repo.XXXXXX")"
  HOMED="$(mktemp -d "$UC_TMP/home.XXXXXX")"
  TMPD="$(mktemp -d "$UC_TMP/scratch.XXXXXX")"
  export WS HOMED TMPD
}

# ── processes that stand in for running agents ───────────────────────────────────────────────────────────────────────────────────────────────────────
# uc_sleeper: a process that stays alive until the journey ends; its pid is the last of UC_SLEEPERS
uc_sleeper() {
  sleep 300 >/dev/null 2>&1 &
  UC_SLEEPERS="$UC_SLEEPERS $!"
  disown 2>/dev/null
}
uc_last_sleeper() { printf '%s' "${UC_SLEEPERS##* }"; }
uc_stop_sleepers() {
  local p
  for p in $UC_SLEEPERS; do kill "$p" 2>/dev/null; done
  UC_SLEEPERS=""
}
# uc_dead_pid: the pid of a process that has already ended
uc_dead_pid() {
  local p
  sh -c 'exit 0' &
  p=$!
  wait "$p" 2>/dev/null
  printf '%s' "$p"
}

# ── the doors ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# uc_in_world <VAR=value ...> <command ...>: the command with an empty environment but the tools directory as PATH, this world's HOME and the variables given
uc_in_world() {
  env -i PATH="${UC_TOOLS_OVERRIDE:-$UC_TOOLS}" HOME="$HOMED" LANG=en_US.UTF-8 PYTHONIOENCODING=utf-8 PYTHONDONTWRITEBYTECODE=1 "$@"
}

# uc_term_env <truecolor|256|16>: the one variable a terminal of that class sets (iTerm2/VS Code, Terminal.app and tmux-style 256 terminals, a plain xterm)
uc_term_env() {
  case "$1" in
    truecolor) echo "COLORTERM=truecolor" ;;
    256) echo "TERM=xterm-256color" ;;
    16) echo "TERM=xterm" ;;
  esac
}

# uc_claude_code <columns> <terminal> [VAR=value ...]: Claude Code's statusLine command; the statusLine JSON is read from stdin
uc_claude_code() {
  local cols="$1" term="$2"
  shift 2
  uc_in_world HMD_NOW=7 HMD_STATUSLINE_TMP="$TMPD" COLUMNS="$cols" "$(uc_term_env "$term")" "$@" bash "$REPO/hooks/statusline.sh"
}

# uc_capture <name> <command ...>: run the command with the caller's stdin and keep what it wrote ($UC_TMP/<name>.out and .err) and how it ended (.rc);
# UC_BASE names the three, UC_RC is the exit code
uc_capture() {
  local name="$1"
  shift
  UC_BASE="$UC_TMP/$name"
  mkdir -p "$(dirname "$UC_BASE")"
  "$@" >"$UC_BASE.out" 2>"$UC_BASE.err"
  UC_RC=$?
  printf '%s\n' "$UC_RC" >"$UC_BASE.rc"
  export UC_BASE UC_RC
}

# ── the world the carried goldens were rendered in: rj, a passing gate, three teammates online ───────────────────────────────────────────────────────
uc_golden_world() {
  mkdir -p "$WS/.heimdall"
  printf '{"handle":"rj","seed":"rj","created":0}\n' >"$WS/.heimdall/identity.json"
  printf '{"verdict":"pass","passed":3,"total":3}\n' >"$WS/.heimdall/statusline.json"
  printf '%s\n' '[{"handle":"nadia","haid":"haid:nadia","verdict":"working","file":"auth.ts","age_seconds":4},{"handle":"arjun","haid":"haid:arjun","verdict":"watching","file":"db.go","age_seconds":9},{"handle":"priya","haid":"haid:priya","verdict":"deny","file":"api.py","age_seconds":6}]' \
    >"$WS/.heimdall/.roster-cache.json"
}
# uc_golden_payload <context use in percent>: the statusLine JSON of the golden world, mid-session
uc_golden_payload() {
  printf '{"workspace":{"project_dir":"/hmd-density-fixture/repo","current_dir":"%s","repo":{"name":"heimdall","branch":"statusline-v1"}},"model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":%s,"total_input_tokens":128000},"session_id":"density","cost":{"total_cost_usd":0.87,"total_duration_ms":3840000},"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":7207},"seven_day":{"used_percentage":12}}}' "$WS" "$1"
}

# the width, in cells, of the bar the goldens hold for each width class (the production terminal is CC_RESERVE cells wider)
uc_cols_for() {
  case "$1" in
    full) echo 120 ;;
    mid) echo 80 ;;
    narrow) echo 48 ;;
    tiny) echo 30 ;;
  esac
}

# uc_golden_hud <width class> <colour class>: the bar of the golden world on a terminal of that width and colour, drawn once per run; prints its capture
uc_golden_hud() {
  local base="$UC_TMP/cache/hud-$1-$2"
  if [ ! -f "$base.rc" ]; then
    uc_world
    uc_golden_world
    uc_golden_payload 42 >"$UC_TMP/payload-$1-$2.json"
    uc_capture "cache/hud-$1-$2" uc_claude_code "$(($(uc_cols_for "$1") + CC_RESERVE))" "$2" HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" <"$UC_TMP/payload-$1-$2.json"
  fi
  printf '%s' "$base"
}

# ── what a journey can say about what came out ───────────────────────────────────────────────────────────────────────────────────────────────────────
uc_ok() {
  UC_PASS=$((UC_PASS + 1))
  printf '    ok   %s\n' "$1"
}
uc_bad() { # <what> [detail]
  UC_FAIL=$((UC_FAIL + 1))
  printf '    FAIL %s\n' "$1"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" | sed 's/^/           /'; fi
}

uc_plain() { "$UC_PY" "$UC_DIR/peek.py" plain "$1"; }
uc_row() { "$UC_PY" "$UC_DIR/peek.py" row "$1.out" "$2"; }
uc_raw_row() { "$UC_PY" "$UC_DIR/peek.py" rawrow "$1.out" "$2"; }

# uc_exit_clean <what> [capture]: the run ended with exit 0 and wrote nothing to stderr
uc_exit_clean() {
  local base="${2:-$UC_BASE}" rc
  rc="$(cat "$base.rc")"
  if [ "$rc" = 0 ] && [ ! -s "$base.err" ]; then
    uc_ok "$1: exits 0 and says nothing on stderr"
  else
    uc_bad "$1: exit $rc, stderr [$(head -c 200 "$base.err")]"
  fi
}
# uc_has / uc_lacks <capture> <text> <what>: the bar, as a person reads it, contains / does not contain the text
uc_has() {
  local text
  text="$(uc_plain "$1.out")"
  if grep -qF -- "$2" <<<"$text"; then uc_ok "$3"; else uc_bad "$3" "no '$2' in: ${text:0:600}"; fi
}
uc_lacks() {
  local text
  text="$(uc_plain "$1.out")"
  if grep -qF -- "$2" <<<"$text"; then uc_bad "$3" "found '$2' in: ${text:0:600}"; else uc_ok "$3"; fi
}
# uc_row_has / uc_row_lacks <capture> <row> <text> <what>: the same for one row (1-based)
uc_row_has() {
  local text
  text="$(uc_row "$1" "$2")"
  if grep -qF -- "$3" <<<"$text"; then uc_ok "$4"; else uc_bad "$4" "no '$3' in row $2: $text"; fi
}
uc_row_lacks() {
  local text
  text="$(uc_row "$1" "$2")"
  if grep -qF -- "$3" <<<"$text"; then uc_bad "$4" "found '$3' in row $2: $text"; else uc_ok "$4"; fi
}
# uc_raw_row_has / uc_raw_row_lacks <capture> <row> <bytes> <what>: the same on the row as emitted, colour codes included
uc_raw_row_has() {
  local bytes
  bytes="$(uc_raw_row "$1" "$2")"
  if grep -qF -- "$3" <<<"$bytes"; then uc_ok "$4"; else uc_bad "$4" "no '$3' in the emitted bytes of row $2"; fi
}
uc_raw_row_lacks() {
  local bytes
  bytes="$(uc_raw_row "$1" "$2")"
  if grep -qF -- "$3" <<<"$bytes"; then uc_bad "$4" "found '$3' in the emitted bytes of row $2"; else uc_ok "$4"; fi
}
# uc_rows_are <capture> <count> <what>: the bar has that many rows
uc_rows_are() {
  local n
  n="$("$UC_PY" "$UC_DIR/peek.py" rows "$1.out")"
  if [ "$n" = "$2" ]; then uc_ok "$3"; else uc_bad "$3" "$n rows, wanted $2"; fi
}
# uc_widths_are <capture> <cells> <what>: every row is exactly that many cells wide
uc_widths_are() {
  local w
  w="$("$UC_PY" "$UC_DIR/peek.py" widths "$1.out")"
  if [ "$w" = "$2" ]; then uc_ok "$3"; else uc_bad "$3" "row widths [$w], wanted every row $2"; fi
}
# uc_matches_golden <capture> <golden file> <what>: byte for byte the golden the repo carries
uc_matches_golden() {
  if cmp -s "$1.out" "$2"; then
    uc_ok "$3"
  else
    uc_bad "$3 (differs from ${2#"$REPO"/})" "$(diff <(uc_plain "$2") <(uc_plain "$1.out") | head -8)"
  fi
}
# uc_same_bytes <capture> <capture> <what>: two runs wrote the same bytes
uc_same_bytes() {
  if cmp -s "$1.out" "$2.out"; then uc_ok "$3"; else uc_bad "$3" "$(diff <(uc_plain "$1.out") <(uc_plain "$2.out") | head -8)"; fi
}
# uc_says <capture> <word> <what>: the first line the run printed is exactly the word
uc_says() {
  local got
  got="$(head -n 1 "$1.out")"
  if [ "$got" = "$2" ]; then uc_ok "$3"; else uc_bad "$3" "printed [$got], wanted [$2]"; fi
}
# uc_json_is <file> <dotted path> <value> <what>: the JSON file holds that string (or number) there
uc_json_is() {
  local got
  got="$("$UC_PY" "$UC_DIR/peek.py" get "$1" "$2")"
  if [ "$got" = "$3" ]; then uc_ok "$4"; else uc_bad "$4" "$2 is [$got], wanted [$3]"; fi
}
# uc_json_has <file> <dotted path> <text> <what>: the value there contains the text
uc_json_has() {
  local got
  got="$("$UC_PY" "$UC_DIR/peek.py" get "$1" "$2")"
  if grep -qF -- "$3" <<<"$got"; then uc_ok "$4"; else uc_bad "$4" "$2 is [$got], wanted it to contain [$3]"; fi
}
# uc_file_unchanged <file> <copy> <what>: the file still holds the bytes of the copy taken before
uc_file_unchanged() {
  if cmp -s "$1" "$2"; then uc_ok "$3"; else uc_bad "$3"; fi
}
