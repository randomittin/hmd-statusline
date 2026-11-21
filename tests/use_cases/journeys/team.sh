#!/usr/bin/env bash
# shellcheck disable=SC2154 # the variables and helpers below come from lib.sh, which run.sh sources first
# Journeys of people and agents working next to me: the wall of teammates, the swarm of agents, the subagent rows under the transcript.

# "My teammates are online: I see who is on the wall and what state they are in."
journey_see_my_teammates_on_the_wall() {
  local full mid now
  # given the golden world (three teammates online); when the bar draws full width
  full="$(uc_golden_hud full truecolor)"
  uc_row_has "$full" 3 "nadia" "nadia is on the wall"
  uc_row_has "$full" 3 "priya" "priya is on the wall"
  uc_row_has "$full" 3 "arjun" "arjun is on the wall"
  uc_row_has "$full" 4 "deny" "the teammate whose gate was denied shows as denied"
  # when the terminal is 84 cells wide, two fit and the third is counted
  mid="$(uc_golden_hud mid truecolor)"
  uc_row_has "$mid" 3 "+1" "the wall says +1 for the teammate that does not fit"
  # given I am in the roster too, I am the sigil on the left and never a column on my own wall
  uc_world
  mkdir -p "$WS/.heimdall"
  printf '[{"handle":"rj","haid":"rj","verdict":"working","file":"x.py","age_seconds":2},{"handle":"nadia","haid":"haid:nadia","verdict":"working","file":"auth.ts","age_seconds":4}]' >"$WS/.heimdall/.roster-cache.json"
  uc_golden_payload 42 >"$UC_TMP/payload.json"
  uc_capture self uc_claude_code 124 truecolor HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" <"$UC_TMP/payload.json"
  uc_row_has "$UC_BASE" 3 "nadia" "my teammate is on my wall"
  uc_row_lacks "$UC_BASE" 3 "rj" "I am not"
  # given a teammate heartbeat that is fresh and one that went quiet long ago (no server roster)
  uc_world
  mkdir -p "$WS/.heimdall/team"
  now="$(date +%s)"
  printf '{"haid":"nadia-1","name":"nadia","agent":"coder","verdict":"working","file":"auth.ts","ts":%s}' "$now" >"$WS/.heimdall/team/nadia.json"
  printf '{"haid":"kai-1","name":"kai","agent":"coder","verdict":"working","file":"db.ts","ts":1}' >"$WS/.heimdall/team/kai.json"
  uc_golden_payload 42 >"$UC_TMP/payload.json"
  uc_capture heartbeats uc_claude_code 124 truecolor HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" <"$UC_TMP/payload.json"
  uc_row_has "$UC_BASE" 3 "nadia" "the teammate who just beat is on the wall"
  uc_row_lacks "$UC_BASE" 3 "kai" "the one who went quiet has left it"
}

# "I run parallel agents: the bar shows each one that is really running, and nothing for one that died."
journey_run_parallel_agents_and_see_each_one() {
  local p1 p2 ghost now none one
  uc_world
  # given two agents whose processes are alive, one whose process has ended, and a claim naming the coder's file
  uc_sleeper
  p1="$(uc_last_sleeper)"
  uc_sleeper
  p2="$(uc_last_sleeper)"
  ghost="$(uc_dead_pid)"
  mkdir -p "$HOMED/.heimdall" "$WS/.planning/ledger/claims"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"max_agents":4,"agents":{"coder-1":{"status":"active","pid":%s,"type":"coder","started_at":"2026-11-22T10:00:00Z"},"reviewer-1":{"status":"active","pid":%s,"type":"reviewer","started_at":"2026-11-22T10:01:00Z"},"tester-1":{"status":"active","pid":%s,"type":"tester","started_at":"2026-11-22T10:02:00Z"}}}' "$p1" "$p2" "$ghost" >"$HOMED/.heimdall/agent-pool.json"
  printf '{"haid":"coder-1","task_ref":"T1","claimed_surfaces":["src/auth.ts"],"claimed_at":"%s","ttl_minutes":90}' "$now" >"$WS/.planning/ledger/claims/coder-1.json"
  uc_golden_payload 42 >"$UC_TMP/payload.json"
  # when the bar draws
  uc_capture swarm uc_claude_code 124 truecolor HMD_HAID=rj HEIMDALL_IDENTITY_DIR="$WS/.heimdall" <"$UC_TMP/payload.json"
  # then
  uc_exit_clean "two agents running"
  uc_has "$UC_BASE" "swarm 2/4 active" "the swarm block counts the two live agents of four"
  uc_has "$UC_BASE" "coder" "the coder is listed"
  uc_has "$UC_BASE" "src/auth.ts" "with the file it claimed"
  uc_has "$UC_BASE" "reviewer" "the reviewer is listed"
  uc_lacks "$UC_BASE" "tester" "the agent whose process has ended is not listed"
  uc_widths_are "$UC_BASE" 120 "the swarm rows fit the bar"
  # given one live agent alone, the bar is exactly what it is with no agents at all
  uc_world
  uc_golden_payload 42 >"$UC_TMP/payload.json"
  uc_capture none uc_claude_code 124 truecolor HMD_HAID=rj <"$UC_TMP/payload.json"
  none="$UC_BASE"
  mkdir -p "$HOMED/.heimdall"
  printf '{"max_agents":4,"agents":{"coder-1":{"status":"active","pid":%s,"type":"coder","started_at":"2026-11-22T10:00:00Z"}}}' "$p1" >"$HOMED/.heimdall/agent-pool.json"
  uc_capture one uc_claude_code 124 truecolor HMD_HAID=rj <"$UC_TMP/payload.json"
  one="$UC_BASE"
  uc_same_bytes "$none" "$one" "one agent alone does not change the bar"
  uc_stop_sleepers
}

# "A subagent runs under my session: Claude Code shows one progress row for it, and the row goes when it finishes."
journey_subagent_progress_rows() {
  uc_world
  # given two tasks, one running and one completed
  printf '{"columns":120,"tasks":[{"id":"t-run","name":"coder","description":"implement auth","status":"running","startTime":1000,"tokenCount":708000,"model":"opus","contextWindowSize":1000000},{"id":"t-done","name":"reviewer","description":"review pr","status":"completed","startTime":1000,"tokenCount":42000,"model":"sonnet","contextWindowSize":1000000}]}' >"$UC_TMP/payload.json"
  # when Claude Code asks for the subagent rows, 250 seconds after the running one started
  uc_capture subagents uc_in_world HMD_NOW=1250 bash "$REPO/hooks/subagent-statusline.sh" <"$UC_TMP/payload.json"
  # then
  uc_exit_clean "two tasks, one running"
  uc_rows_are "$UC_BASE" 1 "one row, for the running task"
  uc_has "$UC_BASE" '"id": "t-run"' "it is the running task's"
  uc_lacks "$UC_BASE" "t-done" "the completed task has no row"
  uc_has "$UC_BASE" "hmd:coder implement auth" "the row names the agent and its job"
  uc_has "$UC_BASE" "4m10s" "and how long it has run"
  uc_has "$UC_BASE" "708k" "and the tokens it holds"
  uc_has "$UC_BASE" "71%" "and how full its context is"
  # given something that is not JSON, there is nothing to show and nothing to complain about
  printf 'not json at all' >"$UC_TMP/payload.json"
  uc_capture subagents_bad uc_in_world HMD_NOW=1250 bash "$REPO/hooks/subagent-statusline.sh" <"$UC_TMP/payload.json"
  uc_exit_clean "garbage in"
  uc_rows_are "$UC_BASE" 0 "no row"
}
