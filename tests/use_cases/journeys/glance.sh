#!/usr/bin/env bash
# shellcheck disable=SC2154 # the variables and helpers below come from lib.sh, which run.sh sources first
# Journeys of someone looking at the bar. The bar is what Claude Code draws under the prompt: hooks/statusline.sh, the session's JSON on stdin, the width in $COLUMNS.

# "I open Claude Code in a repository I have never used it in and glance at the bar."
journey_fresh_session_first_glance() {
  uc_world
  # given: no ledger, no identity (the handle falls back to $USER) and Claude Code's first payload, where the context use is not known yet
  printf '{"workspace":{"current_dir":"%s","project_dir":"%s","repo":{"name":"myapp","branch":"main"}},"model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":null,"total_input_tokens":0,"context_window_size":200000},"session_id":"fresh1","cost":{"total_cost_usd":0,"total_duration_ms":0}}' "$WS" "$WS" >"$UC_TMP/payload.json"
  # when: the bar draws in a 124-cell terminal
  uc_capture fresh uc_claude_code 124 truecolor USER=asha <"$UC_TMP/payload.json"
  # then
  uc_exit_clean "the first draw"
  uc_rows_are "$UC_BASE" 4 "four rows"
  uc_row_has "$UC_BASE" 1 "HEIMDALL" "row 1 carries the brand"
  uc_row_has "$UC_BASE" 1 "asha · Opus 4.8" "row 1 names me (from \$USER) and the model"
  uc_row_has "$UC_BASE" 1 "myapp:main" "row 1 names the repository and the branch"
  uc_row_has "$UC_BASE" 2 "CTX unavailable" "row 2 says the context use is not known yet"
  uc_lacks "$UC_BASE" "CTX 0%" "and never invents a 0%"
  uc_row_has "$UC_BASE" 3 "gates offline" "row 3 says no gate has reported"
}

# "The host hands the bar nothing usable (before the session has data, or a broken payload)": one brand line, never an error.
journey_the_host_sends_garbage() {
  local bad label
  for bad in '' '{bad json' '[1,2,3]'; do
    label="stdin [${bad:-empty}]"
    uc_world
    printf '%s' "$bad" >"$UC_TMP/payload.json"
    uc_capture garbage uc_claude_code 124 truecolor <"$UC_TMP/payload.json"
    uc_exit_clean "$label"
    uc_rows_are "$UC_BASE" 1 "$label: one row"
    uc_has "$UC_BASE" "HEIMDALL" "$label: the brand line"
  done
}

# draws the golden world with <percent> of the context used, on a 124-cell terminal, in a world with nobody else in it
glance_context_at() {
  uc_world
  uc_golden_payload "$1" >"$UC_TMP/payload.json"
  uc_capture "context$1" uc_claude_code 124 truecolor HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" <"$UC_TMP/payload.json"
}

# "I have been working for a while: the bar tells me how full my context is, and warns me when it is nearly full."
journey_work_a_while_and_watch_the_context_fill() {
  local f
  # given the golden world with 42% of the context used; when the bar draws full width
  f="$(uc_golden_hud full truecolor)"
  # then it is the carried golden, and says the numbers
  uc_exit_clean "mid-session at 42%" "$f"
  uc_matches_golden "$f" "$GOLD/density/rj_full_truecolor.txt" "the bar is the carried full-width golden"
  uc_row_has "$f" 1 "heimdall:statusline-v1" "row 1: repository and branch"
  uc_row_has "$f" 2 "CTX 42%" "row 2: the context use"
  uc_row_has "$f" 2 "128k" "row 2: the tokens in the context"
  uc_row_has "$f" 2 '$0.87' "row 2: what the session has cost"
  uc_row_has "$f" 3 "gate 3/3" "row 3: the gates that passed"
  uc_row_has "$f" 4 "7d" "row 4: the seven-day limit"
  uc_row_has "$f" 4 "12%" "row 4: how much of it is used"
  uc_raw_row_lacks "$f" 2 "48;2;255;203;87" "at 42% the bar has no gold warning"
  uc_raw_row_lacks "$f" 2 "48;2;255;107;107" "and no red one"
  # when the context fills past 70%, the end of the bar turns gold; past 90% it turns red
  glance_context_at 80
  uc_row_has "$UC_BASE" 2 "CTX 80%" "at 80% row 2 says so"
  uc_raw_row_has "$UC_BASE" 2 "48;2;255;203;87" "at 80% the end of the bar turns gold"
  uc_raw_row_lacks "$UC_BASE" 2 "48;2;255;107;107" "and is not red yet"
  glance_context_at 95
  uc_row_has "$UC_BASE" 2 "CTX 95%" "at 95% row 2 says so"
  uc_raw_row_has "$UC_BASE" 2 "48;2;255;107;107" "at 95% the end of the bar turns red"
  uc_raw_row_lacks "$UC_BASE" 2 "48;2;255;203;87" "and is no longer gold"
}

# "I shrink my terminal: the bar keeps what matters and never cuts a word in half."
journey_shrink_the_terminal() {
  local narrow tiny
  # given the golden world; when the terminal is 52 cells wide (a 48-cell bar)
  narrow="$(uc_golden_hud narrow truecolor)"
  uc_exit_clean "the 48-cell bar" "$narrow"
  uc_matches_golden "$narrow" "$GOLD/density/rj_narrow_truecolor.txt" "the narrow bar is the carried golden"
  uc_rows_are "$narrow" 4 "still four rows"
  uc_widths_are "$narrow" 48 "every row is exactly 48 cells"
  uc_row_has "$narrow" 1 "HEIMDALL" "the brand stays"
  uc_lacks "$narrow" "Opus 4.8" "whole segments drop when there is no room: the model name is gone"
  uc_lacks "$narrow" "…" "no row is cut in the middle of a word"
  uc_row_has "$narrow" 3 "gate 3/3" "the gate verdict stays"
  uc_row_has "$narrow" 4 "42%" "the limits stay"
  # when it is 34 cells wide (a 30-cell bar), the bar is one line
  tiny="$(uc_golden_hud tiny truecolor)"
  uc_exit_clean "the 30-cell bar" "$tiny"
  uc_matches_golden "$tiny" "$GOLD/density/rj_tiny_truecolor.txt" "the tiny bar is the carried golden"
  uc_rows_are "$tiny" 1 "one line"
  uc_has "$tiny" "HMD 42%" "that says the context use"
}

# "The same bar on every terminal I use": four widths on truecolor, 256-colour and 16-colour terminals.
journey_the_same_bar_on_every_terminal() {
  local tier color f
  for tier in full mid narrow tiny; do
    for color in truecolor 256 16; do
      f="$(uc_golden_hud "$tier" "$color")"
      uc_matches_golden "$f" "$GOLD/density/rj_${tier}_${color}.txt" "$tier width on a $color terminal is the carried golden"
    done
  done
}
