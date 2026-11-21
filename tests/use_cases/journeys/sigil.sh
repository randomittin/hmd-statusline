#!/usr/bin/env bash
# shellcheck disable=SC2154 # the variables and helpers below come from lib.sh, which run.sh sources first
# Journeys of the sigil, the hero mark of an identity: in the terminal (bin/heimdall-sigil) and as a PNG (bin/heimdall-sigil-png).

# "Show me my sigil": three sizes on three colour classes of terminal.
journey_show_my_sigil() {
  local size tier
  uc_world
  for size in S M L; do
    for tier in truecolor 256 16; do
      uc_capture "sigil-$size-$tier" uc_in_world "$REPO/bin/heimdall-sigil" --seed rj --size "$size" --tier "$tier"
      uc_matches_golden "$UC_BASE" "$GOLD/sigil/rj_${size}_${tier}.txt" "rj's $size sigil on a $tier terminal is the carried golden"
    done
  done
}

# "Give my sigil a PNG for my avatar": a real PNG, the same bytes every time.
journey_give_my_sigil_a_png_avatar() {
  local magic
  uc_world
  uc_capture png1 uc_in_world "$REPO/bin/heimdall-sigil-png" --seed rj --out "$WS/me.png"
  uc_exit_clean "exporting the avatar"
  magic="$(head -c 4 "$WS/me.png" | tail -c 3)"
  if [ "$magic" = PNG ]; then uc_ok "the file is a PNG"; else uc_bad "the file is a PNG" "starts with [$magic]"; fi
  uc_capture png2 uc_in_world "$REPO/bin/heimdall-sigil-png" --seed rj --out "$WS/me2.png"
  if cmp -s "$WS/me.png" "$WS/me2.png"; then uc_ok "exporting again gives the same bytes"; else uc_bad "exporting again gives the same bytes"; fi
}
