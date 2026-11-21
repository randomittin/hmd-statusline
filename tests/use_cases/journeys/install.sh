#!/usr/bin/env bash
# shellcheck disable=SC2154 # the variables and helpers below come from lib.sh, which run.sh sources first
# Journeys of installing the bar: the registrars write the user's own settings files, and must never overwrite what the user already has.

# "First session after I install: the bar appears, and the next session leaves my settings alone."
journey_install_wires_the_bar_into_claude_code() {
  local settings cmd
  uc_world
  uc_golden_world
  settings="$HOMED/.claude/settings.json"
  # when the SessionStart hook runs the registrar for the first time
  uc_capture register1 uc_in_world HEIMDALL_STATUSLINE_SETTINGS="$settings" bash "$REPO/bin/heimdall-statusline-register" register
  # then
  uc_says "$UC_BASE" registered "the first session registers the bar"
  uc_json_has "$settings" statusLine.command "hooks/statusline.sh" "my settings name hooks/statusline.sh, the path every registered config carries"
  uc_json_is "$settings" statusLine.refreshInterval 2 "Claude Code redraws it every 2 seconds"
  uc_json_has "$settings" subagentStatusLine.command "subagent-statusline.sh" "the subagent rows are wired too"
  cp "$settings" "$UC_TMP/settings.before"
  uc_capture register2 uc_in_world HEIMDALL_STATUSLINE_SETTINGS="$settings" bash "$REPO/bin/heimdall-statusline-register" register
  uc_says "$UC_BASE" current "the second session finds the bar current"
  uc_file_unchanged "$settings" "$UC_TMP/settings.before" "and writes nothing"
  # and the command now in my settings is the one Claude Code runs: it draws the bar
  cmd="$("$UC_PY" "$UC_DIR/peek.py" get "$settings" statusLine.command)"
  uc_golden_payload 42 >"$UC_TMP/payload.json"
  uc_capture registered_command uc_in_world HMD_NOW=7 HMD_STATUSLINE_TMP="$TMPD" COLUMNS=124 COLORTERM=truecolor HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" bash -c "$cmd" <"$UC_TMP/payload.json"
  uc_exit_clean "the registered command"
  uc_rows_are "$UC_BASE" 4 "it draws the four-row bar"
  uc_has "$UC_BASE" "HEIMDALL" "with the brand on it"
}

# "I already have my own status line in Claude Code: installing the bar does not replace it."
journey_install_keeps_the_statusline_i_already_have() {
  local settings
  uc_world
  settings="$HOMED/.claude/settings.json"
  mkdir -p "$HOMED/.claude"
  printf '{"statusLine":{"type":"command","command":"my-own-bar.sh"},"theme":"dark"}' >"$settings"
  uc_capture keep uc_in_world HEIMDALL_STATUSLINE_SETTINGS="$settings" bash "$REPO/bin/heimdall-statusline-register" register
  uc_says "$UC_BASE" kept-custom "the registrar says it kept mine"
  uc_json_is "$settings" statusLine.command my-own-bar.sh "my status line command is untouched"
  uc_json_is "$settings" theme dark "my other settings survive"
  uc_capture keep_status uc_in_world HEIMDALL_STATUSLINE_SETTINGS="$settings" bash "$REPO/bin/heimdall-statusline-register" status
  uc_says "$UC_BASE" kept-custom "and a read-only status agrees"
}

# "I use Cursor: installing wires its status line, leaves my login alone, and can be removed cleanly."
journey_install_wires_the_bar_into_cursor_and_removes_cleanly() {
  local cfg
  uc_world
  cfg="$HOMED/.cursor/cli-config.json"
  mkdir -p "$HOMED/.cursor"
  printf '{"authInfo":{"email":"asha@example.com"}}' >"$cfg"
  uc_capture cursor_register uc_in_world HEIMDALL_CURSOR_CLI_CONFIG="$cfg" bash "$REPO/bin/heimdall-statusline-register-cursor" register
  uc_says "$UC_BASE" registered "the registrar wires Cursor's status line"
  uc_json_is "$cfg" statusLine.command "$REPO/bin/heimdall-statusline" "Cursor spawns bin/heimdall-statusline directly"
  uc_json_is "$cfg" authInfo.email asha@example.com "my Cursor login is untouched"
  uc_capture cursor_again uc_in_world HEIMDALL_CURSOR_CLI_CONFIG="$cfg" bash "$REPO/bin/heimdall-statusline-register-cursor" register
  uc_says "$UC_BASE" current "registering again finds it current"
  uc_capture cursor_remove uc_in_world HEIMDALL_CURSOR_CLI_CONFIG="$cfg" bash "$REPO/bin/heimdall-statusline-register-cursor" unregister
  uc_says "$UC_BASE" unregistered "unregistering removes it"
  if "$UC_PY" "$UC_DIR/peek.py" get "$cfg" statusLine >/dev/null 2>&1; then uc_bad "Cursor's status line is gone after unregister"; else uc_ok "Cursor's status line is gone after unregister"; fi
  uc_json_is "$cfg" authInfo.email asha@example.com "and my Cursor login is still there"
}

# "I already have my own status line in Cursor: installing and removing the bar never touch it."
journey_cursor_install_keeps_the_statusline_i_already_have() {
  local cfg
  uc_world
  cfg="$HOMED/.cursor/cli-config.json"
  mkdir -p "$HOMED/.cursor"
  printf '{"authInfo":{"email":"asha@example.com"},"statusLine":{"type":"command","command":"/usr/local/bin/mine"}}' >"$cfg"
  cp "$cfg" "$UC_TMP/cursor.before"
  uc_capture cursor_keep uc_in_world HEIMDALL_CURSOR_CLI_CONFIG="$cfg" bash "$REPO/bin/heimdall-statusline-register-cursor" register
  uc_says "$UC_BASE" kept-custom "the registrar says it kept mine"
  uc_file_unchanged "$cfg" "$UC_TMP/cursor.before" "and writes nothing"
  uc_capture cursor_keep_remove uc_in_world HEIMDALL_CURSOR_CLI_CONFIG="$cfg" bash "$REPO/bin/heimdall-statusline-register-cursor" unregister
  uc_says "$UC_BASE" kept-custom "unregistering does not remove what is not the bar's"
  uc_file_unchanged "$cfg" "$UC_TMP/cursor.before" "and writes nothing either"
}
