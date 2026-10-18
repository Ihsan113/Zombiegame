#!/bin/bash
# Real host + client (two Godot processes) over UDP through an impairment proxy.
# usage: GODOT=/path/to/godot tools/net_test/run_loopback.sh LABEL DELAY_MS JITTER_MS LOSS_PCT [SECONDS] [BURST]
# example (bad Wi-Fi): GODOT=./godot tools/net_test/run_loopback.sh bad 30 20 6 24 0.3
# Needs: Godot 4.7.x, python3 with numpy. Output: /tmp/pz_net/<LABEL>/ and an analysis printout.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
LABEL=$1; DELAY=$2; JITTER=$3; LOSS=$4; DUR=${5:-24}; BURST=${6:-0}
WORK=/tmp/pz_net/$LABEL; rm -rf "$WORK"; mkdir -p "$WORK"
for role in host client; do
  cp -r "$ROOT" "$WORK/$role"; rm -rf "$WORK/$role/.git"
done
sed -i 's/^const PORT := 24567/const PORT := 24570/' "$WORK/host/scripts/game.gd"
sed -i 's/^const PORT := 24567/const PORT := 24571/' "$WORK/client/scripts/game.gd"
(cd "$WORK/host" && "$GODOT" --headless --editor --path . --quit >/dev/null 2>&1) || true
cp -r "$WORK/host/.godot" "$WORK/client/.godot" 2>/dev/null || true
python3 "$ROOT/tools/net_test/netem_proxy.py" 24571 24570 "$DELAY" "$JITTER" "$LOSS" $((DUR+22)) "$BURST" > "$WORK/proxy.txt" 2>&1 &
PROXY=$!
sleep 0.5
(cd "$WORK/host" && timeout $((DUR+40)) "$GODOT" --headless --path . -s "$ROOT/tools/net_test/net_test.gd" -- role=host out="$WORK/host.csv" dur=$DUR >"$WORK/host.log" 2>&1) &
HOST=$!
sleep 3
(cd "$WORK/client" && timeout $((DUR+40)) "$GODOT" --headless --path . -s "$ROOT/tools/net_test/net_test.gd" -- role=client out="$WORK/client.csv" dur=$DUR ip=127.0.0.1 >"$WORK/client.log" 2>&1) &
CLI=$!
wait $CLI; wait $HOST; kill $PROXY 2>/dev/null || true
python3 "$ROOT/tools/net_test/analyze.py" "$WORK"
