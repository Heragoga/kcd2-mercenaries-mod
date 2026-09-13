#!/usr/bin/env bash
# One tuning cycle: push commands into the running game, wait, grab a screenshot.
#   tools/uicycle.sh <outfile.jpg> "cmd one" "cmd two" ...
# The mod polls merc_ui_ctl.cfg every second, so every command here must be idempotent.
set -u
GAME="C:/Program Files/Steam/steamapps/common/KingdomComeDeliverance2"
CTL="$GAME/merc_ui_ctl.cfg"
SHOTS="C:/Users/Alex/Saved Games/kingdomcome2/screenshots"
OUT="$1"; shift

# the standing state every cycle wants
{
  echo "merc_dev"
  echo "merc_cmd_on"
  for c in "$@"; do echo "$c"; done
} > "$CTL"

sleep 4

before=$(ls -1 "$SHOTS" 2>/dev/null | wc -l)
echo "r_GetScreenShot 1" >> "$CTL"
sleep 3
# drop the screenshot line so it does not fire every poll
{ echo "merc_dev"; echo "merc_cmd_on"; for c in "$@"; do echo "$c"; done; } > "$CTL"

for i in $(seq 1 12); do
  newest=$(ls -1t "$SHOTS" 2>/dev/null | head -1)
  count=$(ls -1 "$SHOTS" 2>/dev/null | wc -l)
  if [ "$count" -gt "$before" ] && [ -n "$newest" ]; then
    # the game is still writing it - wait until the size stops changing, twice
    prev=0; stable=0
    while [ "$stable" -lt 2 ]; do
      sz=$(stat -c %s "$SHOTS/$newest" 2>/dev/null || echo 0)
      if [ "$sz" -gt 0 ] && [ "$sz" -eq "$prev" ]; then stable=$((stable+1)); else stable=0; fi
      prev=$sz; sleep 1
    done
    cp "$SHOTS/$newest" "$OUT"
    echo "shot: $newest ($prev bytes) -> $OUT"
    exit 0
  fi
  sleep 1
done
echo "FAIL: no new screenshot"
exit 1
