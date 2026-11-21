#!/usr/bin/env bash
# scripts/lint.sh -- the `lint` check of .heimdall/repo-checks.json: every script parses, the entry points the registrars and Cursor run are executable, the
# static analysers that are installed find nothing, and no runtime cache is committed.
#
# Static analysis: shellcheck covers what ships (hooks, bin, sentinels/*.sh) and what this repo added (scripts, tests/use_cases); the carried test/ and conformance/ files (the suites,
# the fixtures and the host helpers copied beside them) are history kept byte for byte, so they are only syntax-checked. ruff runs only the rules that find real bugs (syntax errors,
# undefined names), over the renderers, scripts/carried_suites.py, the carried test/lib helpers and the journeys' python.
# python3 -m py_compile writes its bytecode to a scratch directory, so the work tree stays clean. A missing shellcheck or ruff is said, not hidden.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

FAILED=0
ok() { printf 'lint: ok   %s\n' "$1"; }
skip() { printf 'lint: skip %s\n' "$1"; }
fail() {
  printf 'lint: FAIL %s\n' "$1" >&2
  FAILED=1
}

# the shell scripts, found by their first line (bin/ has no file extensions)
shell_files() {
  local f
  find hooks bin sentinels scripts tests test conformance -type f ! -path '*/__pycache__/*' 2>/dev/null | sort | while IFS= read -r f; do
    case "$(head -n 1 "$f" 2>/dev/null)" in
      '#!/usr/bin/env bash'* | '#!/bin/bash'* | '#!/bin/sh'* | '#!/usr/bin/env sh'*) printf '%s\n' "$f" ;;
    esac
  done
}

parses=1
while IFS= read -r script; do
  if ! bash -n "$script" 2>/dev/null; then
    fail "bash -n: $script does not parse"
    parses=0
  fi
done < <(shell_files)
[ "$parses" = 1 ] && ok "every shell script parses (bash -n)"

for entry in hooks/statusline.sh hooks/subagent-statusline.sh bin/heimdall-statusline bin/heimdall-statusline-register bin/heimdall-statusline-register-cursor bin/heimdall-sigil bin/heimdall-sigil-png; do
  if [ ! -x "$entry" ]; then fail "$entry is not executable (the registrars and Cursor run it directly)"; fi
done

if command -v python3 >/dev/null 2>&1; then
  pycache="$(mktemp -d)"
  if PYTHONPYCACHEPREFIX="$pycache" python3 -m py_compile sentinels/*.py scripts/*.py test/lib/*.py tests/use_cases/*.py; then
    ok "every python source compiles"
  else
    fail "py_compile: a python source does not compile"
  fi
  rm -rf "$pycache"
else
  fail "python3 is not installed (the renderers are python)"
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning -x hooks/*.sh bin/* sentinels/*.sh scripts/*.sh tests/use_cases/*.sh tests/use_cases/journeys/*.sh; then
    ok "shellcheck (warning and above) finds nothing in the runtime, the scripts and the journeys"
  else
    fail "shellcheck found problems"
  fi
else
  skip "shellcheck is not installed"
fi

if command -v ruff >/dev/null 2>&1; then
  if ruff check --no-cache --isolated --select E9,F63,F7,F82 sentinels scripts test/lib tests/use_cases; then
    ok "ruff finds no syntax error or undefined name"
  else
    fail "ruff found problems"
  fi
else
  skip "ruff is not installed"
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  litter="$(git ls-files | grep -E '(^|/)__pycache__/|\.pyc$|^\.heimdall/(receipts/|\.)' || true)"
  if [ -n "$litter" ]; then fail "runtime files are committed: $litter"; else ok "no runtime cache is committed"; fi
fi

if [ "$FAILED" = 0 ]; then echo "lint: clean"; fi
exit "$FAILED"
