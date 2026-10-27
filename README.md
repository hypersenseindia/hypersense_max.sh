# Hypersense MAX

A **non-root** Termux performance tool built around burst tuning: short, aggressive passes rather than a permanent setting, with a watchdog that keeps the loop alive and a log of everything it applied.

Android only. Free Fire / Free Fire Max are the tuned targets, but it runs against any foreground app.

## Features

| | |
| --- | --- |
| **Activation** | Local, time-locked key &mdash; no server call |
| **Raw touch** | Direct X/Y touch response tuning |
| **Pre-boost** | Warms the scheduler before the game reaches its heaviest scene |
| **Micro-burst** | Short high-performance windows instead of a constant drain |
| **FPS push** | Frame-rate targeting based on the detected display rate |
| **vPool** | Virtual memory pool to absorb spikes |
| **Watchdog** | Restarts the tuning loop if it is killed |
| **Logs** | CSV of every applied setting, under `$HOME/.local/state/hypersense` |

## Run

```bash
pkg install -y git
git clone https://github.com/hypersenseindia/hypersense_max.sh
cd hypersense_max.sh
chmod +x hypersense_max.sh
./hypersense_max.sh
```

## Where things live

```
~/.config/hypersense/          settings and activation info
~/.local/state/hypersense/     logs and analytics.csv
```

## Notes

- `set -o errexit` and `pipefail` are on: a failed command stops the pass rather than half-applying it.
- Activation is local and time-locked; nothing is transmitted.
- Nothing is written to `/system`. Delete the two directories above to reset completely.
---

<p align="center">
  <sub>Built by <b>AG HYDRAXFF</b> &mdash; HYPERSENSEGLOBAL &middot;
  <a href="https://www.instagram.com/hydraxff_yt/">@hydraxff_yt</a></sub>
</p>