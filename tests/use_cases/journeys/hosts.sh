#!/usr/bin/env bash
# shellcheck disable=SC2154 # the variables and helpers below come from lib.sh, which run.sh sources first
# Journeys of the places the bar runs besides a Claude Code terminal with python3 at hand.

# "I use Cursor: its status line is 48 cells wide however wide the terminal that launched it was."
journey_cursor_user() {
  uc_world
  uc_golden_world
  # given Cursor's payload: the width in render_width_chars, a stale COLUMNS=200 inherited from the launching terminal, and a transcript_path
  uc_golden_payload 42 | sed 's/^{/{"render_width_chars":48,"transcript_path":"\/tmp\/t.jsonl",/' >"$UC_TMP/payload.json"
  # when Cursor runs bin/heimdall-statusline
  uc_capture cursor uc_in_world HMD_NOW=7 HMD_STATUSLINE_TMP="$TMPD" COLUMNS=200 COLORTERM=truecolor HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" "$REPO/bin/heimdall-statusline" <"$UC_TMP/payload.json"
  # then the width is Cursor's, and the bar is the carried 48-cell golden
  uc_exit_clean "Cursor's draw"
  uc_widths_are "$UC_BASE" 48 "every row is 48 cells: render_width_chars wins over COLUMNS"
  uc_matches_golden "$UC_BASE" "$GOLD/density/rj_narrow_truecolor.txt" "and it is the carried 48-cell golden"
  # given Cursor sends no model name on a 120-cell terminal (the model segment fits there), the bar calls it Cursor
  sed -e 's/"display_name":"Opus 4.8"/"display_name":""/' -e 's/"render_width_chars":48/"render_width_chars":120/' "$UC_TMP/payload.json" >"$UC_TMP/payload2.json"
  uc_capture cursor_label uc_in_world HMD_NOW=7 HMD_STATUSLINE_TMP="$TMPD" COLUMNS=200 COLORTERM=truecolor HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" "$REPO/bin/heimdall-statusline" <"$UC_TMP/payload2.json"
  uc_row_has "$UC_BASE" 1 "Cursor" "a Cursor session with no model name is labelled Cursor"
}

# "python3 is missing on this machine": the bar still prints a line and never an error.
journey_python_is_missing() {
  uc_world
  printf '{"workspace":{"current_dir":"/tmp"},"model":{"display_name":"Opus 4.8"}}' >"$UC_TMP/payload.json"
  # when Claude Code runs the bar with no python3 on the PATH
  UC_TOOLS_OVERRIDE="$UC_TMP/tools-nopy" uc_capture nopython uc_in_world COLUMNS=124 bash "$REPO/hooks/statusline.sh" <"$UC_TMP/payload.json"
  # then
  uc_exit_clean "no python3"
  printf '[ heimdall ]\n' >"$UC_TMP/floor.txt"
  uc_matches_golden "$UC_BASE" "$UC_TMP/floor.txt" "the bar prints its one-line floor, [ heimdall ]"
}
