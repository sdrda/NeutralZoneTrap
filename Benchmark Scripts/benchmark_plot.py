"""
Plot benchmark CSV vygenerovaného `BenchmarkLogger`em v aplikaci
(zapisuje do `~/Documents/nzt-benchmark-<timestamp>.csv` při spuštění
s `--benchmark` flagem).

Vykreslí dva grafy:

  1. Latence: přijetí paketu → render frame, který ho použil
     (jak dlouho trvá interní pipeline mezi `UDPReceiver` a RealityKit).
  2. Latence: odeslání z localhostu → render frame
     (end-to-end, včetně síťové vrstvy lo0).

Oba grafy zachycují závislost latence na počtu aktivních senzorů ve
scéně a porovnávají ji s hranicí 100 ms ze nefunkčních požadavků.

Spuštění:
    python3 benchmark_plot.py                       # poslední CSV v ~/Documents
    python3 benchmark_plot.py path/to/file.csv      # konkrétní soubor
    python3 benchmark_plot.py --save out.png        # uloží PNG místo zobrazení
"""

import argparse
import csv
import glob
import os
from collections import defaultdict
from pathlib import Path
from statistics import median

import matplotlib.pyplot as plt

THRESHOLD_MS = 100.0


def find_latest_csv(directory: Path) -> Path:
    pattern = str(directory / "nzt-benchmark-*.csv")
    files = glob.glob(pattern)
    if not files:
        raise FileNotFoundError(f"No CSV files matching {pattern}")
    return Path(max(files, key=os.path.getmtime))


def load(csv_path: Path):
    counts, latency, sent_to_render = [], [], []
    with open(csv_path) as f:
        for row in csv.DictReader(f):
            counts.append(int(row["active_count_at_render"]))
            latency.append(float(row["latency_ms"]))
            sent_to_render.append(float(row["sent_to_render_ms"]))
    return counts, latency, sent_to_render


def median_per_count(counts, values):
    """Spočítá medián hodnot pro každou unikátní hodnotu počtu senzorů."""
    buckets: dict[int, list[float]] = defaultdict(list)
    for c, v in zip(counts, values):
        buckets[c].append(v)
    xs = sorted(buckets)
    ys = [median(buckets[x]) for x in xs]
    return xs, ys


def plot_panel(ax, counts, values, title, color):
    ax.scatter(counts, values, s=6, alpha=0.25, color=color, label="vzorky")

    xs_med, ys_med = median_per_count(counts, values)
    ax.plot(xs_med, ys_med, color=color, linewidth=2.0, label="medián")

    ax.axhline(
        THRESHOLD_MS,
        color="red",
        linestyle="--",
        linewidth=1.5,
        label=f"hranice {THRESHOLD_MS:.0f} ms (nefunkční požadavek)",
    )
    ax.set_ylabel("latence (ms)")
    ax.set_title(title)
    ax.grid(True, alpha=0.3)
    ax.legend(loc="upper left", fontsize=9)


def main():
    parser = argparse.ArgumentParser(description="Plot NZT benchmark CSV")
    parser.add_argument(
        "csv",
        nargs="?",
        help="cesta k CSV (default: poslední v ~/Documents)",
    )
    parser.add_argument(
        "--save",
        help="uloží graf do tohoto souboru místo interaktivního zobrazení",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv) if args.csv else find_latest_csv(Path.home() / "Documents")
    print(f"reading {csv_path}")

    counts, latency, sent_to_render = load(csv_path)
    if not counts:
        raise SystemExit("CSV neobsahuje žádné vzorky")

    print(
        f"loaded {len(counts)} samples, "
        f"active count {min(counts)}–{max(counts)}, "
        f"latency {min(latency):.1f}–{max(latency):.1f} ms, "
        f"sent→render {min(sent_to_render):.1f}–{max(sent_to_render):.1f} ms"
    )

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(11, 8), sharex=True)

    plot_panel(
        ax1,
        counts,
        latency,
        "Latence: přijetí paketu → render frame",
        color="tab:blue",
    )
    plot_panel(
        ax2,
        counts,
        sent_to_render,
        "Latence: odeslání z localhostu → render frame (end-to-end)",
        color="tab:orange",
    )
    ax2.set_xlabel("počet aktivních senzorů ve scéně")

    fig.suptitle(f"Benchmark — {csv_path.name}", fontsize=11)
    fig.tight_layout()

    if args.save:
        fig.savefig(args.save, dpi=200, bbox_inches="tight")
        print(f"saved → {args.save}")
    else:
        plt.show()


if __name__ == "__main__":
    main()
