#!/usr/bin/env bash
# tests/use_cases/run.sh -- the `use-cases` check of .heimdall/repo-checks.json: what a person does with the bar, run through the repo's real entry points.
#
#   bash tests/use_cases/run.sh [text]      every journey, or only the journeys whose name contains the text
#
# The journeys (one per thing a user comes to the bar for; the list is the suite's spec, see README.md):
#   fresh session first glance                  I open Claude Code in a new repository and look at the bar
#   the host sends garbage                      before the session has data, or with a broken payload: one brand line, never an error
#   work a while and watch the context fill     42% is the carried golden; the end of the bar turns gold past 70% and red past 90%
#   shrink the terminal                         a 48-cell bar and a one-line 30-cell bar, the carried goldens, no word cut in half
#   the same bar on every terminal              4 widths x truecolor / 256 / 16 colours = the 12 carried density goldens
#   see my teammates on the wall                names and states, +N when they do not fit, never me, and the one who went quiet is gone
#   run parallel agents and see each one        the swarm block lists live agents only; one agent alone changes nothing
#   subagent progress rows                      one faint row per running subagent under the transcript
#   cursor user                                 Cursor's width wins over a stale COLUMNS; a nameless model is labelled Cursor
#   python is missing                           the bar prints [ heimdall ] and exits 0
#   install wires the bar into claude code      registered, then current, and the command written draws the bar
#   install keeps the statusline i already have mine is never replaced
#   install wires the bar into cursor ...       registered, current, unregistered; the Cursor login is never touched
#   cursor install keeps the statusline ...     mine is never replaced or removed
#   show my sigil                               3 sizes x 3 colour classes = the 9 carried sigil goldens
#   give my sigil a png avatar                  a real PNG, the same bytes every time
#
# Hermetic: no network, no heimdall, a frozen clock, a new HOME per journey (lib.sh). Exit 0 when every journey passes, 1 when one fails, 2 when it cannot run.
set -u
UC_RUN_DIR="$(cd "$(dirname "$0")" && pwd)" || exit 2
# shellcheck source=lib.sh
. "$UC_RUN_DIR/lib.sh"
for journey_file in "$UC_RUN_DIR"/journeys/*.sh; do
  # shellcheck source=/dev/null
  . "$journey_file"
done
uc_init || exit 2

filter="${1:-}"
journeys=0
assertions=0
failed=0
names="$(compgen -A function | grep '^journey_' | sort)"
for fn in $names; do
  case "$fn" in *"$filter"*) ;; *) continue ;; esac
  journeys=$((journeys + 1))
  printf '\n%s\n' "journey: $(printf '%s' "${fn#journey_}" | tr '_' ' ')"
  rm -f "$UC_TMP/result"
  (
    trap uc_stop_sleepers EXIT
    "$fn"
    printf '%s %s\n' "$UC_PASS" "$UC_FAIL" >"$UC_TMP/result"
  )
  if [ -f "$UC_TMP/result" ]; then
    read -r passed bad <"$UC_TMP/result"
  else
    passed=0
    bad=1
    echo "    FAIL the journey stopped before it finished"
  fi
  assertions=$((assertions + passed + bad))
  failed=$((failed + bad))
done

printf '\nuse-cases: %s journeys, %s checks, %s failed\n' "$journeys" "$assertions" "$failed"
if [ "$journeys" -eq 0 ]; then
  echo "use-cases: no journey is named like '$filter'" >&2
  exit 2
fi
[ "$failed" -eq 0 ]
