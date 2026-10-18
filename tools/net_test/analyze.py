import sys
from collections import defaultdict

import numpy as np


def load(path):
    rows = defaultdict(list)
    with open(path) as f:
        for line in f:
            p = line.strip().split(",")
            if p[0] in ("H", "C", "Z", "Y"):
                rows[(p[0], int(p[2]))].append((float(p[1]), float(p[3]), float(p[4])))
            elif p[0] == "I":
                rows[("I", 0)].append((float(p[1]), float(p[2]), float(p[3])))
            elif p[0] == "D":
                rows[("D", 0)].append((float(p[1]), 0.0, 0.0))
            elif p[0] == "S":
                rows[("S", 0)].append((float(p[1]), float(p[2]), p[3], p[4]))
    return rows


def series(rows):
    a = np.array(rows)
    return a[:, 0], a[:, 1:3]


def best_lag(shown_t, shown_xy, truth_t, truth_xy, lags_ms=range(0, 420, 5)):
    """Delay D (ms) that makes shown(t) best match truth(t - D); returns (D, rmse px)."""
    best = (None, 1e9)
    mask = (shown_t > truth_t[0] + 0.5) & (shown_t < truth_t[-1])
    for d in lags_ms:
        tt = shown_t - d / 1000.0
        ok = mask & (tt > truth_t[0])
        if ok.sum() < 20:
            continue
        tx = np.interp(tt[ok], truth_t, truth_xy[:, 0])
        ty = np.interp(tt[ok], truth_t, truth_xy[:, 1])
        err = np.sqrt(np.mean((shown_xy[ok, 0] - tx) ** 2 + (shown_xy[ok, 1] - ty) ** 2))
        if err < best[1]:
            best = (d, err)
    return best


def analyse(folder):
    host = load(folder + "/host.csv")
    cli = load(folder + "/client.csv")
    res = {}
    cutoff = None
    if ("D", 0) in cli:
        cutoff = cli[("D", 0)][0][0] - 0.3
        for key in list(cli.keys()):
            if key[0] in ("C", "Y", "I"):
                cli[key] = [r for r in cli[key] if r[0] < cutoff]
        res["cut_at_death_s"] = round(cutoff - cli[("C", 1)][0][0], 1)
    client_ids = [k[1] for k in cli if k[0] == "C" and k[1] != 1]
    if not client_ids:
        return None
    me = client_ids[0]
    # 1) own character vs ideal zero-latency integration
    st, sxy = series(cli[("C", me)])
    it, ixy = series(cli[("I", 0)])
    d_own, e_own = best_lag(st, sxy, it, ixy)
    res["own_lag_ms"], res["own_rmse_px"] = d_own, e_own
    mask = st > st[0] + 2.0
    shown_at = np.interp(st[mask], it, ixy[:, 0])
    res["own_mean_abs_x_px"] = float(np.mean(np.abs(shown_at - sxy[mask, 0])))
    # 2) host-controlled survivor as seen on the client
    rt, rxy = series(cli[("C", 1)])
    ht, hxy = series(host[("H", 1)])
    d_rem, e_rem = best_lag(rt, rxy, ht, hxy)
    res["remote_lag_ms"], res["remote_rmse_px"] = d_rem, e_rem
    # smoothness: per-frame speed variation while the remote is moving
    dt = np.diff(rt)
    sp = np.hypot(np.diff(rxy[:, 0]), np.diff(rxy[:, 1])) / np.maximum(dt, 1e-4)
    htm = np.interp(rt[1:], ht, hxy[:, 0])
    htm_prev = np.interp(rt[:-1], ht, hxy[:, 0])
    moving = np.abs(htm - htm_prev) > 0.05
    moving &= rt[1:] > rt[0] + 2.0
    if moving.sum() > 20:
        s = sp[moving]
        res["remote_speed_cv"] = float(np.std(s) / max(np.mean(s), 1e-6))
        res["remote_stall_pct"] = float(100.0 * np.mean(s < 5.0))
    # 3) zombies
    per_lag = []
    sq = []
    n = 0
    for key in list(cli.keys()):
        if key[0] != "Y":
            continue
        zid = key[1]
        if ("Z", zid) not in host:
            continue
        zt, zxy = series(host[("Z", zid)])
        yt, yxy = series(cli[key])
        if len(yt) < 60 or len(zt) < 60:
            continue
        d, e = best_lag(yt, yxy, zt, zxy, lags_ms=range(0, 420, 10))
        if d is None:
            continue
        per_lag.append(d)
        sq.append(e)
    if per_lag:
        res["zombie_lag_ms"] = float(np.median(per_lag))
        res["zombie_rmse_px"] = float(np.median(sq))
        res["zombies_tracked"] = len(per_lag)
    # 4) traffic
    s = cli[("S", 0)]
    byts = [r[1] for r in s][2:]
    res["wire_KBps"] = float(np.mean(byts) / 1024.0) if byts else 0.0
    perr = []
    for r in s:
        try:
            perr.append(float(r[2]))
        except ValueError:
            pass
    if perr and any(v != 0 for v in perr):
        res["pred_err_px_avg"] = float(np.mean(perr))
    return res


if __name__ == "__main__":
    for folder in sys.argv[1:]:
        r = analyse(folder)
        print(folder.split("/")[-1])
        if r is None:
            print("  (no data)")
            continue
        for k, v in r.items():
            print(f"  {k:20s} {v:10.2f}" if isinstance(v, float) else f"  {k:20s} {v}")
