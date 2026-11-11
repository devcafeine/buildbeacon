# BuildBeacon - générateur des circuits imprimés (KiCad 8/9, sans pcbnew)
# Version 1.0 (2026-11-11) - produit buildbeacon_tuile_v1.0 et buildbeacon_master_v1.0
# Source : https://github.com/devcafeine/buildbeacon (hardware/pcb) - Licence : CERN-OHL-P-2.0
#
# Usage :
#   python3 gen_buildbeacon_pcb_v1.0.py          -> buildbeacon_tuile_v<VERSION>.kicad_pcb  (tuile projet)
#   python3 gen_buildbeacon_pcb_v1.0.py --logo   -> buildbeacon_master_v<VERSION>.kicad_pcb (tuile master)
# Ensuite dans KiCad : ouvrir, enregistrer (format récent), touche B (remplir les zones), DRC.
# Repère : vue de face, x vers la droite, y vers le haut, en mm, origine au centre de la tuile.
import uuid

OX, OY = 150.0, 100.0
out = []


def U():
    return '(uuid "%s")' % uuid.uuid4()


def X(x):
    return round(OX + x, 4)


def Y(y):
    return round(OY - y, 4)


def f(v):
    return ("%.4f" % v).rstrip("0").rstrip(".")


NETS = ["", "+5V", "GND", "DATA_IN", "DATA_OUT", "S1_DIN", "S2_DIN", "S3_DIN"]
NID = {n: i for i, n in enumerate(NETS)}


def netref(n):
    return '(net %d "%s")' % (NID[n], n) if n else ""


FONT = "(effects (font (size %s %s) (thickness 0.15))%s)"


def gr_text(s, x, y, h=1.0, back=False):
    out.append('  (gr_text "%s" (at %s %s 0) (layer "%s") %s %s)' % (
        s, f(X(x)), f(Y(y)), "B.SilkS" if back else "F.SilkS", U(),
        FONT % (h, h, " (justify mirror)" if back else "")))


def gr_line(x1, y1, x2, y2, layer, w=0.15):
    out.append('  (gr_line (start %s %s) (end %s %s) (stroke (width %s) (type default)) (layer "%s") %s)' % (
        f(X(x1)), f(Y(y1)), f(X(x2)), f(Y(y2)), w, layer, U()))


def gr_rect(x1, y1, x2, y2, layer="F.SilkS"):
    pts = [(x1, y1), (x2, y1), (x2, y2), (x1, y2)]
    for i in range(4):
        gr_line(*pts[i], *pts[(i + 1) % 4], layer)


def footprint(name, ref, value, x, y, pads, circle=None, hole=False):
    """pads : (num, x_abs, y_abs, forme, larg, haut, percage, net) en vue de face."""
    L = ['  (footprint "BuildBeacon:%s" (layer "F.Cu") %s (at %s %s)' % (name, U(), f(X(x)), f(Y(y)))]
    for prop, val in (("Reference", ref), ("Value", value)):
        L.append('    (property "%s" "%s" (at 0 0 0) (layer "F.Fab") %s %s)' % (
            prop, val, U(), FONT % (0.8, 0.8, "")))
    L.append("    (attr %s)" % ("exclude_from_pos_files exclude_from_bom" if hole else "through_hole"))
    if circle:
        L.append('    (fp_circle (center 0 0) (end %s 0) (stroke (width 0.15) (type solid)) (fill none) (layer "F.SilkS") %s)' % (circle, U()))
    for num, px, py, shape, sx, sy, drill, n in pads:
        dx, dy = f(px - x), f(-(py - y))
        if hole:
            L.append('    (pad "" np_thru_hole circle (at %s %s) (size %s %s) (drill %s) (layers "*.Cu" "*.Mask") %s)' % (
                dx, dy, sx, sy, drill, U()))
        else:
            L.append('    (pad "%s" thru_hole %s (at %s %s) (size %s %s) (drill %s) (layers "*.Cu" "*.Mask") %s %s)' % (
                num, shape, dx, dy, sx, sy, drill, netref(n), U()))
    L.append("  )")
    out.extend(L)



# ================================================================ version "morceaux de ruban"
# Ruban WS2812B 100 LED/m, 10 mm de large. Pastilles au point de coupe, ruban a plat,
# fleche vers la droite, de haut en bas : GND / DIN / 5V. Pas presume : 3,3 mm.
PITCH = 3.3
PAD_IN, PAD_OUT = 1.5, 2.0          # longueur de pastille sous le ruban / qui depasse du ruban


def smd_footprint(name, ref, x, y, pads):
    L = ['  (footprint "BuildBeacon:%s" (layer "F.Cu") %s (at %s %s)' % (name, U(), f(X(x)), f(Y(y)))]
    for prop, val in (("Reference", ref), ("Value", name)):
        L.append('    (property "%s" "%s" (at 0 0 0) (layer "F.Fab") %s %s)' % (prop, val, U(), FONT % (0.8, 0.8, "")))
    L.append("    (attr smd)")
    for num, px, py, sx, sy, n in pads:
        L.append('    (pad "%s" smd rect (at %s %s) (size %s %s) (layers "F.Cu" "F.Mask") %s %s)' % (
            num, f(px - x), f(-(py - y)), sx, sy, netref(n), U()))
    L.append("  )")
    out.extend(L)


def via(x, y, n="GND"):
    out.append('  (via (at %s %s) (size 0.6) (drill 0.3) (layers "F.Cu" "B.Cu") (net %d) %s)' % (
        f(X(x)), f(Y(y)), NID[n], U()))


def track(pts, n, w=0.3, layer="F.Cu"):
    for a, c in zip(pts, pts[1:]):
        out.append('  (segment (start %s %s) (end %s %s) (width %s) (layer "%s") (net %d) %s)' % (
            f(X(a[0])), f(Y(a[1])), f(X(c[0])), f(Y(c[1])), w, layer, NID[n], U()))


def strip(ref, x1, x2, y, din, dout, reverse, vnet="+5V"):
    """Morceau de ruban de x1 a x2 (x1 < x2). reverse=True : donnee de droite a gauche."""
    order = ["GND", "D", "5V"]                       # de haut en bas, fleche vers la droite
    if reverse:
        order = order[::-1]
    ys = {order[0]: y + PITCH, order[1]: y, order[2]: y - PITCH}
    ends = [(x1, "L"), (x2, "R")]
    pads, gnd_vias = [], []
    for e, side in ends:
        cx = e + (PAD_IN - PAD_OUT) / 2 if side == "L" else e - (PAD_IN - PAD_OUT) / 2
        is_in = (side == "L") != reverse
        for sig in ("GND", "D", "5V"):
            n = {"GND": "GND", "5V": vnet, "D": din if is_in else dout}[sig]
            pads.append(("%s%s" % ("IN_" if is_in else "OUT_", sig), cx, ys[sig], PAD_IN + PAD_OUT, 2.0, n))
        gx = e - PAD_OUT - 1.5 if side == "L" else e + PAD_OUT + 1.5
        if (side == "L" and (x1 < -20 or y > 10)) or (side == "R" and x2 > 20):
            gx = e + 3.5 if side == "L" else e - 3.5   # ruban long : via cote interieur
        track([(cx, ys["GND"]), (gx, ys["GND"])], "GND", 0.5)
        via(gx, ys["GND"])
    smd_footprint("Ruban_WS2812B_10mm", ref, (x1 + x2) / 2, y, pads)
    # silhouette du ruban + sens de la donnee
    gr_rect(x1, y - 5, x2, y + 5)
    arrow = "<<<  DIN" if reverse else "DIN  >>>"
    gr_text(arrow, (x1 + x2) / 2, y + (3.6 if not reverse else -3.6), 0.9)
    return {s: ys[s] for s in ys}



# ================================================================ CARTE HEXAGONALE
# 6 connecteurs JST PH 3 broches (un par cote, au dos) + interrupteurs DIP CMS au dos
# pour choisir le cote d'entree (IN) et de sortie (OUT).
import math, sys
MASTER = "--logo" in sys.argv
VERSION = "1.0"          # a incrementer a chaque modification de carte
OUTFILE = ("buildbeacon_master_v%s.kicad_pcb" if MASTER else "buildbeacon_tuile_v%s.kicad_pcb") % VERSION
NETS[:] = ["", "+5V", "GND", "DI", "DO", "S1_DIN", "S2_DIN", "S3_DIN"] + ["SIDE%d" % i for i in range(1, 7)] + ["GPIO4", "VLED"]
NID.clear(); NID.update({n: i for i, n in enumerate(NETS)})

RP = 34.0                                   # hexagone : sommets vers le milieu des cotes de la tuile


def P(r, deg, t=0.0):
    a = math.radians(deg)
    return (r * math.cos(a) - t * math.sin(a), r * math.sin(a) + t * math.cos(a))


def smd_b(name, ref, x, y, pads):
    L = ['  (footprint "BuildBeacon:%s" (layer "B.Cu") %s (at %s %s)' % (name, U(), f(X(x)), f(Y(y)))]
    for prop, val in (("Reference", ref), ("Value", name)):
        L.append('    (property "%s" "%s" (at 0 0 0) (layer "B.Fab") %s %s)' % (prop, val, U(), FONT % (0.8, 0.8, " (justify mirror)")))
    L.append("    (attr smd)")
    for num, px, py, sx, sy, n in pads:
        L.append('    (pad "%s" smd rect (at %s %s) (size %s %s) (layers "B.Cu" "B.Mask") %s %s)' % (
            num, f(px - x), f(-(py - y)), sx, sy, netref(n), U()))
    L.append("  )")
    out.extend(L)


def two(name, ref, val, x1, y1, x2, y2, n1, n2):
    footprint(name, ref, val, (x1 + x2) / 2, (y1 + y2) / 2,
              [("1", x1, y1, "rect", 1.6, 1.6, 0.8, n1), ("2", x2, y2, "circle", 1.6, 1.6, 0.8, n2)])


YK = [6.35, 3.81, 1.27, -1.27, -3.81, -6.35]   # rangees des interrupteurs 1..6


def dip(ref, cx, rowA_x, rowB_x, side_nets, bus):
    pads = []
    for k in range(6):
        pads.append((str(k + 1), rowA_x, YK[k], 2.8, 1.2, side_nets[k]))
        pads.append((str(12 - k), rowB_x, YK[k], 2.8, 1.2, bus))
    smd_b("DIP_SMD_6pos_P2.54", ref, cx, 0, pads)
    gr_rect(min(rowA_x, rowB_x) + 1.6, -8.2, max(rowA_x, rowB_x) - 1.6, 8.2, "B.SilkS")



# ================================================================ v3 : composants CMS au dos (assembles par JLCPCB)
# J1..J6 : JST S3B-PH-SM4-TB (C265101), centres sur chaque cote, ouverture vers la paroi
# SW_IN / SW_OUT : KingTek DSHP06TS (C40737), empreinte KiCad exacte
JST_PADS = [("1", -2, -2.85, 1, 3.5, 0.25), ("2", 0, -2.85, 1, 3.5, 0.25), ("3", 2, -2.85, 1, 3.5, 0.25),
            ("MP", -4.35, 2.9, 1.5, 3.4, 0.166667), ("MP", 4.35, 2.9, 1.5, 3.4, 0.166667)]
DIP_PADS = [(str(k), -3.81, -3.175 + 1.27 * (k - 1), 1.27, 0.76, 0.25) for k in range(1, 7)] + \
           [(str(13 - k), 3.81, -3.175 + 1.27 * (k - 1), 1.27, 0.76, 0.25) for k in range(1, 7)]


def back_fp(name, ref, ox, oy, ang, pads, nets):
    """Empreinte de bibliotheque montee AU DOS. pads = coordonnees de la bibliotheque KiCad (y vers le bas).
    Au dos, vue de face = miroir gauche/droite ; on calcule la position reelle de chaque pastille
    et on l'ecrit en relatif (empreinte a 0 deg, angle porte par les pastilles)."""
    L = ['  (footprint "%s" (layer "B.Cu") %s (at %s %s)' % (name, U(), f(X(ox)), f(Y(oy)))]
    for prop, val in (("Reference", ref), ("Value", name.split(":")[-1])):
        L.append('    (property "%s" "%s" (at 0 0 0) (layer "B.Fab") (hide yes) %s %s)' % (prop, val, U(), FONT % (0.8, 0.8, " (justify mirror)")))
    L.append("    (attr smd)")
    a = math.radians(ang)
    for (num, lx, ly, sx, sy, rr), n in zip(pads, nets):
        bx, by = -lx, -ly                                   # bibliotheque -> vue de face (miroir + y vers le haut)
        fx = bx * math.cos(a) - by * math.sin(a); fy = bx * math.sin(a) + by * math.cos(a)
        PADLOG.append((ref, num, ox + fx, oy + fy, n))
        L.append('    (pad "%s" smd roundrect (at %s %s %s) (size %s %s) (layers "B.Cu" "B.Mask" "B.Paste") (roundrect_rratio %s) %s %s)' % (
            num, f(fx), f(-fy), f(ang % 180), sx, sy, rr, netref(n), U()))
    L.append("  )")
    out.extend(L)
    CPL.append((ref, ox, oy, ang))


PADLOG, CPL = [], []


def rot(x, y, deg):
    a = math.radians(deg)
    return (x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a))


R_ANCHOR = 27.6
SIDE_ANG = {1: 0, 2: 60, 3: 120, 4: 180, 5: 240, 6: 300}
if MASTER:
    del SIDE_ANG[5]
DATAPIN = {}
for k, phi in SIDE_ANG.items():
    ax, ay = P(R_ANCHOR, phi)
    th = phi + 90
    back_fp("Connector_JST:JST_PH_S3B-PH-SM4-TB_1x03-1MP_P2.00mm_Horizontal", "J%d" % k, ax, ay, th,
            JST_PADS, ["+5V", "SIDE%d" % k, "GND", "GND", "GND"])
    DATAPIN[k] = P(24.75, phi)
    p1 = (P(24.75, phi, 2.0), P(28.0, phi, 2.0))        # broche 1 (+5V) -> via vers la face avant
    track([p1[0], p1[1]], "+5V", 0.5, "B.Cu"); via(*p1[1], n="+5V")
    c = [P(24.4, phi, -4.95), P(32, phi, -4.95), P(32, phi, 4.95), P(24.4, phi, 4.95)]
    for i in range(4):
        gr_line(*c[i], *c[(i + 1) % 4], "B.SilkS")
    gr_text(str(k), *P(21.2, phi), 1.2, back=True)

# ---------------------------------------------------------------- contour, trous
# ---------------------------------------------------------------- contour
# Forme de la plaque (hexagone pointe en haut, 1 mm en retrait des parois),
# avec une encoche en U autour des 3 colonnes aimantees de la coque
# (centre a 37 mm, rayon 4,4 mm + 1,2 mm de jeu), ouverte vers le coin.
if MASTER:
    ANG = math.radians(240); UX, UY = math.cos(ANG), math.sin(ANG); LX, LY = -UY, UX
    def mp(r, s): return (r * UX + s * LX, r * UY + s * LY)
APO = 37.0
RV = APO / math.cos(math.radians(30))
COLS = {30, 150, 270}
RN = 5.6


def inter(p1, d1, p2, p3):
    # intersection de la droite p1 + s*d1 avec le segment p2-p3
    x1, y1 = p1; dx, dy = d1; x2, y2 = p2; ex, ey = p3[0] - x2, p3[1] - y2
    den = dx * ey - dy * ex
    s_ = ((x2 - x1) * ey - (y2 - y1) * ex) / den
    return (x1 + s_ * dx, y1 + s_ * dy)


OUTLINE = []
angs = [30, 90, 150, 210, 270, 330]
for i, a in enumerate(angs):
    V = P(RV, a)
    prv, nxt = P(RV, angs[i - 1]), P(RV, angs[(i + 1) % 6])
    if a in COLS:
        u = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        t = (-u[1], u[0])
        c = P(37.0, a)
        a1 = (c[0] - RN * t[0], c[1] - RN * t[1])
        a2 = (c[0] + RN * t[0], c[1] + RN * t[1])
        OUTLINE.append(inter(a1, u, prv, V))
        for k in range(0, 13):                      # demi-cercle cote centre, de -t a +t
            ang = math.radians(a - 90 - 15 * k)
            OUTLINE.append((c[0] + RN * math.cos(ang), c[1] + RN * math.sin(ang)))
        OUTLINE.append(inter(a2, u, V, nxt))
    else:                                          # coin simplement chanfreine (3 mm)
        for q in (prv, nxt):
            d = math.hypot(q[0] - V[0], q[1] - V[1])
            OUTLINE.append((V[0] + (q[0] - V[0]) * 3 / d, V[1] + (q[1] - V[1]) * 3 / d)) if q is prv else None
        d = math.hypot(nxt[0] - V[0], nxt[1] - V[1])
        OUTLINE.append((V[0] + (nxt[0] - V[0]) * 3 / d, V[1] + (nxt[1] - V[1]) * 3 / d))

for i in range(len(OUTLINE)):
    gr_line(*OUTLINE[i], *OUTLINE[(i + 1) % len(OUTLINE)], "Edge.Cuts", 0.1)
HOLES = [(0, 23), (20, -12), mp(31, 0), (-20, -10)] if MASTER else [(0, 23), (-20, -12), (20, -12), (0, -27)]
for i, (x, y) in enumerate(HOLES, 1):
    footprint("MountingHole_M2.5", "H%d" % i, "M2.5", x, y, [("", x, y, "circle", 2.7, 2.7, 2.7, None)], hole=True)


def two(name, ref, val, x1, y1, x2, y2, n1, n2):
    footprint(name, ref, val, (x1 + x2) / 2, (y1 + y2) / 2,
              [("1", x1, y1, "rect", 1.6, 1.6, 0.8, n1), ("2", x2, y2, "circle", 1.6, 1.6, 0.8, n2)])


if MASTER:
    # C1 au-dessus du ruban (laisse la place a D1) + entree d'alimentation 5 V dediee
    two("C_P5.00", "C1", "10uF", 15, 10.5, 20, 10.5, "+5V", "GND")
    gr_rect(14.4, 9.2, 20.6, 11.8); gr_text("C1 10uF 16V", 17.5, 13.0, 0.8); gr_text("+", 13.3, 10.5, 1.0)
    footprint("Alim_5V_P5.08", "J7", "ALIM 5V", 0, 30.5,
              [("1", -2.54, 30.5, "rect", 2.8, 2.8, 1.4, "+5V"), ("2", 2.54, 30.5, "circle", 2.8, 2.8, 1.4, "GND")])
    gr_text("+5V", -6.6, 30.5, 0.9); gr_text("GND", 6.8, 30.5, 0.9)
    gr_text("+5V", -6.6, 30.5, 0.9, back=True); gr_text("GND", 6.8, 30.5, 0.9, back=True)
    gr_text("ALIM", 0, 33.6, 0.9, back=True)
else:
    two("C_P5.00", "C1", "10uF", 16, -8, 21, -8, "+5V", "GND")
    gr_rect(15.4, -9.3, 21.6, -6.7); gr_text("C1 10uF 16V", 18.5, -5.6, 0.8); gr_text("+", 14.3, -8.0, 1.0)
B = "B.Cu"
# Interrupteur DIP 6 positions CMS au pas de 2,54 mm (format courant, soudable au fer)
DIP_NAME = "Button_Switch_SMD:SW_DIP_SPSTx06_Slide_6.7x16.8mm_W8.61mm_P2.54mm_LowProfile"
DIP_PADS = [(str(k), -4.305, -6.35 + 2.54 * (k - 1), 2.44, 1.12, 0.223214) for k in range(1, 7)] + \
           [(str(13 - k), 4.305, -6.35 + 2.54 * (k - 1), 2.44, 1.12, 0.223214) for k in range(1, 7)]
CX = 6.5                       # centre des interrupteurs : x = -CX (IN) et +CX (OUT)
CI, CO = CX - 4.305, CX + 4.305   # colonne interieure (cotes) / exterieure
BX = CX - 0.7                     # ligne de bus sur les pastilles 'bus' des cavaliers
ROWS = {1: 6.35, 2: 3.81, 3: 1.27, 4: -1.27, 5: -3.81, 6: -6.35}   # cote -> rangee
if MASTER:
    ROWS = {1: 6.35, 2: 3.81, 3: 1.27, 4: -3.81, 6: -6.35}


def dip(ref, cx, left_net_of_y, right_net_of_y):
    """Cavaliers a souder (remplacent l'interrupteur DIP) : une paire de pastilles par rangee,
    separees de 0,5 mm ; une goutte d'etain = position ON."""
    sgn = 1 if cx > 0 else -1                     # cote de la colonne interieure (cotes) : vers le centre
    xs, xb = cx - sgn * 3.5, cx - sgn * 0.7
    pads = []
    for k, y in sorted(ROWS.items()):
        bus = right_net_of_y(y) if sgn > 0 else left_net_of_y(y)
        sid = left_net_of_y(y) if sgn > 0 else right_net_of_y(y)
        pads.append(("%dS" % k, xs, y, 2.4, 1.2, sid))
        pads.append(("%dB" % k, xb, y, 2.2, 1.2, bus))
    smd_b("SolderJumper_x%d_P2.54" % len(ROWS), ref, cx, 0, pads)
    gr_rect(cx - 3.35, -8.4, cx + 3.35, 8.4, "B.SilkS")


SIDE_OF_Y = {round(v, 3): "SIDE%d" % k for k, v in ROWS.items()}
side_net = lambda y: SIDE_OF_Y.get(round(y, 3))


def side(k, pts, front=False):
    n = "SIDE%d" % k
    if not front:
        track([DATAPIN[k]] + pts, n, 0.3, B); return
    track([DATAPIN[k]] + pts[:-2], n, 0.3, B); via(*pts[-3], n=n)
    track(pts[-3:], n, 0.3, "F.Cu"); via(*pts[-1], n=n)


if not MASTER:
    strip("RB1", -10, 10, 16, "S1_DIN", "S2_DIN", False)
    strip("RB2", -25, 25, 0, "S2_DIN", "S3_DIN", True)
    strip("RB3", -10, 10, -16, "S3_DIN", "DO", False)
    dip("SW_IN", -CX, lambda y: "DI", side_net)
    dip("SW_OUT", CX, side_net, lambda y: "DO")
    for k, y in ROWS.items():                     # liaison IN <-> OUT de chaque cote
        track([(-CI, y), (CI, y)], "SIDE%d" % k, 0.3, B)
    two("R_Axial_P7.62", "R1", "330", -14.5, 7.5, -14.5, 15.12, "DI", "S1_DIN")
    two("R_Axial_P7.62", "R2", "10k", -18, 7.5, -18, 15.12, "DI", "GND")
    gr_rect(-15.8, 8.2, -13.2, 14.4); gr_rect(-19.3, 8.2, -16.7, 14.4)
    gr_text("R1", -14.5, 17.0, 0.8); gr_text("R2", -18.5, 17.0, 0.8)
    gr_text("330", -14.5, 18.2, 0.7); gr_text("10k", -18.5, 18.2, 0.7)
    # bus DI (colonne exterieure de SW_IN) -> R1 / R2 (pastilles traversantes, pas de via)
    track([(-BX, -6.35), (-BX, 7.5), (-14.5, 7.5), (-18, 7.5)], "DI", 0.3, B)
    track([(-14.5, 15.12), (-14.5, 16), (-11.5, 16)], "S1_DIN")
    track([(11.5, 16), (14, 16), (21, 0), (24, 0)], "S2_DIN")
    track([(-24, 0), (-21, 0), (-14, -16), (-11.5, -16)], "S3_DIN")
    # bus DO (colonne exterieure de SW_OUT) -> via -> fin du ruban du bas
    track([(BX, -6.35), (BX, 6.35)], "DO", 0.3, B)
    track([(BX, -2.54), (14.5, -2.54)], "DO", 0.3, B); via(14.5, -2.54, "DO")
    track([(14.5, -2.54), (14.5, -16), (11.5, -16)], "DO")
    # cotes -> colonne interieure de SW_IN, par le couloir sous son boitier
    side(1, [(23, 0), (21, 2), (21, 8.2), (-4.2, 8.2), (-4.2, 6.35), (-CI, 6.35)], front=True)
    side(2, [(11.25, 19.48), (7, 13), (7, 9.0), (-5.0, 9.0), (-5.0, 3.81), (-CI, 3.81)], front=True)
    side(3, [(-11.25, 19.48), (-8, 14), (-8, 10.6), (-5.8, 10.6), (-5.8, 1.27), (-CI, 1.27)], front=True)
    side(4, [(-22.5, 0), (-19, -5), (-19, -9.0), (-5.8, -9.0), (-5.8, -1.27), (-CI, -1.27)], front=True)
    side(5, [(-11.25, -19.48), (-5.0, -13), (-5.0, -3.81), (-CI, -3.81)], front=True)
    side(6, [(11.25, -19.48), (8, -14), (8, -8.2), (-4.2, -8.2), (-4.2, -6.35), (-CI, -6.35)], front=True)
    for k, y in ROWS.items():
        gr_text(str(k), 0, y + 1.0, 0.8, back=True)
    gr_text("IN", -CX, 9.6, 1.0, back=True); gr_text("OUT", CX, 9.6, 1.0, back=True)
    gr_text("1 goutte d'etain par bloc", 0, -11.2, 0.8, back=True)
else:
    ROW, FIRST, R_PORT = 15.24, 3.47, 36.0
    LEFT = ["5V", "GND", "3V3", "4", "3", "2", "1", "0"]; RIGHT = ["5", "6", "7", "8", "9", "10", "20", "21"]
    NETMAP = {"5V": "+5V", "GND": "GND", "4": "GPIO4"}
    pads = []
    for i in range(8):
        r = R_PORT - FIRST - i * 2.54
        for sd, names in ((ROW / 2, LEFT), (-ROW / 2, RIGHT)):
            x, y = mp(r, sd)
            pads.append((("L" if sd > 0 else "R") + str(i + 1), x, y, "rect" if names[i] == "5V" else "circle", 1.6, 1.6, 1.0, NETMAP.get(names[i])))
    footprint("ESP32-C3_SuperMini", "U1", "ESP32-C3 SuperMini", *mp(R_PORT - 11.26, 0), pads)
    cs = [mp(R_PORT, 9), mp(R_PORT, -9), mp(R_PORT - 22.52, -9), mp(R_PORT - 22.52, 9)]
    for i in range(4):
        gr_line(*cs[i], *cs[(i + 1) % 4], "F.SilkS")
    gr_text("USB", *mp(R_PORT - 2.0, 0), 1.0)
    # D1 : les 3 LED de la master sont alimentees ~0,7 V plus bas (environ 4,4 V) : elles
    # reconnaissent alors sans faute le signal 3,3 V de l'ESP32 et le regenerent en 5 V.
    st = strip("RB1", -15, 15, 0, "S1_DIN", "DO", False, vnet="VLED")
    footprint("D_DO-41_P7.62", "D1", "1N4148/1N4007", 17.19, -8.2,
              [("1", 13.38, -8.2, "rect", 2.0, 2.0, 1.1, "VLED"), ("2", 21.0, -8.2, "circle", 2.0, 2.0, 1.1, "+5V")])
    gr_rect(14.6, -9.2, 19.8, -7.2); gr_line(15.4, -9.2, 15.4, -7.2, "F.SilkS")
    gr_text("D1 1N4148", 17.2, -6.2, 0.7)
    track([(13.38, -8.2), (13.38, -5.6), (14.2, st["5V"])], "VLED", 0.5)
    track([(-14.2, st["5V"]), (14.2, st["5V"])], "VLED", 0.5)   # double le 5V interne du ruban
    two("R_Axial_P7.62", "R1", "330", 3, -16.62, 3, -9.0, "GPIO4", "S1_DIN")
    gr_rect(1.7, -15.9, 4.3, -9.7); gr_text("R1", 0.6, -12.2, 0.8); gr_text("330", 0.4, -13.4, 0.7)
    g4 = mp(R_PORT - FIRST - 3 * 2.54, ROW / 2)
    track([g4, mp(R_PORT - FIRST - 3 * 2.54, ROW / 2 + 1.6), mp(14, ROW / 2 + 1.6), (3, -16.62)], "GPIO4")
    track([(3, -9.0), (3, -7.5), (-19, -7.5), (-19, 0), (-16, 0)], "S1_DIN")
    dip("SW_OUT", CX, side_net, lambda y: "DO")
    track([(BX, -6.35), (BX, 6.35)], "DO", 0.3, B)
    track([(16, 0), (18, 0), (18, -2.54)], "DO"); via(18, -2.54, "DO")
    track([(18, -2.54), (BX, -2.54)], "DO", 0.3, B)
    side(1, [(23, 0), (21, 2), (21, 8.2), (-0.6, 8.2), (-0.6, 6.35), (CI, 6.35)])
    side(2, [(11.25, 19.48), (7, 13), (7, 9.0), (-1.4, 9.0), (-1.4, 3.81), (CI, 3.81)])
    side(3, [(-11.25, 19.48), (-8, 14), (-8, 10.6), (-2.2, 10.6), (-2.2, 1.27), (CI, 1.27)])
    side(4, [(-22.5, 0), (-19, -4.5), (-1.4, -4.5), (-1.4, -3.81), (CI, -3.81)])
    side(6, [(11.25, -19.48), (8, -14), (8, -7.6), (-0.6, -7.6), (-0.6, -6.35), (CI, -6.35)])
    for k, y in ROWS.items():
        gr_text(str(k), -3.4, y + 1.0, 0.8, back=True)
    gr_text("OUT", CX, 9.6, 1.0, back=True)
    gr_text("1 goutte", CX, -9.6, 0.8, back=True)
gr_text("BuildBeacon %s v%s" % ("master" if MASTER else "tuile", VERSION), 0, 16 if MASTER else -20, 0.8, back=True)
for layer, n in (("F.Cu", "+5V"), ("B.Cu", "GND")):
    pts = " ".join("(xy %s %s)" % (f(X(x)), f(Y(y))) for x, y in OUTLINE)
    out.append('  (zone (net %d) (net_name "%s") (layer "%s") %s (hatch edge 0.5)\n'
               '    (connect_pads (clearance 0.3))\n'
               '    (min_thickness 0.25) (filled_areas_thickness no)\n'
               '    (fill (thermal_gap 0.5) (thermal_bridge_width 0.5))\n'
               '    (polygon (pts %s))\n  )' % (NID[n], n, layer, U(), pts))
print("data pins", {k: (round(v[0], 2), round(v[1], 2)) for k, v in DATAPIN.items()})
# ---------------------------------------------------------------- en-tete
LAYERS = [(0, "F.Cu", "signal", None), (31, "B.Cu", "signal", None),
          (32, "B.Adhes", "user", "B.Adhesive"), (33, "F.Adhes", "user", "F.Adhesive"),
          (34, "B.Paste", "user", None), (35, "F.Paste", "user", None),
          (36, "B.SilkS", "user", "B.Silkscreen"), (37, "F.SilkS", "user", "F.Silkscreen"),
          (38, "B.Mask", "user", None), (39, "F.Mask", "user", None),
          (40, "Dwgs.User", "user", "User.Drawings"), (41, "Cmts.User", "user", "User.Comments"),
          (42, "Eco1.User", "user", "User.Eco1"), (43, "Eco2.User", "user", "User.Eco2"),
          (44, "Edge.Cuts", "user", None), (45, "Margin", "user", None),
          (46, "B.CrtYd", "user", "B.Courtyard"), (47, "F.CrtYd", "user", "F.Courtyard"),
          (48, "B.Fab", "user", None), (49, "F.Fab", "user", None)]
head = ['(kicad_pcb (version 20240108) (generator "buildbeacon") (generator_version "8.0")',
        "  (general (thickness 1.6) (legacy_teardrops no))",
        '  (paper "A4")',
        '  (title_block (title "BuildBeacon %s") (date "%s") (rev "v%s") (comment 1 "CERN-OHL-P-2.0"))' % ("master" if MASTER else "tuile", __import__("datetime").date.today().isoformat(), VERSION),
        "  (layers"]
for num, name, kind, alias in LAYERS:
    head.append('    (%d "%s" %s%s)' % (num, name, kind, ' "%s"' % alias if alias else ""))
head.append("  )")
head.append("  (setup (pad_to_mask_clearance 0))")
for i, n in enumerate(NETS):
    head.append('  (net %d "%s")' % (i, n))

text = "\n".join(head + out) + "\n)\n"
open(OUTFILE, "w").write(text)
print("ok", text.count("(") - text.count(")"))

