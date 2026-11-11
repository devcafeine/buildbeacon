// =====================================================================
//  BuildBeacon - tuile hexagonale lumineuse (paramétrique)
//  Version 1.0 (2026-11-11) - première version publique
//  Cartes : buildbeacon_tuile_v1.0 / buildbeacon_master_v1.0
//  Source : https://github.com/devcafeine/buildbeacon (hardware/cad)
//  Licence matériel : CERN-OHL-P-2.0
//
//  Impression :
//   - Tuile : façade contre le plateau, sans support, PLA/PETG blanc
//     ou "natural". Le texte est aminci par l'intérieur : il ressort
//     plus lumineux que le reste de la façade (une seule couleur).
//   - Plaque arrière : imprimée nervures vers le haut.
//   - Socle : à plat, tel quel.
//
//  Orientation "pointy" (par défaut) : pointe en haut et en bas,
//  côtés plats à gauche et à droite -> les tuiles s'alignent en rangée
//  sur le socle de bureau et forment aussi un nid d'abeille au mur.
//
//  Aimants 6x3 mm : polarité alternée d'un côté à l'autre
//  (côtés 0,2,4 = Nord vers l'extérieur ; 1,3,5 = Sud).
//  Ainsi n'importe quelle tuile s'accroche à n'importe quelle autre.
// =====================================================================

/* [Style] */
// glow = une couleur, texte aminci qui brille plus fort
// swap = une couleur + 1 changement de filament : façade noire, lettres blanches
// dark_face = multicolore : façade sombre, seules les lettres s'allument
// stencil = une couleur, lettres traversantes + papier calque collé derrière.
//           Utiliser une police pochoir (ex. "Stardos Stencil:style=Bold")
//           sinon l'intérieur des lettres (o, D, a...) tombe.
style = "glow"; // [glow, swap, dark_face, stencil]
// (swap) Épaisseur noire à l'avant : changer de filament à cette hauteur
swap_z = 0.8;

/* [Texte] */
// Nom du projet affiché
label = "BuildBeacon";
// Seconde ligne optionnelle (laisser vide pour aucune)
label2 = "";
font = "Liberation Sans:style=Bold";
// Taille du texte principal (0 = automatique selon la tuile ; réduire si le nom est long)
text_size = 0;
text_size2 = 7;
// Épaisseur restante devant le texte (mm) : plus fin = plus lumineux
text_skin = 0.6;

/* [Décor] */
// Tuile maître = tuile « tête » : un logo à la place du nom
master_logo = true;
// Fichier SVG du logo (vide = logo intégré « balise »). Ex. "logo.svg"
logo_svg = "";
// Largeur du logo (mm)
logo_size = 34;
// Décalage vertical du logo (mm, + = vers le haut)
logo_y = 3;
// Liseré lumineux qui suit le contour de la tuile
border = true;
// Distance du liseré au bord extérieur (au-delà des bossages d'aimant)
border_inset = 7.5;
border_w = 1.2;
// Barre de points sous le nom : 1 point par LED, allumables séparément.
// Les 5 LED des points sont enfermées ; 2 LED au-dessus et 2 en dessous
// éclairent le nom et le liseré. Pas de points sur la tuile maître (pas
// la place sous l'ESP32), ni avec les T-Clips (logements sur l'axe).
dots = true;
// LED d'ambiance au-dessus / en dessous des points
amb_leds = 2;
// Distance (verticale) des LED d'ambiance au centre de la tuile
amb_offset = 16;
// Tuile logo : 2 LED d'ambiance en haut en plus du ruban central
// (utile seulement si le haut du logo/liseré paraît trop sombre)
master_amb = false;
// Nombre de points (= nombre de LED derrière)
dots_n = 5;
// Écart entre points = pas des LED du ruban (100 LED/m -> 10 mm)
dots_pitch = 10;
dots_d = 4;
// Passage des fils entre les morceaux de ruban PAR L'ARRIÈRE de la plaque :
// un trou au bout de chaque morceau, des rainures au dos qui les relient
// (désactivé par défaut : avec du fil épais, utiliser les clips à câbles)
wire_paths = false;
// Réglé pour 3 fils silicone 28 AWG (Ø ~1,1 mm) côte à côte
groove_w = 3.6;
groove_d = 1.2;
wire_hole_size = 3.6;
// Boîtes fermées autour des points, jusqu'au ruban : chaque LED
// n'éclaire que son point
dot_ribs = true;
// Jeu entre le haut des parois et le ruban (mm)
rib_gap = 0.4;
rib_t = 0.8;

/* [Tuile] */
// pointy = pointe en haut (rangées sur bureau) ; flat = côté plat en haut
orientation = "pointy"; // [pointy, flat]
// Largeur entre deux côtés plats (mm) — 65 minimum
flat = 80;
// Profondeur totale (mm)
depth = 22;
wall = 2;
// Épaisseur de la façade (mm)
face = 1.6;
corner_r = 3;

/* [Liaison des plaques] */
// Les plaques arrière se relient entre elles par des pièces en « os de
// chien » (part = links), posées à cheval au milieu des côtés communs,
// à travers l'encoche ouverte. L'ensemble forme un panneau rigide :
// quelques tuiles clipsées ou vissées suffisent à tout porter.
plate_links = true;
// Nombre d'os de chien à imprimer (part = links)
link_count = 6;
// Serrage des os de chien (mm par côté) : grossit l'os sans toucher aux
// logements des plaques. 0 = d'origine ; plus grand = moins de jeu.
// Pour trouver la bonne valeur : part = link_test (4 os de 0,05 à 0,20).
link_fit = 0.10; // [0:0.025:0.3]

/* [Aimants latéraux (option)] */
// Aimants sur les côtés des coques. Inutiles avec la liaison des plaques.
magnets = false;
// Aimants par côté : 2 = pas de pivot ni de glissement entre tuiles.
// Polarité (2 aimants) : en tournant autour de la tuile vue de face dans
// le sens des aiguilles d'une montre, sur CHAQUE côté le 1er aimant
// rencontré a le Nord vers l'extérieur, le 2e le Sud. Toutes les tuiles
// s'accrochent alors entre elles par n'importe quel côté.
side_magnets = 2; // [1, 2]
// Écart des aimants par rapport au milieu du côté (mm)
mag_spread = 10;
// Côté d'ouverture des logements d'aimant de la plaque arrière :
// top = sur le dessus (côté coque, plus facile à imprimer, aimant collé)
// back = par l'arrière (côté plateau d'impression)
plate_mag_side = "top"; // [top, back]
// Diamètre du logement (aimant 6 mm + jeu ; les trous imprimés sortent
// plus petits : 6,4 à 6,5 en général)
mag_d = 6.4;
// Profondeur du logement (aimant 3 mm + jeu)
mag_h = 3.2;
// Hauteur du centre des aimants depuis la façade (0 = automatique)
mag_z = 0;

/* [Passage de câbles] */
notches = true;
// Côtés avec encoche, VUS DE FACE (orientation pointy) :
// 0 = gauche, 1 = haut-gauche, 2 = haut-droite,
// 3 = droite, 4 = bas-droite, 5 = bas-gauche
notch_sides = [0, 1, 2, 3, 4, 5];
notch_w = 10;
notch_h = 4;
// Encoches défonçables : fermées par une fine peau à casser si besoin
notch_knockout = true;
knockout_skin = 0.6;
// Nombre de bouchons à imprimer (part = plugs). Avec les encoches
// défonçables, inutiles ; à coller si on referme une encoche ouverte.
plug_count = 4;

/* [Plaque arrière] */
back_t = 2;
// tray  = la plaque arrière est un BAC à rebords, la coque se pose dessus
//         (les fils courent dans le bac, le long des rebords)
// inset = ancienne version : plaque plate emboîtée dans une coque pleine
//         hauteur (compatible avec les coques déjà imprimées avant le bac)
// double = DOUBLE FOND pour coques pleine hauteur : un plateau LED (comme
//         inset) posé sur 3 piliers d'un socle ; les câbles passent entre
//         les deux. Imprimer part = back (plateau) et part = base (socle).
plate_style = "inset"; // [inset, tray, double]
// (double) Hauteur du double fond pour les câbles
dbl_space = 8;
// (double) Fixation du plateau sur les piliers du socle (les aimants de la
// coque tirent sur le plateau : il doit être vissé) :
// insert = insert laiton M3 dans le pilier + vis M3 x 6 ; self_tap = vis
// autotaraudeuse M2,5 x 8 ; peg = simples pions (déconseillé)
dbl_fix = "insert"; // [insert, self_tap, peg]
// (double) Diamètre des trous du plateau pour descendre les fils des LED
// dans le double fond (3 fils silicone 22 AWG : 4,2 mm)
dbl_wire_hole = 4.2;
// Hauteur des rebords du bac (style tray)
base_wall_h = 6;
// Bourrelet sur le haut des rebords, qui centre la coque
base_lip_h = 1.5;
base_lip_w = 1.2;
// Jeu d'emboîtement (plaque arrière et socle)
tol = 0.25;
// Rebord d'appui de la plaque. Inutile avec les colonnes (aimants ou vis)
// qui arrêtent déjà la plaque ; il crée un porte-à-faux à l'impression.
ledge = false;
ledge_w = 1.5;
ledge_h = 1.5;
// Support des LED des tuiles projet :
// strip = morceaux de ruban collés sur la plaque, entre des rails
// pcb   = circuit imprimé (morceaux de ruban soudés dessus), vissé sur des
//         entretoises : "tuile_ruban" (tuiles projet) ou "tuile_logo"
//         (tuile maître, ESP32-C3 SuperMini sur le circuit ; pointy seulement)
led_mount = "strip"; // [strip, pcb]
// (pcb) Hauteur des entretoises : place pour les connecteurs JST soudés
// au dos du circuit (4,8 mm de haut) et les vis des clips Skådis
pcb_standoff = 7;
// (pcb) Épaisseur du circuit imprimé
pcb_t = 1.6;
// (pcb) Avant-trou pour vis autotaraudeuse M2,5 x 6 (PLA : 2,2 mm)
pcb_pilot = 2.2;
// Fixation de la carte : vis autotaraudeuse M2,5 ou insert laiton M2,5 + vis M2,5 x 6
pcb_fix = "insert"; // [self_tap, insert]
// (insert) Diamètre du logement : diamètre extérieur de l'insert - 0,3 mm (insert M2,5 x 4 x 3,5)
pcb_insert_d = 3.2;
// (insert) Longueur de l'insert
pcb_insert_len = 4;
// (pcb, tuile logo) Hauteur de l'entretoise plastique des barrettes sous
// l'ESP32-C3 SuperMini (2,5 mm en standard). Sert à placer l'ouverture USB.
esp_spacer = 2.5;
// (pcb, tuile logo) Épaisseur du circuit de l'ESP32-C3 SuperMini
esp_board_t = 1.0;
// (pcb) Fenêtres dans la plaque arrière en face des interrupteurs DIP
pcb_dip_window = false;
// Largeur du ruban LED (WS2812B : 10 mm en général)
strip_w = 10;
rail_len = 56;
// Passage de câble par l'arrière (ex. alimentation qui sort du mur)
wire_hole = false;
wire_hole_d = 8;
// Trou de serrure pour fixation murale
keyhole = true;
// Fixation de la plaque arrière sur la coque (3 points, 4 pour la maître)
screws = true;
// magnet = aimants 6x3 (coque interchangeable sans outil)
// insert = vis M3 + insert laiton ; self_tap = vis autotaraudeuse M2,5
screw_type = "magnet"; // [magnet, insert, self_tap]
// (insert) Diamètre du trou : ~ diamètre extérieur de l'insert - 0,5 mm
insert_d = 3.6;     // kit Corgi M3 x 5 x 4 : 4 - 0,4
// (insert) Longueur de l'insert
insert_len = 5;
// (insert) Passage de la vis dans la plaque (M3 : 3,4)
insert_screw_clear = 3.4;
// Diamètre d'avant-trou dans la colonne (M2,5 dans du PLA : 2,2)
screw_pilot = 2.2;
// Diamètre de passage dans la plaque
screw_clear = 2.9;
screw_boss_d = 6;

/* [Tuile maître (ESP32)] */
// Carte : c3 = ESP32-C3 Super Mini (dans le coin, en diagonale)
//         d1mini = Wemos D1 mini : à plat au centre, USB à gauche,
//         ruban LED sur un pont au-dessus (part = led_bridge)
esp_board = "c3"; // [c3, d1mini]
// Nombre de LED du ruban central de la tuile logo
master_leds = 3; // [3, 4, 5]
// Tuile qui contient l'ESP32-C3 Super Mini et reçoit l'USB-C
master = false;
// Dimensions de la carte (ESP32-C3 Super Mini : 18 x 22,5 mm)
esp_w = 18.2;
esp_l = 22.7;
// Découpe pour la fiche USB-C (largeur x hauteur)
usb_w = 13;
usb_h = 8.5;

/* [Socle de bureau (orientation pointy)] */
// Nombre de tuiles côte à côte sur le socle
stand_tiles = 2;
// Inclinaison vers l'arrière (degrés)
tilt = 12;
// Matière sous la pointe des tuiles
stand_floor = 6;
// Hauteur des joues au-dessus de la pointe
lip_h = 10;
lip = 3;
// Passage du câble USB pour la tuile maître, placée tout à gauche
stand_usb = true;
// Débord avant et arrière de la semelle (stabilité)
stand_front = 6;
stand_back = 15;

/* [Adaptateur IKEA Skådis] */
// Fixation Skådis de la plaque arrière (tuile >= 80 mm) :
// clips = 2 fentes + nos clips glissés par l'intérieur
// tclip = logements pour le "Skadis T-Clip System" de LineArcLine
//         (2 l'un au-dessus de l'autre ; 1 seul sur la tuile maître ;
//          pas de trou de serrure). Clips à télécharger sur Printables.
skadis_mount = "clips"; // [clips, tclip, none]
skadis_slots = (skadis_mount == "clips");
// Type de clip Skådis (part = skadis_clips) :
// snap = clip simple à pinces : on l'enfonce, clic, c'est tenu
// twist = clip quart de tour
skadis_clip_type = "snap"; // [snap, twist]
// Largeur des clips Skådis (fente : 5 mm ; 4,2 à 4,4 conseillé)
skadis_hook_w = 4.4;
// (snap) Épaisseur des bras souples : plus fin = plus facile à enclipser
snap_arm_t = 1.2;
// (snap) Débord des crochets derrière le panneau
snap_barb = 0.7;
// Épaisseur RÉELLE du panneau Skådis (à mesurer au pied à coulisse)
skadis_board = 5.0;

/* [Clips à câbles] */
// Petits clips à coller sur la plaque pour tenir les fils (part = cable_clips)
cable_clip_count = 8;
// Ouverture du clip (2 fils silicone 22 AWG : 4 mm)
cable_clip_gap = 4;
cable_clip_h = 3.5;

/* [Export] */
// letters = lettres seules, pour le style dark_face (même origine que tile)
// skadis_clips = 2 clips qui traversent plaque + panneau (recommandé)
// skadis = ancien adaptateur à vis (accroche par le trou de serrure)
// knockout_test = éprouvette pour choisir l'épaisseur des opercules
part = "both"; // [tile, letters, back, both, stand, plugs, skadis_clips, skadis, links, link_test, led_bridge, base, cable_clips, knockout_test]

/* [Hidden] */
bb_version = "1.0";
echo(str("BuildBeacon modèle v", bb_version));
$fn = 48;
eps = 0.01;
pointy = (orientation == "pointy");
hex_rot = pointy ? 30 : 0;      // rotation du contour
side_off = pointy ? 0 : 30;     // angle du milieu du côté 0
apothem = flat / 2;
R_hex = flat / sqrt(3);
inner_flat = flat - 2 * wall;
r_in = max(corner_r - wall, 0.5);
boss_d = mag_d + 3;
boss_len = mag_h + 1.2;
mag_offsets = side_magnets == 2 ? [-mag_spread, mag_spread] : [0];
// Côté de sortie USB : en pointy, le côté en biais en bas à GAUCHE vu de
// face (côté 5 du modèle, qui est en miroir) : le ruban reste centré et
// le câble sort vers l'extérieur de la rangée. En flat : en bas.
d1 = master && pointy && esp_board == "d1mini";
eW = d1 ? 25.8 : esp_w;
eL = d1 ? 34.5 : esp_l;
USB_SIDE = pointy ? (d1 ? 0 : 5) : 4;
usb_angle = side_off + 60 * USB_SIDE;
// La plaque est retournée à la pose (Y inversé) : l'angle s'inverse
cradle_angle = -usb_angle;
// Coins (sommets) utilisés pour les colonnes de vis : 1 sur 2
vertex_off = pointy ? 30 : 0;
use_insert = (screw_type == "insert");
use_magnet = (screw_type == "magnet");
// Colonne assez grosse pour garder ~1,2 à 1,7 mm de matière autour
column_d = use_magnet ? max(screw_boss_d, mag_d + 2.4)
         : use_insert ? max(screw_boss_d, insert_d + 3.5)
         : screw_boss_d;
// En retrait du rebord de la plaque (sinon le bossage touche le rebord)
screw_r = (inner_flat - 2 * ledge_w) / sqrt(3) - column_d / 2 - 0.8;
// Mode aimant : la colonne s'arrête plus bas, la plaque porte un
// bossage avec son propre aimant qui vient au contact.
// Hauteur des plots d'aimant côté intérieur de la plaque (aimant posé par
// l'arrière + peau de 0,4 mm)
plate_boss_h = max(0.6, mag_h + 0.4 - back_t);
col_top = use_magnet ? depth - back_t - plate_boss_h : depth - back_t;
// Coins des colonnes de vis/aimants : un coin sur deux, en triangle
// équilibré, identique pour toutes les tuiles (maître comprise).
// Vérifié en 80 mm avec ESP32-C3 et D1 mini : le plot voisin de l'USB
// passe à côté du berceau. En dessous de 80 mm, vérifier à l'aperçu.
screw_angles = [for (k = [0 : 2]) vertex_off + 120 * k];
// Aimants : à mi-hauteur entre façade et encoches, sauf réglage manuel
// Hauteur de la coque (façade + parois) : elle se pose sur les rebords du bac
tray = (plate_style == "tray");
dbl = (plate_style == "double");
hc = tray ? depth - back_t - base_wall_h : depth;
mag_zz = mag_z > 0 ? mag_z : (tray ? hc : depth - back_t - notch_h) - boss_d / 2 - 0.5;
// Rayon intérieur de la plaque arrière (sommet)
plate_R = (inner_flat - 2 * tol) / sqrt(3);
// Positions proportionnelles à la taille de la tuile
// (positions vérifiées pour flat de 65 à 100 mm, tuile normale et maître)
// Fentes Skådis dans la plaque : 40 mm d'écart (pas du Skådis), placées
// dans la moitié haute de la tuile, à l'écart du berceau ESP32.
// En flat avec les LED d'ambiance, le trou de serrure n'a plus de place :
// les 2 fentes servent alors aussi à visser la plaque au mur.
slot_on = skadis_slots || (!pointy && dots && skadis_mount != "tclip");
slot_x = 20;
slot_h = 15.2;          // laisse passer le pied du clip quart de tour (14,8 mm)
slot_w = skadis_hook_w + 0.8;
// au-dessus des rails du ruban central, en laissant la place à la tête
// du clip (3 mm sous la fente) ; à l'écart des liaisons de plaques
slot_cy = -(strip_w / 2 + 1.4 + 2.6 + slot_h / 2);
// Logements T-Clip : sur l'axe vertical, à +/-20 mm (fentes Skådis d'une
// même colonne). Plaque -Y = haut de la tuile. Tuile maître : seulement
// celui du haut (celui du bas tomberait sur l'ESP32).
tclip_on = pointy && skadis_mount == "tclip";
// (décalés de 0,5 mm vers le haut pour s'écarter de la colonne d'aimant
//  du bas ; l'écart reste de 40 mm)
tclip_pos = master ? [[0, -20.5]] : [[0, -20.5], [0, 19.5]];
// Points et LED d'ambiance (pointy et flat ; pas avec les T-Clips)
amb_on = dots && !tclip_on;
dots_on = amb_on && !master;
// Circuit imprimé (led_mount = pcb). Tuile logo : seulement en pointy avec
// l'ESP32-C3 (le circuit place le module en biais vers le côté USB 5)
pcb_on = (led_mount == "pcb") && pointy && !d1;
// Le ruban est surélevé de l'entretoise + l'épaisseur du circuit
lift = pcb_on ? pcb_standoff + pcb_t : 0;
// Trous et contour des circuits, en VUE DE FACE (mm, y vers le haut).
// La plaque est retournée dans la coque : vue de face (x, y) = plaque (-x, -y).
pcb_holes_front = master
    ? [[0, 23], [20, -12], [-15.5, -26.85], [-20, -10]]
    : [[0, 23], [-20, -12], [20, -12], [0, -27]];
// circuits hexagonaux (6 connecteurs JST, un par côté ; sommets du circuit
// vers le milieu des côtés de la tuile, entre les colonnes aimantées)
// Circuit à la forme de la plaque (1 mm en retrait des parois), avec une
// encoche en U autour de chacune des 3 colonnes aimantées (tuile pointy)
pcb_outline_front = [[37.00, 14.90], [34.84, 13.65], [33.49, 13.09], [32.04, 12.90], [30.59, 13.09], [29.24, 13.65], [28.08, 14.54], [27.19, 15.70], [26.63, 17.05], [26.44, 18.50], [26.63, 19.95], [27.19, 21.30], [28.08, 22.46], [29.24, 23.35], [31.40, 24.60], [2.60, 41.22], [-2.60, 41.22], [-31.40, 24.60], [-29.24, 23.35], [-28.08, 22.46], [-27.19, 21.30], [-26.63, 19.95], [-26.44, 18.50], [-26.63, 17.05], [-27.19, 15.70], [-28.08, 14.54], [-29.24, 13.65], [-30.59, 13.09], [-32.04, 12.90], [-33.49, 13.09], [-34.84, 13.65], [-37.00, 14.90], [-37.00, -18.36], [-34.40, -22.86], [-5.60, -39.49], [-5.60, -37.00], [-5.41, -35.55], [-4.85, -34.20], [-3.96, -33.04], [-2.80, -32.15], [-1.45, -31.59], [-0.00, -31.40], [1.45, -31.59], [2.80, -32.15], [3.96, -33.04], [4.85, -34.20], [5.41, -35.55], [5.60, -37.00], [5.60, -39.49], [34.40, -22.86], [37.00, -18.36]];
// Fenêtres d'accès aux interrupteurs DIP (soudés au dos du circuit) :
// x des colonnes d'interrupteurs en vue de face (IN à gauche, OUT à droite)
pcb_dip_x_front = master ? [6.5] : [-6.5, 6.5];
// (pcb) Fenêtres dans la plaque pour basculer les interrupteurs avec une
// pointe, tuile décrochée du mur
pcb_holes = [for (h = pcb_holes_front) [-h[0], -h[1]]];
pcb_outline = [for (q = pcb_outline_front) [-q[0], -q[1]]];
// Tuile logo sur circuit : le module est surélevé, l'USB passe par une
// FENÊTRE fermée dans la paroi (et non plus une fente ouverte vers l'arrière).
// Hauteur du centre de la prise USB-C depuis le bord arrière de la coque :
usb_from_back = back_t + pcb_standoff + pcb_t + esp_spacer + esp_board_t + 1.6;
usb_win_z0 = max(face + 1.2, depth - usb_from_back - usb_h / 2);   // côté façade
usb_win_z1 = depth - usb_from_back + usb_h / 2;                    // côté arrière
// Boîtes : largeur du ruban + jeu ; hauteur jusqu'au ruban
cell_y = strip_w + 2 * 0.4;
rib_h_in = depth - back_t - face - 0.6 - rib_gap - lift;     // entre les LED, sur le circuit
rib_h_out = depth - back_t - face - 1.5 - rib_gap - lift;    // au-dessus des rails
// Trous et rainures des fils (coordonnées de la plaque ; -Y = haut de la
// tuile). Chaîne : haut (entrée) -> points -> bas (sortie).
dot_half = dots_n * dots_pitch / 2;            // 25 mm pour 5 LED
amb_half = amb_leds * dots_pitch / 2;          // 10 mm pour 2 LED
wp_on = wire_paths && dots_on;
wire_holes = [[-(amb_half + 1.5), -amb_offset], [amb_half + 1.5, -amb_offset],
              [dot_half + 1.5, 0], [-(dot_half + 1.5), 0],
              [-(amb_half + 1.5), amb_offset], [amb_half + 1.5, amb_offset]];
wire_grooves = [
    [[amb_half + 1.5, -amb_offset], [amb_half + 1.5, -2], [dot_half + 1.5, -2], [dot_half + 1.5, 0]],
    [[-(dot_half + 1.5), 0], [-(dot_half + 1.5), 2], [-(amb_half + 1.5), 2], [-(amb_half + 1.5), amb_offset]]
];
// (double) Piliers du socle : sur les 3 coins sans aimant, à 33 mm du centre
pillars = [for (k = [0 : 2]) [33 * cos(-(vertex_off + 60 + 120 * k)),
                               33 * sin(-(vertex_off + 60 + 120 * k))]];
// (double) Trous du plateau pour descendre les fils vers le double fond
dbl_holes = master ? [[master_leds * dots_pitch / 2 + 1.5, 0], [-(master_leds * dots_pitch / 2 + 1.5), 0]]
                   : (dots_on ? wire_holes : [[dot_half + 1.5, 0], [-(dot_half + 1.5), 0]]);
// Trou de serrure centré, en haut de la tuile une fois posée
key_x = 0;
// (flat : sous le logement d'os de chien du côté du haut)
key_y = pointy ? -(plate_R - 12.5) : -0.225 * flat;
wire_x = pointy ? 0.25 * flat : 0;
wire_y = pointy ? 0.22 * flat : 0.25 * flat;

// ---------------------------------------------------------------------

module hex2d(f, r) {
    rotate(hex_rot)
        offset(r = r) offset(delta = -r) circle(r = f / sqrt(3), $fn = 6);
}

// Place l'enfant au milieu du côté k (axe X local = normale sortante)
module side(k) {
    rotate([0, 0, side_off + 60 * k]) children();
}

module label2d() {
    // Miroir : le texte se lit correctement vu depuis la façade
    ts = text_size > 0 ? text_size : (border ? 0.12 : 0.14) * flat;
    // avec la barre de points (sur l'axe des LED), le nom monte un peu
    // le bas du nom (jambages compris) reste au-dessus des boîtes
    ty = amb_on ? cell_y / 2 + rib_t + 1 + 0.6 * ts : 0;
    translate([0, ty]) mirror([1, 0, 0]) {
        if (label2 == "") {
            text(label, size = ts, font = font,
                 halign = "center", valign = "center");
        } else {
            gap = 3;
            translate([0, gap / 2 + ts / 2])
                text(label, size = ts, font = font,
                     halign = "center", valign = "center");
            translate([0, -(gap / 2 + text_size2 / 2)])
                text(label2, size = text_size2, font = font,
                     halign = "center", valign = "center");
        }
    }
}

// Liseré : contour hexagonal en retrait du bord. En style stencil, il est
// coupé aux 6 sommets pour que le centre de la façade reste attaché.
module border2d() {
    difference() {
        hex2d(flat - 2 * border_inset, max(corner_r - border_inset, 0.5));
        hex2d(flat - 2 * (border_inset + border_w), 0.5);
        if (style == "stencil")
            for (k = [0 : 5]) rotate(hex_rot + 60 * k)
                translate([flat / 2, 0]) square([flat, 2], center = true);
    }
}

// Barre de points, centrée sur l'axe du ruban LED (Y = 0)
module dots2d() {
    for (i = [0 : dots_n - 1])
        translate([(i - (dots_n - 1) / 2) * dots_pitch, 0])
            circle(d = dots_d);
}

// Logo intégré : une balise qui émet des ondes (pas d'îlots : compatible
// avec tous les styles, y compris stencil)
module beacon_logo2d() {
    sc = logo_size / 34;
    scale(sc) translate([0, -8]) {
        circle(d = 6);                                  // la balise
        translate([-1.2, -12]) square([2.4, 12]);       // son mât
        translate([-6, -13.2]) square([12, 2.4]);       // son pied
        for (r = [10, 16])                              // les ondes
            intersection() {
                difference() { circle(r = r + 1.2); circle(r = r - 1.2); }
                polygon([[0, 0], [30, 25], [-30, 25]]);
            }
    }
}

module logo2d() {
    translate([0, logo_y]) mirror([1, 0, 0])
        if (logo_svg == "") beacon_logo2d();
        else resize([logo_size, 0], auto = true) import(logo_svg, center = true);
}

// Tout ce qui s'allume sur la façade
module art2d() {
    if (master && master_logo) logo2d(); else label2d();
    if (border) border2d();
    if (dots_on) dots2d();
}

// Boîtes fermées sur 4 côtés autour des points, de la façade jusqu'au
// ruban. Parois entre LED : descendent sur le circuit du ruban, entre
// deux LED. Parois haute/basse et bouts : s'arrêtent au-dessus des rails.
module dot_ribs3d() {
    w = dots_n * dots_pitch;
    ex = 2.6;                            // bouts écartés : soudures et fils
    translate([0, 0, face - eps]) {
        for (i = [0 : dots_n]) {
            x = (i - dots_n / 2) * dots_pitch - rib_t / 2
                + (i == 0 ? -ex : (i == dots_n ? ex : 0));
            inner = (i > 0 && i < dots_n);
            // partie centrale (sur le ruban)
            translate([x, -strip_w / 2 + 0.2, 0])
                cube([rib_t, strip_w - 0.4, inner ? rib_h_in : rib_h_out]);
            // raccord vers les parois haute/basse
            translate([x, -cell_y / 2 - rib_t / 2, 0])
                cube([rib_t, cell_y + rib_t, rib_h_out]);
        }
        for (s = [-1, 1])
            translate([-w / 2 - ex - rib_t / 2, s * cell_y / 2 - rib_t / 2, 0])
                cube([w + 2 * ex + rib_t, rib_t, rib_h_out]);
    }
}

// ----------------------------- Tuile ---------------------------------

module boss() {
    // Bossage d'aimant avec pente à 45° pour imprimer sans support
    hull() {
        translate([apothem - wall / 2, 0, mag_zz])
            rotate([0, -90, 0]) cylinder(d = boss_d, h = boss_len);
        translate([apothem - wall / 2 - eps, -boss_d / 2,
                   max(face, mag_zz - boss_d / 2 - boss_len)])
            cube([eps, boss_d, eps]);
    }
}

module magnet_pocket() {
    translate([apothem - mag_h, 0, mag_zz])
        rotate([0, 90, 0]) cylinder(d = mag_d, h = mag_h + 1);
}

// Avec le circuit imprimé, les connecteurs des côtés droit et gauche (vue de
// face) sont remontés de 8 mm (place du ruban des points) : leurs encoches aussi.
// Côtés du modèle (en miroir de la vue de face) : 0 = gauche, 3 = droite.
function notch_shift(k) = 0;   // connecteurs centres sur chaque cote

module notch() {
    // en mode défonçable, on s'arrête avant la face extérieure
    nl = notch_knockout ? wall + ledge_w + 1 - knockout_skin
                        : wall + ledge_w + 2;
    translate([apothem - wall - ledge_w - 1, -notch_w / 2,
               depth - back_t - notch_h])
        cube([nl, notch_w, notch_h + back_t + eps]);
}

module usb_cut() {
    if (pcb_on && master)
        // fenêtre fermée, centrée sur la prise du module
        translate([apothem - wall - ledge_w - 1, -usb_w / 2, usb_win_z0])
            cube([wall + ledge_w + 2, usb_w, usb_win_z1 - usb_win_z0]);
    else
        translate([apothem - wall - ledge_w - 1, -usb_w / 2, depth - usb_h])
            cube([wall + ledge_w + 2, usb_w, usb_h + eps]);
}

module ledge() {
    translate([0, 0, depth - back_t - ledge_h])
        linear_extrude(ledge_h)
            difference() {
                hex2d(inner_flat + eps, r_in);
                hex2d(inner_flat - 2 * ledge_w, max(r_in - ledge_w, 0.5));
            }
}

// Colonne de vis dans un coin, de la façade jusqu'au rebord,
// reliée à la paroi (imprimable sans support).
// La colonne ne touche la façade que contre la paroi : elle démarre
// plus haut avec une pente vers le coin, pour ne pas faire d'ombre
// sur le liseré (imprimable sans support).
col_lift = 10;
module screw_column(a) {
    z0 = min(face + col_lift, col_top - 7);
    rotate(a)
        hull() {
            translate([screw_r, 0, z0]) cylinder(d = column_d, h = col_top - z0);
            translate([inner_flat / sqrt(3) - 1.5, 0, face])
                cylinder(d = 3, h = (tray ? hc - base_lip_h - 0.3 : col_top) - face);
        }
}

module tile() {
    difference() {
        union() {
            difference() {
                linear_extrude(hc) hex2d(flat, corner_r);
                translate([0, 0, face])
                    linear_extrude(hc) hex2d(inner_flat, r_in);
            }
            if (magnets) for (k = [0 : 5], t = mag_offsets)
                if (!(master && k == USB_SIDE)) side(k) translate([0, t, 0]) boss();
            if (screws) for (a = screw_angles) screw_column(a);
            if (dots_on && dot_ribs) dot_ribs3d();
        }
        if (screws) for (a = screw_angles)
            rotate(a) translate([screw_r, 0, 0]) {
                if (use_magnet) {
                    // logement d'aimant au sommet de la colonne
                    translate([0, 0, col_top - mag_h])
                        cylinder(d = mag_d, h = mag_h + 1);
                } else if (use_insert) {
                    // logement de l'insert, ouvert côté plaque
                    translate([0, 0, depth - back_t - insert_len - 0.5])
                        cylinder(d = insert_d, h = insert_len + 1);
                    // dégagement pour le bout de la vis
                    translate([0, 0, depth - back_t - insert_len - 4.5])
                        cylinder(d = 2.6, h = 4.5);
                } else {
                    pz = max(face + 0.8, depth - back_t - 12);
                    translate([0, 0, pz])
                        cylinder(d = screw_pilot, h = depth - pz + 1);
                }
            }
        if (style == "glow")
            // Texte aminci depuis l'intérieur
            translate([0, 0, text_skin])
                linear_extrude(face - text_skin + eps) art2d();
        else if (style == "swap")
            // Lettres en creux sur l'avant, à travers la couche noire
            translate([0, 0, -eps])
                linear_extrude(swap_z + eps) art2d();
        else
            // Texte traversant : rempli par la pièce "letters"
            translate([0, 0, -eps])
                linear_extrude(face + 2 * eps) art2d();
        if (magnets) for (k = [0 : 5], t = mag_offsets)
            if (!(master && k == USB_SIDE)) side(k) translate([0, t, 0]) magnet_pocket();
        // encoches dans la coque : seulement en inset (en tray et double,
        // elles sont dans le bac / le socle)
        if (notches && plate_style == "inset") for (k = notch_sides)
            side(k) translate([0, notch_shift(k), 0]) notch();
        if (master) side(USB_SIDE) usb_cut();
    }
}

// ------------------------- Plaque arrière ----------------------------

// Entretoise du circuit imprimé : base évasée (solide, sans support) et
// avant-trou pour vis autotaraudeuse M2,5
module pcb_standoff3d() {
    ins = (pcb_fix == "insert");
    dd = ins ? pcb_insert_d + 3 : 5.5;            // paroi d'au moins 1,5 mm autour de l'insert
    difference() {
        union() {
            cylinder(d = dd, h = pcb_standoff + eps);
            cylinder(d1 = dd + 2.5, d2 = dd, h = 1.5);
        }
        if (ins) {
            // logement de l'insert (ouvert en haut) + degagement pour le bout de la vis
            translate([0, 0, pcb_standoff - pcb_insert_len - 0.3]) cylinder(d = pcb_insert_d, h = pcb_insert_len + 1);
            translate([0, 0, 0.8]) cylinder(d = 2.7, h = pcb_standoff);
        } else
            translate([0, 0, 0.8]) cylinder(d = pcb_pilot, h = pcb_standoff);
    }
}

// Silhouette du circuit imprimé (aperçu seulement)
module pcb2d() {
    difference() {
        polygon(pcb_outline);
        for (h = pcb_holes) translate(h) circle(d = 2.7);
    }
}

module back_plate() {
    rail_w = 1.2;
    rail_h = 1.5;
    half = strip_w / 2 + 0.2 + rail_w;          // demi-largeur du couloir LED
    // --- orientation flat : ruban perpendiculaire au berceau (comme avant)
    y_back = inner_flat / 2 - ledge_w - 0.5 - esp_l - 1.2;
    r_off_flat = master ? min(0, y_back - 1 - half) : 0;
    rl_flat = min(rail_len,
             2 * (plate_R - (half + abs(r_off_flat)) * tan(30) - 2),
             screws ? 2 * (screw_r - column_d / 2 - 1) : 1000);
    // --- orientation pointy : ruban horizontal et centré, dans le sens du
    // texte. L'ESP32 de la tuile maître est en diagonale, hors du ruban.
    r_off_pt = 0;
    rl_pt = min(rail_len, 2 * (inner_flat / 2 - tol - 2));
    rail_rot = pointy ? 0 : cradle_angle - 90;
    r_off = pointy ? r_off_pt : r_off_flat;
    // tuile logo : rails à la longueur de son ruban (master_leds)
    rl = min(pointy ? rl_pt : rl_flat, master ? master_leds * dots_pitch + 6 : 1000);
    difference() {
        union() {
            if (tray) {
                // fond du bac, à la taille extérieure de la tuile
                linear_extrude(back_t) hex2d(flat, corner_r);
                // rebords du bac
                translate([0, 0, back_t - eps]) linear_extrude(base_wall_h + eps)
                    difference() { hex2d(flat, corner_r); hex2d(inner_flat, r_in); }
                // bourrelet de centrage (entre dans la coque)
                translate([0, 0, back_t + base_wall_h - eps]) linear_extrude(base_lip_h + eps)
                    difference() {
                        hex2d(inner_flat - 2 * tol, r_in);
                        hex2d(inner_flat - 2 * tol - 2 * base_lip_w, max(r_in - base_lip_w, 0.5));
                    }
            } else {
                // ancienne plaque plate, emboîtée dans la coque
                linear_extrude(back_t) hex2d(inner_flat - 2 * tol, r_in);
            }
            // Circuit imprimé : 3 entretoises à la place des rails
            if (pcb_on) for (h = pcb_holes)
                translate([h[0], h[1], back_t - eps]) pcb_standoff3d();
            // Rails de guidage du ruban LED (pas en D1 mini : ruban sur le pont)
            if (!d1 && !pcb_on) rotate([0, 0, rail_rot])
                for (s = [-1, 1])
                    translate([-rl / 2,
                               r_off + s * (strip_w / 2 + 0.2 + rail_w / 2) - rail_w / 2,
                               back_t - eps])
                        cube([rl, rail_w, rail_h]);
            // Rails des LED d'ambiance (plaque -Y = haut de la tuile) :
            // en haut sur toutes les tuiles, en bas sauf la maître
            if (amb_on && (!master || master_amb) && !pcb_on)
                for (ay = master ? [-amb_offset] : [-amb_offset, amb_offset])
                    for (s = [-1, 1])
                        translate([-(amb_leds * dots_pitch + 2) / 2,
                                   ay + s * (strip_w / 2 + 0.2 + rail_w / 2) - rail_w / 2,
                                   back_t - eps])
                            cube([amb_leds * dots_pitch + 2, rail_w, rail_h]);
        }
        // Fenêtres des interrupteurs DIP du circuit (vue de face x -> plaque -x)
        if (pcb_on && pcb_dip_window) for (dx = pcb_dip_x_front)
            translate([-dx - 3.6, -8.6, -1]) cube([7.2, 17.2, back_t + 2]);   // DIP 6,7 x 16,8 mm
        // Passage de fils optionnel (tuiles non maîtres)
        if (wire_hole && !master)
            translate([wire_x, wire_y, -eps]) cylinder(d = wire_hole_d, h = back_t + 1);
        // Logements d'aimant ouverts côté arrière de la plaque, avec un
        // chanfrein d'entrée (cette face est sur le plateau : la première
        // couche écrasée rétrécit l'entrée du trou)
        if (screws && use_magnet && plate_mag_side == "back") for (a = screw_angles)
            rotate(-a) translate([screw_r, 0, -eps]) {
                cylinder(d = mag_d, h = mag_h + eps);
                cylinder(d1 = mag_d + 1, d2 = mag_d, h = 0.5);
            }
        // Logements d'aimant ouverts sur le dessus (fond de 0,4 mm)
        if (screws && use_magnet && plate_mag_side == "top") for (a = screw_angles)
            rotate(-a) translate([screw_r, 0, back_t + plate_boss_h - mag_h])
                cylinder(d = mag_d, h = mag_h + 1);
        // Trous de vis (positions en miroir : la plaque est retournée)
        if (screws && !use_magnet) for (a = screw_angles)
            rotate(-a)
                translate([screw_r, 0, -eps])
                    cylinder(d = use_insert ? insert_screw_clear : screw_clear,
                             h = back_t + 1);
        // Trous et rainures des fils (au dos de la plaque)
        // (double) trous des pions des piliers + trous de passage des fils
        if (dbl) {
            for (q = pillars) translate([q[0], q[1], -1])
                cylinder(d = dbl_fix == "insert" ? insert_screw_clear
                           : dbl_fix == "self_tap" ? screw_clear : 3.1, h = back_t + 2);
            for (h = dbl_holes) translate([h[0], h[1], -1])
                cylinder(d = dbl_wire_hole, h = back_t + 2);
        }
        if (wp_on && !dbl) {
            for (h = wire_holes) translate([h[0], h[1], -1])
                cylinder(d = wire_hole_size, h = back_t + 2);
            for (path = wire_grooves)
                for (k = [0 : len(path) - 2])
                    hull() for (q = [path[k], path[k + 1]])
                        translate([q[0], q[1], -1]) cylinder(d = groove_w, h = groove_d + 1);
        }
        // Encoches des rebords (câbles et os de chien), ouvertes vers le haut,
        // défonçables ; la coque vient les fermer en se posant
        if (tray && notches) for (k = notch_sides)
            if (!(master && k == USB_SIDE))
                rotate(-(side_off + 60 * k)) {
                    nl = notch_knockout ? wall + 1 - knockout_skin : wall + 2;
                    translate([inner_flat / 2 - 1, -notch_w / 2, back_t])
                        cube([nl, notch_w, base_wall_h + base_lip_h + 1]);
                }
        // Ouverture USB de la tuile maître dans le rebord
        if (tray && master) rotate(-usb_angle)
            translate([inner_flat / 2 - 1, -usb_w / 2, back_t])
                cube([wall + 2, usb_w, base_wall_h + base_lip_h + 1]);
        // Logements des os de chien (liaison avec les plaques voisines),
        // au milieu de chaque côté ; pas sur le côté USB de la tuile maître
        if (plate_links && !dbl) for (k = [0 : 5])
            if (!(master && k == USB_SIDE))
                rotate(-(side_off + 60 * k)) link_pocket3d(back_t);
        // Fente oblongue des logements T-Clip, à travers la plaque
        if (tclip_on) for (p = tclip_pos)
            translate([p[0], p[1], -1]) hull()
                for (s = [-1, 1]) translate([0, s * (15.2 - 5.2) / 2, 0])
                    cylinder(d = 5.2, h = back_t + 2);
        // Trous des pieds du pont LED (D1 mini)
        if (d1) for (p = bridge_legs)
            translate([p[0], p[1], -1]) cylinder(d = 3.1, h = back_t + 2);
        // Fentes Skådis (D1 mini : seulement à gauche, la carte occupe la droite)
        if (slot_on && !dbl) for (sx = d1 ? [-slot_x] : [-slot_x, slot_x])
            translate([sx - slot_w / 2, slot_cy - slot_h / 2, -eps])
                cube([slot_w, slot_h, back_t + 1]);
        // Trou de serrure : petit bout de la fente vers -Y de la plaque,
        // qui devient le haut une fois la plaque retournée et posée.
        // (supprimé avec les T-Clips : il tomberait sur le logement du haut)
        if (keyhole && !tclip_on && !dbl && (pointy || !amb_on)) {
            translate([key_x, key_y, -eps]) cylinder(d = 8, h = back_t + 1);
            hull() {
                translate([key_x, key_y, -eps]) cylinder(d = 4, h = back_t + 1);
                translate([key_x, key_y - 7, -eps]) cylinder(d = 4, h = back_t + 1);
            }
        }
    }
    // berceau de l'ESP32 (pas avec le circuit : le module est soudé dessus)
    if (master && !pcb_on) rotate([0, 0, cradle_angle - 90]) esp_cradle();
    if (tclip_on) for (p = tclip_pos) translate([p[0], p[1], 0]) tclip_receiver();
    // Mode aimant : bossages bas face aux colonnes. L'aimant se pose par
    // l'ARRIÈRE de la plaque ; une peau de 0,4 mm côté coque le retient
    // (l'attraction le plaque contre elle).
    if (screws && use_magnet) for (a = screw_angles)
        rotate(-a) translate([screw_r, 0, 0])
            difference() {
                translate([0, 0, back_t - eps])
                    cylinder(d = column_d, h = plate_boss_h + eps);
                if (plate_mag_side == "back")
                    translate([0, 0, -1]) cylinder(d = mag_d, h = mag_h + 1);
                else
                    translate([0, 0, back_t + plate_boss_h - mag_h])
                        cylinder(d = mag_d, h = mag_h + 1);
            }
}

// Logement T-Clip (cotes relevées sur la pièce d'exemple du "Skadis
// T-Clip System") : fente oblongue 5,2 x 15,2 mm sur 2,5 mm côté panneau,
// puis cône de 16,4 à 21,4 mm jusqu'à 5,4 mm d'épaisseur totale.
// Le clip se pose depuis l'intérieur (coque retirée) et se tourne d'1/4
// de tour : sa barre de 28 mm balaie un cercle de ~29 mm au-dessus.
tclip_total = 5.4;
module tclip_receiver() {
    difference() {
        // bossage côté intérieur, pour atteindre 5,4 mm d'épaisseur
        translate([0, 0, back_t - eps])
            cylinder(d = 24, h = tclip_total - back_t + eps);
        // fente oblongue verticale (dans l'axe Y de la plaque)
        translate([0, 0, -1]) hull()
            for (s = [-1, 1]) translate([0, s * (15.2 - 5.2) / 2, 0])
                cylinder(d = 5.2, h = 3.5 + 1);
        // cône d'appui des flancs du clip
        translate([0, 0, 2.5])
            cylinder(r1 = 8.2, r2 = 10.7, h = tclip_total - 2.5 + eps);
    }
}

// Pont LED (D1 mini) : plateau 52 x 35 sur 4 pieds de 6 mm, posé au-dessus
// de la carte. Le ruban de 5 LED se colle dans la rainure, LED vers la
// façade. Imprimé face LED sur le plateau, pieds vers le haut.
bridge_legs = [[-23.5, -4], [23.5, -16.5], [-23.5, 16.5], [23.5, 16.5]];
bridge_h = 6;      // hauteur sous le plateau (D1 mini sans barrettes : ~5 mm)
bridge_t = 2;
module led_bridge() {
    difference() {
        translate([-26, -17.7, 0]) cube([52, 35.4, bridge_t]);
        // rainure du ruban, 0,6 mm, côté LED (sur le plateau)
        translate([-26 - 1, -(strip_w + 0.4) / 2, -1]) cube([54, strip_w + 0.4, 1.6]);
    }
    for (p = bridge_legs) translate([p[0], p[1], 0]) {
        translate([-1.2, -1.2, bridge_t - eps]) cube([2.4, 2.4, bridge_h]);
        // pion qui s'emboîte dans la plaque
        translate([0, 0, bridge_t + bridge_h - eps]) cylinder(d = 2.8, h = back_t);
    }
}

// Socle du DOUBLE FOND (plate_style = double). Imprimé fond sur le plateau.
// Fond à la taille de la tuile + rebords de dbl_space (la coque se pose
// dessus) + 3 piliers à pions qui portent le plateau LED. Les fixations
// murales sont ici : fentes Skådis, trou de serrure, os de chien.
module dbl_base() {
    H = dbl_space;
    pil_d = dbl_fix == "insert" ? max(6, insert_d + 3.5) : 6;
    difference() {
        union() {
            linear_extrude(back_t) hex2d(flat, corner_r);
            translate([0, 0, back_t - eps]) linear_extrude(H + eps)
                difference() { hex2d(flat, corner_r); hex2d(inner_flat, r_in); }
            for (q = pillars) translate([q[0], q[1], 0]) {
                translate([0, 0, back_t - eps]) cylinder(d = pil_d, h = H + eps);
                if (dbl_fix == "peg")
                    translate([0, 0, back_t + H - eps]) cylinder(d = 2.8, h = back_t - 0.3);
            }
        }
        // logements de fixation au sommet des piliers
        for (q = pillars) translate([q[0], q[1], 0]) {
            if (dbl_fix == "insert") {
                translate([0, 0, back_t + H - insert_len - 0.5])
                    cylinder(d = insert_d, h = insert_len + 1);
                translate([0, 0, back_t + H - insert_len - 3.5]) cylinder(d = 2.6, h = 3.1);
            }
            if (dbl_fix == "self_tap")
                translate([0, 0, back_t + 0.8]) cylinder(d = screw_pilot, h = H + 1);
        }
        // encoches défonçables des rebords (câbles JST, os de chien)
        if (notches) for (k = notch_sides)
            rotate(-(side_off + 60 * k)) {
                nl = notch_knockout ? wall + 1 - knockout_skin : wall + 2;
                translate([inner_flat / 2 - 1, -notch_w / 2, back_t])
                    cube([nl, notch_w, H + 1]);
            }
        // os de chien
        if (plate_links) for (k = [0 : 5])
            rotate(-(side_off + 60 * k)) link_pocket3d(back_t);
        // fentes Skådis
        if (skadis_mount == "clips") for (sx = [-slot_x, slot_x])
            translate([sx - slot_w / 2, slot_cy - slot_h / 2, -1])
                cube([slot_w, slot_h, back_t + 2]);
        // trou de serrure (au-dessus du centre de la tuile)
        if (keyhole) {
            translate([0, -12, -1]) cylinder(d = 8, h = back_t + 2);
            hull() for (y = [-12, -19]) translate([0, y, -1]) cylinder(d = 4, h = back_t + 2);
        }
    }
}

// Os de chien : 2 têtes rondes reliées par un col qui traverse l'écart
// entre deux plaques (2 parois de coque + jeu = 4,5 mm en 80 mm).
link_head_r = 3.5;
link_neck_w = 6;
link_in = 5;          // distance tête - bord de plaque
link_clr = 0.15;      // jeu dans les logements
link_gap = 2 * (wall + tol);
module link2d() {
    c = link_in + link_gap / 2;
    for (s = [-1, 1]) translate([s * c, 0]) circle(r = link_head_r);
    translate([-c, -link_neck_w / 2]) square([2 * c, link_neck_w]);
}
// Logement d'os de chien avec chanfrein côté plateau d'impression
// (compense la première couche écrasée, « patte d'éléphant »)
module link_pocket3d(h) {
    translate([0, 0, -1]) linear_extrude(h + 2) link_pocket2d();
    translate([0, 0, -eps]) linear_extrude(0.25 + eps) offset(delta = 0.5) link_pocket2d();
    translate([0, 0, 0.25 - eps]) linear_extrude(0.25 + eps) offset(delta = 0.25) link_pocket2d();
}

// Os de chien avec bords chanfreinés (dessous : patte d'éléphant ;
// dessus : entrée facilitée)
module link3d(fit = link_fit) {
    linear_extrude(0.3) offset(delta = fit - 0.4) link2d();
    translate([0, 0, 0.3 - eps]) linear_extrude(back_t - 0.5 + eps) offset(delta = fit) link2d();
    translate([0, 0, back_t - 0.2 - eps]) linear_extrude(0.2 + eps) offset(delta = fit - 0.2) link2d();
}

module link_pocket2d() {
    ap = (inner_flat - 2 * tol) / 2;
    translate([ap - link_in, 0]) circle(r = link_head_r + link_clr);
    translate([ap - link_in, -link_neck_w / 2 - link_clr])
        square([flat / 2 + 1 - (ap - link_in), link_neck_w + 2 * link_clr]);
}

// Berceau de l'ESP32 (construit vers +Y puis tourné vers le côté USB).
// Une fois la plaque retournée et posée, le port USB-C fait face
// à l'ouverture de la tuile.
module esp_cradle() {
    g = 1.2;          // épaisseur des guides
    gh = 2.5;         // hauteur des guides
    y_port = inner_flat / 2 - ledge_w - 0.5;   // bord côté USB
    y_back = y_port - eL;
    // Butée étroite et guides qui démarrent 3 mm plus loin : en diagonale,
    // les coins du berceau restent ainsi à l'écart du ruban LED.
    translate([0, 0, back_t - eps]) {
        // butée arrière (le câble pousse la carte contre elle)
        translate([-5, y_back - g, 0]) cube([10, g, gh]);
        // guides latéraux, ouverts côté USB
        for (s = [-1, 1])
            translate([s > 0 ? eW / 2 : -eW / 2 - g, y_back + 3, 0])
                cube([g, eL * 0.6 - 3, gh]);
    }
}

// ------------------------- Socle de bureau ---------------------------
// Barre avec une encoche en V par tuile (orientation pointy).
// Repère : X = longueur, Y = vers l'arrière, Z = vers le haut.
// La tuile maître se place à gauche : son USB sort par le côté.

module tilted() {
    lift = (depth + 2 * tol + lip) * sin(tilt);
    translate([0, 0, lift]) rotate([-tilt, 0, 0]) children();
}

module stand() {
    D = depth + 2 * tol;
    L = stand_tiles * flat;
    h = stand_floor + lip_h;
    lift = (D + lip) * sin(tilt);
    // hauteur du bloc = point le plus haut des joues inclinées
    top = lift + h * cos(tilt) + lip * sin(tilt);
    difference() {
        // bloc droit, faces verticales
        translate([-L / 2, -stand_front, 0])
            cube([L, stand_front + D + stand_back, top]);
        // une encoche en V (contour de la tuile + jeu) par tuile
        for (i = [0 : stand_tiles - 1])
            tilted()
                translate([(i - (stand_tiles - 1) / 2) * flat, 0,
                           stand_floor + R_hex])
                    rotate([-90, 0, 0])
                        linear_extrude(D)
                            offset(delta = tol) hex2d(flat, corner_r);
        // passage de la fiche USB de la tuile maître (tuile de gauche,
        // côté en biais en bas à gauche vu de face, vers l'arrière)
        if (stand_usb && pointy && esp_board != "d1mini")
            tilted()
                translate([-(stand_tiles - 1) / 2 * flat, 0, stand_floor + R_hex])
                    rotate([0, 120, 0])
                        translate([apothem - wall - 1, depth - usb_h - 1,
                                   -(usb_w + 4) / 2])
                            cube([40, 100, usb_w + 4]);
        // tout ce qui passe sous le bureau
        translate([-500, -100, -100]) cube([1000, 300, 100]);
    }
}

// ---------------------------------------------------------------------

// Lettres seules (style dark_face) : à charger avec la tuile comme
// un seul objet en plusieurs pièces dans le trancheur.
module letters() {
    linear_extrude(face) art2d();
}

// Bouchon d'encoche : remplit la paroi et la découpe du rebord.
// Imprimé debout, face extérieure (Y = 0) affleurant la tuile.
// La plaque arrière vient appuyer sur sa partie "rebord".
module plug() {
    w = notch_w - 2 * tol;
    h = notch_h + back_t;
    cube([w, wall, h]);
    translate([0, wall - eps, notch_h - ledge_h]) cube([w, ledge_w, ledge_h]);
}

// Adaptateur Skådis : 2 crochets au dos (fentes espacées de 40 mm
// sur une même rangée), un insert laiton M3 devant. Une vis M3 laissée
// dépasser de ~3 mm sert de "clou" pour le trou de serrure de la tuile.
// Imprimé tel quel, face du bas sur le plateau, sans support.
// Repère : X = largeur, Y = vers la tuile (Y < 0 = derrière le panneau),
// Z = vertical.
module skadis_adapter() {
    hw = skadis_hook_w / 2;
    difference() {
        union() {
            // barre
            translate([-24, 0, 0]) cube([48, 6, 14]);
            for (sx = [-20, 20]) translate([sx - hw, 0, 0]) {
                // tige qui traverse la fente (repose en bas de la fente)
                translate([0, -skadis_board, 6]) cube([2 * hw, skadis_board + eps, 6]);
                // ergot qui descend derrière le panneau
                translate([0, -skadis_board - 2, 0]) cube([2 * hw, 2, 12]);
            }
        }
        // logement de l'insert, ouvert vers la tuile
        translate([0, -1, 7]) rotate([-90, 0, 0])
            cylinder(d = insert_d, h = 8);
    }
}

if (part == "skadis") skadis_adapter();

if (part == "led_bridge") led_bridge();

// Clip à câbles : un U sur une semelle, avec 2 ergots qui retiennent les
// fils. À coller sur la plaque (cyano ou adhésif double face).
module cable_clip() {
    w = cable_clip_gap + 2 * 1.2;
    cube([w, 7, 1]);
    for (sx = [0, w - 1.2]) translate([sx, 0, 1 - eps]) cube([1.2, 7, cable_clip_h]);
    // ergots
    for (sg = [0, 1])
        translate([sg == 0 ? 1.2 - eps : w - 1.2 - 0.4 + eps, 0, 1 + cable_clip_h - 0.8])
            cube([0.4, 7, 0.8]);
}
if (part == "cable_clips")
    for (i = [0 : cable_clip_count - 1])
        translate([(i % 4) * (cable_clip_gap + 6), floor(i / 4) * 10, 0]) cable_clip();
if (part == "base") {
    if (!dbl) echo("ATTENTION : part = base sert au style plate_style = double");
    dbl_base();
}

if (part == "links")
    for (i = [0 : link_count - 1])
        translate([0, i * (2 * link_head_r + 3), 0])
            link3d();

// Éprouvette de serrage : 4 os (0,05 / 0,10 / 0,15 / 0,20 mm),
// repérés par 1 à 4 encoches sur le col. Garder celui qui entre en
// forçant légèrement, puis reporter sa valeur dans link_fit.
if (part == "link_test")
    for (i = [0 : 3])
        translate([0, i * (2 * link_head_r + 4), 0])
            difference() {
                link3d(0.05 * (i + 1));
                for (j = [0 : i])
                    translate([(j - i / 2) * 1.6 - 0.3, link_neck_w / 2 - 0.6 + 0.05 * (i + 1), back_t - 0.5])
                        cube([0.6, 1, 1]);
            }

// Éprouvette : 4 encoches défonçables (peau de 0,4 / 0,6 / 0,8 / 1,0 mm),
// même paroi et même encoche que la tuile. Imprimée debout, comme la tuile.
module knockout_test() {
    skins = [0.4, 0.6, 0.8, 1.0];
    pitch = notch_w + 6;
    h = notch_h + back_t + 4;
    difference() {
        cube([pitch * len(skins) + 2, wall, h]);
        for (i = [0 : len(skins) - 1]) {
            // encoche ouverte en haut, peau côté Y = 0 (extérieur)
            translate([3 + i * pitch, skins[i], h - notch_h - back_t])
                cube([notch_w, wall, notch_h + back_t + eps]);
            // repère : i+1 crans gravés sous l'encoche
            for (j = [0 : i])
                translate([3 + i * pitch + j * 2, -eps, 1])
                    cube([1, 0.4, 2]);
        }
    }
}

if (part == "knockout_test") knockout_test();

// Clip Skådis SIMPLE À PINCES (snap) : deux bras souples terminés par des
// crochets traversent la fente de la plaque puis celle du panneau, se
// resserrent au passage et s'écartent derrière le panneau (clic).
// Les bras occupent toute la hauteur de la fente (pas de jeu vertical),
// la tête (8 x 18 mm) serre la plaque contre le panneau. Crochets
// inclinés au dos : on peut le retirer en tirant fermement.
// Profil vu de côté (U = vers le mur, V = vertical), extrudé sur la
// largeur ; imprimé à plat, de préférence en PETG.
module skadis_snap() {
    L = back_t + skadis_board + 0.1;     // plaque + panneau
    o = slot_h / 2 - 0.4;                // bord extérieur des bras (7,2)
    i = o - snap_arm_t;                  // bord intérieur
    b = 7.5 + snap_barb;                 // crochet (fente du panneau : 15 mm)
    // tête, plus large que la fente (8 mm), sur toute sa hauteur
    translate([-2, -9, 0]) cube([2, 18, 8]);
    linear_extrude(skadis_hook_w)
        for (sg = [-1, 1]) scale([1, sg])
            polygon([[-eps, i], [-eps, o], [L, o], [L + 0.8, b],
                     [L + 3.2, o - 1.4], [L + 3.2, i - 1.0], [L + 0.8, i]]);
}

// Clip Skådis QUART DE TOUR (même principe que le T-Clip, en plus petit) :
// 1. Coque retirée, plaque posée contre le panneau, on enfonce le clip
//    depuis l'intérieur, PIED À LA VERTICALE, à travers la fente de la
//    plaque puis celle du panneau.
// 2. On tourne d'un quart de tour par la tête : le pied (14,8 mm) passe à
//    l'horizontale derrière le panneau et ne peut plus ressortir par la
//    fente de 5 mm ; la tête (13 mm) serre la plaque contre le panneau.
// Tige à angles arrondis (diagonale 5 mm) pour tourner dans les fentes.
// Imprimé à plat, sans support. Pour démonter : quart de tour inverse.
module skadis_clip() {
    L = back_t + skadis_board + 0.15;    // plaque + panneau, léger jeu
    t = 4.8;                             // épaisseur (= hauteur d'impression)
    // pied (derrière le panneau), avec chanfreins d'entrée
    hull() {
        translate([-7.4, 0, 0]) cube([14.8, 2, t]);
        translate([-6.4, -1, 0]) cube([12.8, 1, t]);
    }
    // tige : carré de 4,8 aux angles arrondis
    translate([0, 2 - eps, 0]) intersection() {
        translate([-t / 2, 0, 0]) cube([t, L + 2 * eps, t]);
        translate([0, 0, t / 2]) rotate([-90, 0, 0]) cylinder(d = 5.0, h = L + 2 * eps);
    }
    // tête / poignée (dans la tuile)
    translate([-6.5, 2 + L, 0]) cube([13, 2.5, t]);
}

if (part == "skadis_clips") {
    if (!slot_on) echo("ATTENTION : activer skadis_slots, orientation pointy");
    if (master && flat < 80) echo("ATTENTION : tuile maître Skådis : flat >= 80");
    for (i = [0 : 1]) translate([i * 22, 0, 0])
        if (skadis_clip_type == "twist") skadis_clip(); else skadis_snap();
}

if (part == "plugs")
    for (i = [0 : plug_count - 1]) translate([i * (notch_w + 4), 0, 0]) plug();

if (master && pointy && !d1 && esp_l > 25)
    echo("ATTENTION : carte trop longue pour la diagonale : choisir esp_board = d1mini (pont LED) ou un ESP32-C3 Super Mini.");

if (part == "tile" || part == "both") tile();
if (part == "letters") letters();
if (part == "back" || part == "both")
    translate([flat + 10, 0, 0]) {
        back_plate();
        // aperçu du circuit en transparence (non exporté)
        if (pcb_on) %translate([0, 0, back_t + pcb_standoff])
            color("green") linear_extrude(pcb_t) pcb2d();
    }
if (pcb_on && (part == "back" || part == "both" || part == "tile"))
    echo(str("CIRCUIT : 3 vis M2,5 x 6 autotaraudeuses. Ruban surélevé de ",
             lift, " mm : cloisons des points raccourcies d'autant ",
             "(réimprimer la coque, les anciennes cloisons touchent le circuit)."));
if (led_mount == "pcb" && !pcb_on)
    echo("Circuit imprimé prévu seulement en orientation pointy (et ESP32-C3 pour la tuile logo) : ruban sur rails.");
if (pcb_on && master && depth - usb_from_back - usb_h / 2 < face + 1.2)
    echo("ATTENTION : fenêtre USB trop près de la façade : augmenter depth (26 conseillé).");
if (pcb_on && master)
    echo(str("CIRCUIT LOGO : 4 vis M2,5 x 6. Garder l'entretoise plastique des barrettes ",
             "de l'ESP32 (", esp_spacer, " mm) : une vis passe sous le module."));
if (part == "stand") {
    if (!pointy) echo("ATTENTION : le socle est prévu pour orientation = \"pointy\"");
    stand();
}
