# BuildBeacon - aperçu PNG des circuits (face avant et vue du dos), sans KiCad
# Version 1.0 (2026-11-11) - Licence : CERN-OHL-P-2.0
# Usage : python3 render_pcb_v1.0.py buildbeacon_tuile_v1.0.kicad_pcb sortie.png "Titre"
# Lit seulement les éléments que produit gen_buildbeacon_pcb (lignes, pistes, vias,
# pastilles, textes), suffisant pour la documentation.
import re
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyBboxPatch

OX, OY = 150.0, 100.0
BOARD, CU_F, CU_B, PAD, SILK, EDGE = "#1f4d2b", "#c8553d", "#3d7cc8", "#d9a441", "#f2f2f2", "#e8e05a"


def parse(path):
    s = open(path, encoding="utf-8").read()
    num = r"(-?[\d.]+)"
    lines = [(float(a), float(b), float(c), float(d), lay) for a, b, c, d, lay in re.findall(
        r"\(gr_line \(start %s %s\) \(end %s %s\).*?\(layer \"([^\"]+)\"\)" % (num, num, num, num), s)]
    segs = [(float(a), float(b), float(c), float(d), float(w), lay) for a, b, c, d, w, lay in re.findall(
        r"\(segment \(start %s %s\) \(end %s %s\) \(width %s\) \(layer \"([^\"]+)\"\)" % (num, num, num, num, num), s)]
    vias = [(float(a), float(b), float(d)) for a, b, d in re.findall(
        r"\(via \(at %s %s\) \(size %s\)" % (num, num, num), s)]
    texts = []
    for m in re.finditer(r"\(gr_text \"([^\"]*)\" \(at %s %s(?: %s)?\) \(layer \"([^\"]+)\"\).*?\(size %s" % (num, num, num, num), s):
        texts.append((m.group(1), float(m.group(2)), float(m.group(3)), m.group(5), float(m.group(6))))
    pads = []
    for fp in re.finditer(r"\(footprint \"[^\"]+\" \(layer \"([^\"]+)\"\).*?\(at %s %s\)(.*?)\n  \)" % (num, num), s, re.S):
        flay, fx, fy, body = fp.group(1), float(fp.group(2)), float(fp.group(3)), fp.group(4)
        for p in re.finditer(r"\(pad \"[^\"]*\" (\w+) (\w+) \(at %s %s(?: %s)?\) \(size %s %s\)(?: \(drill %s\))?" % (num, num, num, num, num, num), body):
            kind, shape = p.group(1), p.group(2)
            px, py = fx + float(p.group(3)), fy + float(p.group(4))
            ang = float(p.group(5) or 0)
            w, h = float(p.group(6)), float(p.group(7))
            if round(ang) % 180 == 90:
                w, h = h, w
            drill = float(p.group(8)) if p.group(8) else 0
            pads.append((px, py, w, h, shape, kind, flay, drill))
    return lines, segs, vias, texts, pads


def draw(ax, data, back):
    lines, segs, vias, texts, pads = data
    sx = -1 if back else 1
    T = lambda x, y: (sx * (x - OX), -(y - OY))
    ax.set_facecolor("#111111")
    edge = [l for l in lines if l[4] == "Edge.Cuts"]
    # fond de carte : polygone du contour (segments chaînés)
    pts = [T(l[0], l[1]) for l in edge]
    if pts:
        ax.fill([p[0] for p in pts], [p[1] for p in pts], color=BOARD, zorder=0)
    for l in edge:
        a, b = T(l[0], l[1]), T(l[2], l[3])
        ax.plot([a[0], b[0]], [a[1], b[1]], color=EDGE, lw=1.2, zorder=1)
    near, far = ("B.Cu", "F.Cu") if back else ("F.Cu", "B.Cu")
    for layer, col, alpha, z in ((far, CU_F if far == "F.Cu" else CU_B, 0.25, 2), (near, CU_F if near == "F.Cu" else CU_B, 0.95, 3)):
        for x1, y1, x2, y2, w, lay in segs:
            if lay == layer:
                a, b = T(x1, y1), T(x2, y2)
                ax.plot([a[0], b[0]], [a[1], b[1]], color=col, lw=w * 3.2, alpha=alpha, solid_capstyle="round", zorder=z)
    for x, y, d in vias:
        c = T(x, y)
        ax.add_patch(Circle(c, d / 2, color=PAD, zorder=4)); ax.add_patch(Circle(c, d / 4, color="#111111", zorder=5))
    side = "B.Cu" if back else "F.Cu"
    for px, py, w, h, shape, kind, flay, drill in pads:
        if kind == "smd" and flay != side:
            continue
        cx, cy = T(px, py)
        if shape == "circle":
            ax.add_patch(Circle((cx, cy), w / 2, color=PAD, zorder=6))
        else:
            ax.add_patch(FancyBboxPatch((cx - w / 2, cy - h / 2), w, h, boxstyle="round,pad=0,rounding_size=%s" % (0.25 * min(w, h) if shape == "roundrect" else 0.01),
                                        color=PAD, zorder=6))
        if drill:
            ax.add_patch(Circle((cx, cy), drill / 2, color="#111111", zorder=7))
    silk = "B.SilkS" if back else "F.SilkS"
    for l in lines:
        if l[4] == silk:
            a, b = T(l[0], l[1]), T(l[2], l[3])
            ax.plot([a[0], b[0]], [a[1], b[1]], color=SILK, lw=0.8, zorder=8)
    for txt, x, y, lay, size in texts:
        if lay == silk:
            c = T(x, y)
            ax.text(c[0], c[1], txt, color=SILK, fontsize=size * 7.5, ha="center", va="center", zorder=9, fontweight="bold")
    ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    for sp in ax.spines.values():
        sp.set_visible(False)


def main():
    src, out, title = sys.argv[1], sys.argv[2], sys.argv[3]
    data = parse(src)
    fig, axs = plt.subplots(1, 2, figsize=(16, 8.4), facecolor="#111111")
    for ax, back, sub in ((axs[0], False, "front / face avant"), (axs[1], True, "back / dos (connecteurs, cavaliers)")):
        draw(ax, data, back)
        ax.set_title("%s — %s" % (title, sub), color="white", fontsize=13)
    plt.tight_layout()
    plt.savefig(out, dpi=110, facecolor="#111111")


if __name__ == "__main__":
    main()
