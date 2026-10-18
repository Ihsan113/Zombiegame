# LAN network test tools (not exported to the APK)

`run_loopback.sh` starts a real host and a real client (two headless Godot processes) and connects
them through `netem_proxy.py`, a UDP proxy that adds delay, jitter and packet loss in both directions.
Both processes follow scripted joystick/fire input and write CSV logs; `analyze.py` then reports:

| metric | meaning |
|---|---|
| `own_lag_ms` / `own_rmse_px` | how far the client's own survivor trails an ideal zero-latency copy |
| `remote_lag_ms` / `remote_rmse_px` | delay and smoothness of the other survivor as seen on the client |
| `zombie_lag_ms` / `zombie_rmse_px` | same for zombies |
| `remote_speed_cv` | speed variation of the remote survivor (lower = smoother) |
| `hostview_lag_ms` / `hostview_rmse_px` | how the HOST draws the client's survivor vs the client's own ideal path (the net_test host logs `V` = drawn position) |
| `hostview_speed_cv` / `hostview_stall_pct` / `hostview_jerk_p95` | smoothness of that drawn motion: speed variation, % of moving frames where it is frozen, 95th percentile frame-to-frame speed change |
| `wire_KBps` | bytes per second the client receives on the wire |

Example: `GODOT=./godot tools/net_test/run_loopback.sh wifi 15 10 2` (15 ms ± 10 ms, 2 % loss).

`tests/codec_test.gd` is the CI unit test for the snapshot codec (`godot --headless --path . -s res://tests/codec_test.gd`).
