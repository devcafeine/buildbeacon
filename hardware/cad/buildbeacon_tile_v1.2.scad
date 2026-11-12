// =====================================================================
//  BuildBeacon - hexagonal light-up tile (parametric)
//  Version 1.2 (2026-11-12) - comments in English
//  v1.1: references the v1.2 boards
//  v1.0: first public version
//  Boards: buildbeacon_tuile_v1.2 / buildbeacon_master_v1.2
//  Source: https://github.com/devcafeine/buildbeacon (hardware/cad)
//  Hardware license: CERN-OHL-P-2.0
//
//  Printing:
//   - Tile: front face down on the build plate, no supports, white or
//     "natural" PLA/PETG. The text is thinned from the inside: it shows
//     brighter than the rest of the front (single color).
//   - Back plate: printed with the ribs facing up.
//   - Stand: flat, as is.
//
//  "pointy" orientation (default): points at the top and bottom,
//  flat sides on the left and right -> the tiles line up in a row
//  on the desk stand and also form a honeycomb on the wall.
//
//  6x3 mm magnets: polarity alternates from one side to the next
//  (sides 0,2,4 = North facing out; 1,3,5 = South).
//  So any tile snaps onto any other.
// =====================================================================

/* [Style] */
// glow = single color, thinned text that glows brighter
// swap = single color + 1 filament change: black front, white letters
// dark_face = multicolor: dark front, only the letters light up
// stencil = single color, through-cut letters + tracing paper glued behind.
//           Use a stencil font (e.g. "Stardos Stencil:style=Bold")
//           otherwise the inside of the letters (o, D, a...) falls out.
style = "glow"; // [glow, swap, dark_face, stencil]
// (swap) Black thickness at the front: change filament at this height
swap_z = 0.8;

/* [Text] */
// Displayed project name
label = "BuildBeacon";
// Optional second line (leave empty for none)
label2 = "";
font = "Liberation Sans:style=Bold";
// Main text size (0 = automatic from the tile size; reduce if the name is long)
text_size = 0;
text_size2 = 7;
// Remaining thickness in front of the text (mm): thinner = brighter
text_skin = 0.6;

/* [Decoration] */
// Master tile = "head" tile: a logo instead of the name
master_logo = true;
// Logo SVG file (empty = built-in "beacon" logo). E.g. "logo.svg"
logo_svg = "";
// Logo width (mm)
logo_size = 34;
// Logo vertical offset (mm, + = up)
logo_y = 3;
// Light-up border following the tile outline
border = true;
// Distance from the border to the outer edge (beyond the magnet bosses)
border_inset = 7.5;
border_w = 1.2;
// Dot row under the name: 1 dot per LED, each lit individually.
// The 5 dot LEDs are enclosed; 2 LEDs above and 2 below
// light the name and the border. No dots on the master tile (no
// room under the ESP32), nor with T-Clips (receivers on the axis).
dots = true;
// Ambient LEDs above / below the dots
amb_leds = 2;
// (Vertical) distance from the ambient LEDs to the tile center
amb_offset = 16;
// Logo tile: 2 ambient LEDs at the top in addition to the central strip
// (only useful if the top of the logo/border looks too dark)
master_amb = false;
// Number of dots (= number of LEDs behind them)
dots_n = 5;
// Dot spacing = LED pitch of the strip (100 LEDs/m -> 10 mm)
dots_pitch = 10;
dots_d = 4;
// Wire routing between the strip pieces THROUGH THE BACK of the plate:
// a hole at the end of each piece, grooves on the back connecting them
// (off by default: with thick wire, use the cable clips)
wire_paths = false;
// Sized for 3 silicone 28 AWG wires (Ø ~1.1 mm) side by side
groove_w = 3.6;
groove_d = 1.2;
wire_hole_size = 3.6;
// Closed boxes around the dots, up to the strip: each LED
// lights only its own dot
dot_ribs = true;
// Clearance between the top of the walls and the strip (mm)
rib_gap = 0.4;
rib_t = 0.8;

/* [Tile] */
// pointy = point at the top (rows on a desk); flat = flat side at the top
orientation = "pointy"; // [pointy, flat]
// Width across the flat sides (mm) — 65 minimum
flat = 80;
// Total depth (mm)
depth = 22;
wall = 2;
// Front thickness (mm)
face = 1.6;
corner_r = 3;

/* [Plate links] */
// The back plates are joined to each other by "dog bone" pieces
// (part = links), straddling the middle of the shared sides,
// through the open notch. The assembly forms a rigid panel:
// a few clipped or screwed tiles are enough to hold everything.
plate_links = true;
// Number of dog bones to print (part = links)
link_count = 6;
// Dog bone fit (mm per side): enlarges the bone without changing the
// plate pockets. 0 = original; larger = less clearance.
// To find the right value: part = link_test (4 bones from 0.05 to 0.20).
link_fit = 0.10; // [0:0.025:0.3]

/* [Side magnets (optional)] */
// Magnets on the sides of the shells. Not needed with plate links.
magnets = false;
// Magnets per side: 2 = no pivoting or sliding between tiles.
// Polarity (2 magnets): going clockwise around the tile seen from the
// front, on EACH side the 1st magnet
// encountered has North facing out, the 2nd South. All tiles
// then snap together on any side.
side_magnets = 2; // [1, 2]
// Magnet offset from the middle of the side (mm)
mag_spread = 10;
// Opening side of the magnet pockets in the back plate:
// top = on the top (shell side, easier to print, magnet glued)
// back = from the back (build plate side)
plate_mag_side = "top"; // [top, back]
// Pocket diameter (6 mm magnet + clearance; printed holes come out
// smaller: usually 6.4 to 6.5)
mag_d = 6.4;
// Pocket depth (3 mm magnet + clearance)
mag_h = 3.2;
// Height of the magnet centers from the front (0 = automatic)
mag_z = 0;

/* [Cable routing] */
notches = true;
// Sides with a notch, SEEN FROM THE FRONT (pointy orientation):
// 0 = left, 1 = top-left, 2 = top-right,
// 3 = right, 4 = bottom-right, 5 = bottom-left
notch_sides = [0, 1, 2, 3, 4, 5];
notch_w = 10;
notch_h = 4;
// Knockout notches: closed by a thin skin to break out if needed
notch_knockout = true;
knockout_skin = 0.6;
// Number of plugs to print (part = plugs). Not needed with knockout
// notches; glue one in to close an opened notch.
plug_count = 4;

/* [Back plate] */
back_t = 2;
// tray  = the back plate is a TRAY with rims, the shell sits on it
//         (the wires run inside the tray, along the rims)
// inset = previous version: flat plate fitted inside a full-height
//         shell (compatible with shells printed before the tray)
// double = DOUBLE BOTTOM for full-height shells: an LED plate (like
//         inset) resting on 3 pillars of a base; the cables run between
//         the two. Print part = back (LED plate) and part = base (base).
plate_style = "inset"; // [inset, tray, double]
// (double) Height of the double bottom for the cables
dbl_space = 8;
// (double) Fastening of the LED plate on the base pillars (the shell
// magnets pull on the plate: it must be screwed down):
// insert = M3 brass insert in the pillar + M3 x 6 screw;
// self_tap = M2.5 x 8 self-tapping screw; peg = plain pegs (not recommended)
dbl_fix = "insert"; // [insert, self_tap, peg]
// (double) Diameter of the plate holes to route the LED wires down
// into the double bottom (3 silicone 22 AWG wires: 4.2 mm)
dbl_wire_hole = 4.2;
// Height of the tray rims (tray style)
base_wall_h = 6;
// Lip on top of the rims, which centers the shell
base_lip_h = 1.5;
base_lip_w = 1.2;
// Fit clearance (back plate and stand)
tol = 0.25;
// Support ledge for the plate. Not needed with the columns (magnets or screws)
// which already stop the plate; it creates an overhang when printing.
ledge = false;
ledge_w = 1.5;
ledge_h = 1.5;
// LED mounting on the project tiles:
// strip = strip pieces glued onto the plate, between rails
// pcb   = PCB (strip pieces soldered onto it), screwed onto
//         spacers: "tuile_ruban" (project tiles) or "tuile_logo"
//         (master tile, ESP32-C3 SuperMini on the board; pointy only)
led_mount = "strip"; // [strip, pcb]
// (pcb) Spacer height: room for the JST connectors soldered
// on the back of the board (4.8 mm high) and the Skådis clip screws
pcb_standoff = 7;
// (pcb) PCB thickness
pcb_t = 1.6;
// (pcb) Pilot hole for an M2.5 x 6 self-tapping screw (PLA: 2.2 mm)
pcb_pilot = 2.2;
// Board fastening: M2.5 self-tapping screw or M2.5 brass insert + M2.5 x 6 screw
pcb_fix = "insert"; // [self_tap, insert]
// (insert) Pocket diameter: outer diameter of the insert - 0.3 mm (M2.5 x 4 x 3.5 insert)
pcb_insert_d = 3.2;
// (insert) Insert length
pcb_insert_len = 4;
// (pcb, logo tile) Height of the plastic spacer of the pin headers under
// the ESP32-C3 SuperMini (2.5 mm as standard). Used to place the USB opening.
esp_spacer = 2.5;
// (pcb, logo tile) Thickness of the ESP32-C3 SuperMini board
esp_board_t = 1.0;
// (pcb) Windows in the back plate facing the DIP switches
pcb_dip_window = false;
// LED strip width (WS2812B: usually 10 mm)
strip_w = 10;
rail_len = 56;
// Cable hole through the back (e.g. power cable coming out of the wall)
wire_hole = false;
wire_hole_d = 8;
// Keyhole for wall mounting
keyhole = true;
// Fastening of the back plate to the shell (3 points, 4 for the master)
screws = true;
// magnet = 6x3 magnets (shell swappable without tools)
// insert = M3 screw + brass insert; self_tap = M2.5 self-tapping screw
screw_type = "magnet"; // [magnet, insert, self_tap]
// (insert) Hole diameter: ~ outer diameter of the insert - 0.5 mm
insert_d = 3.6;     // Corgi kit M3 x 5 x 4: 4 - 0.4
// (insert) Insert length
insert_len = 5;
// (insert) Screw clearance hole in the plate (M3: 3.4)
insert_screw_clear = 3.4;
// Pilot hole diameter in the column (M2.5 in PLA: 2.2)
screw_pilot = 2.2;
// Clearance hole diameter in the plate
screw_clear = 2.9;
screw_boss_d = 6;

/* [Master tile (ESP32)] */
// Board: c3 = ESP32-C3 Super Mini (in the corner, diagonally)
//         d1mini = Wemos D1 mini: flat in the center, USB on the left,
//         LED strip on a bridge above it (part = led_bridge)
esp_board = "c3"; // [c3, d1mini]
// Number of LEDs on the central strip of the logo tile
master_leds = 3; // [3, 4, 5]
// Tile that holds the ESP32-C3 Super Mini and takes the USB-C
master = false;
// Board dimensions (ESP32-C3 Super Mini: 18 x 22.5 mm)
esp_w = 18.2;
esp_l = 22.7;
// Cutout for the USB-C plug (width x height)
usb_w = 13;
usb_h = 8.5;

/* [Desk stand (pointy orientation)] */
// Number of tiles side by side on the stand
stand_tiles = 2;
// Backward tilt (degrees)
tilt = 12;
// Material under the tile points
stand_floor = 6;
// Height of the lips above the point
lip_h = 10;
lip = 3;
// USB cable passage for the master tile, placed far left
stand_usb = true;
// Front and back extension of the footprint (stability)
stand_front = 6;
stand_back = 15;

/* [IKEA Skådis adapter] */
// Skådis mounting of the back plate (tile >= 80 mm):
// clips = 2 slots + our clips inserted from the inside
// tclip = receivers for LineArcLine's "Skadis T-Clip System"
//         (2 one above the other; only 1 on the master tile;
//          no keyhole). Clips available for download on Printables.
skadis_mount = "clips"; // [clips, tclip, none]
skadis_slots = (skadis_mount == "clips");
// Skådis clip type (part = skadis_clips):
// snap = simple clip with flexible prongs: push it in, click, it holds
// twist = quarter-turn clip
skadis_clip_type = "snap"; // [snap, twist]
// Skådis clip width (slot: 5 mm; 4.2 to 4.4 recommended)
skadis_hook_w = 4.4;
// (snap) Thickness of the flexible arms: thinner = easier to snap in
snap_arm_t = 1.2;
// (snap) Overhang of the hooks behind the pegboard
snap_barb = 0.7;
// ACTUAL thickness of the Skådis pegboard (measure it with calipers)
skadis_board = 5.0;

/* [Cable clips] */
// Small clips to glue onto the plate to hold the wires (part = cable_clips)
cable_clip_count = 8;
// Clip opening (2 silicone 22 AWG wires: 4 mm)
cable_clip_gap = 4;
cable_clip_h = 3.5;

/* [Export] */
// letters = letters only, for the dark_face style (same origin as tile)
// skadis_clips = 2 clips going through plate + pegboard (recommended)
// skadis = old screw-on adapter (hangs by the keyhole)
// knockout_test = test piece to choose the knockout skin thickness
part = "both"; // [tile, letters, back, both, stand, plugs, skadis_clips, skadis, links, link_test, led_bridge, base, cable_clips, knockout_test]

/* [Hidden] */
bb_version = "1.2";
echo(str("BuildBeacon model v", bb_version));
$fn = 48;
eps = 0.01;
pointy = (orientation == "pointy");
hex_rot = pointy ? 30 : 0;      // outline rotation
side_off = pointy ? 0 : 30;     // angle of the middle of side 0
apothem = flat / 2;
R_hex = flat / sqrt(3);
inner_flat = flat - 2 * wall;
r_in = max(corner_r - wall, 0.5);
boss_d = mag_d + 3;
boss_len = mag_h + 1.2;
mag_offsets = side_magnets == 2 ? [-mag_spread, mag_spread] : [0];
// USB exit side: in pointy, the slanted side at the bottom LEFT seen from
// the front (side 5 of the model, which is mirrored): the strip stays centered
// and the cable exits toward the outside of the row. In flat: at the bottom.
d1 = master && pointy && esp_board == "d1mini";
eW = d1 ? 25.8 : esp_w;
eL = d1 ? 34.5 : esp_l;
USB_SIDE = pointy ? (d1 ? 0 : 5) : 4;
usb_angle = side_off + 60 * USB_SIDE;
// The plate is flipped when installed (Y inverted): the angle is inverted
cradle_angle = -usb_angle;
// Corners (vertices) used for the screw columns: every other one
vertex_off = pointy ? 30 : 0;
use_insert = (screw_type == "insert");
use_magnet = (screw_type == "magnet");
// Column thick enough to keep ~1.2 to 1.7 mm of material around
column_d = use_magnet ? max(screw_boss_d, mag_d + 2.4)
         : use_insert ? max(screw_boss_d, insert_d + 3.5)
         : screw_boss_d;
// Set back from the plate ledge (otherwise the boss touches the ledge)
screw_r = (inner_flat - 2 * ledge_w) / sqrt(3) - column_d / 2 - 0.8;
// Magnet mode: the column stops lower, the plate carries a
// boss with its own magnet that comes into contact.
// Height of the magnet bosses on the inner side of the plate (magnet
// inserted from the back + 0.4 mm skin)
plate_boss_h = max(0.6, mag_h + 0.4 - back_t);
col_top = use_magnet ? depth - back_t - plate_boss_h : depth - back_t;
// Corners of the screw/magnet columns: every other corner, in a balanced
// triangle, identical for all tiles (master included).
// Checked at 80 mm with ESP32-C3 and D1 mini: the boss next to the USB
// clears the cradle. Below 80 mm, check in the preview.
screw_angles = [for (k = [0 : 2]) vertex_off + 120 * k];
// Magnets: halfway between front and notches, unless set manually
// Shell height (front + walls): it sits on the tray rims
tray = (plate_style == "tray");
dbl = (plate_style == "double");
hc = tray ? depth - back_t - base_wall_h : depth;
mag_zz = mag_z > 0 ? mag_z : (tray ? hc : depth - back_t - notch_h) - boss_d / 2 - 0.5;
// Inner radius of the back plate (vertex)
plate_R = (inner_flat - 2 * tol) / sqrt(3);
// Positions proportional to the tile size
// (positions checked for flat from 65 to 100 mm, regular and master tile)
// Skådis slots in the plate: 40 mm apart (Skådis pitch), placed
// in the upper half of the tile, away from the ESP32 cradle.
// In flat with the ambient LEDs, there is no room left for the keyhole:
// the 2 slots are then also used to screw the plate to the wall.
slot_on = skadis_slots || (!pointy && dots && skadis_mount != "tclip");
slot_x = 20;
slot_h = 15.2;          // lets the foot of the quarter-turn clip through (14.8 mm)
slot_w = skadis_hook_w + 0.8;
// above the rails of the central strip, leaving room for the head
// of the clip (3 mm below the slot); away from the plate links
slot_cy = -(strip_w / 2 + 1.4 + 2.6 + slot_h / 2);
// T-Clip receivers: on the vertical axis, at +/-20 mm (Skådis slots of the
// same column). Plate -Y = top of the tile. Master tile: only
// the top one (the bottom one would land on the ESP32).
tclip_on = pointy && skadis_mount == "tclip";
// (shifted 0.5 mm up to clear the bottom magnet column;
//  the spacing stays 40 mm)
tclip_pos = master ? [[0, -20.5]] : [[0, -20.5], [0, 19.5]];
// Dots and ambient LEDs (pointy and flat; not with T-Clips)
amb_on = dots && !tclip_on;
dots_on = amb_on && !master;
// PCB (led_mount = pcb). Logo tile: only in pointy with
// the ESP32-C3 (the board places the module slanted toward USB side 5)
pcb_on = (led_mount == "pcb") && pointy && !d1;
// The strip is raised by the spacer + the board thickness
lift = pcb_on ? pcb_standoff + pcb_t : 0;
// Board holes and outline, in FRONT VIEW (mm, y up).
// The plate is flipped inside the shell: front view (x, y) = plate (-x, -y).
pcb_holes_front = master
    ? [[0, 23], [20, -12], [-15.5, -26.85], [-20, -10]]
    : [[0, 23], [-20, -12], [20, -12], [0, -27]];
// hexagonal boards (6 JST connectors, one per side; board vertices
// toward the middle of the tile sides, between the magnet columns)
// Board shaped like the plate (1 mm in from the walls), with a
// U-shaped notch around each of the 3 magnet columns (pointy tile)
pcb_outline_front = [[37.00, 14.90], [34.84, 13.65], [33.49, 13.09], [32.04, 12.90], [30.59, 13.09], [29.24, 13.65], [28.08, 14.54], [27.19, 15.70], [26.63, 17.05], [26.44, 18.50], [26.63, 19.95], [27.19, 21.30], [28.08, 22.46], [29.24, 23.35], [31.40, 24.60], [2.60, 41.22], [-2.60, 41.22], [-31.40, 24.60], [-29.24, 23.35], [-28.08, 22.46], [-27.19, 21.30], [-26.63, 19.95], [-26.44, 18.50], [-26.63, 17.05], [-27.19, 15.70], [-28.08, 14.54], [-29.24, 13.65], [-30.59, 13.09], [-32.04, 12.90], [-33.49, 13.09], [-34.84, 13.65], [-37.00, 14.90], [-37.00, -18.36], [-34.40, -22.86], [-5.60, -39.49], [-5.60, -37.00], [-5.41, -35.55], [-4.85, -34.20], [-3.96, -33.04], [-2.80, -32.15], [-1.45, -31.59], [-0.00, -31.40], [1.45, -31.59], [2.80, -32.15], [3.96, -33.04], [4.85, -34.20], [5.41, -35.55], [5.60, -37.00], [5.60, -39.49], [34.40, -22.86], [37.00, -18.36]];
// Access windows for the DIP switches (soldered on the back of the board):
// x of the switch columns in front view (IN on the left, OUT on the right)
pcb_dip_x_front = master ? [6.5] : [-6.5, 6.5];
// (pcb) Windows in the plate to flip the switches with a
// pointed tool, with the tile taken off the wall
pcb_holes = [for (h = pcb_holes_front) [-h[0], -h[1]]];
pcb_outline = [for (q = pcb_outline_front) [-q[0], -q[1]]];
// Logo tile on a PCB: the module is raised, the USB goes through a
// closed WINDOW in the wall (no longer a slot open toward the back).
// Height of the USB-C socket center from the back edge of the shell:
usb_from_back = back_t + pcb_standoff + pcb_t + esp_spacer + esp_board_t + 1.6;
usb_win_z0 = max(face + 1.2, depth - usb_from_back - usb_h / 2);   // front side
usb_win_z1 = depth - usb_from_back + usb_h / 2;                    // back side
// Boxes: strip width + clearance; height up to the strip
cell_y = strip_w + 2 * 0.4;
rib_h_in = depth - back_t - face - 0.6 - rib_gap - lift;     // between the LEDs, down to the strip PCB
rib_h_out = depth - back_t - face - 1.5 - rib_gap - lift;    // above the rails
// Wire holes and grooves (plate coordinates; -Y = top of the
// tile). Chain: top (input) -> dots -> bottom (output).
dot_half = dots_n * dots_pitch / 2;            // 25 mm for 5 LEDs
amb_half = amb_leds * dots_pitch / 2;          // 10 mm for 2 LEDs
wp_on = wire_paths && dots_on;
wire_holes = [[-(amb_half + 1.5), -amb_offset], [amb_half + 1.5, -amb_offset],
              [dot_half + 1.5, 0], [-(dot_half + 1.5), 0],
              [-(amb_half + 1.5), amb_offset], [amb_half + 1.5, amb_offset]];
wire_grooves = [
    [[amb_half + 1.5, -amb_offset], [amb_half + 1.5, -2], [dot_half + 1.5, -2], [dot_half + 1.5, 0]],
    [[-(dot_half + 1.5), 0], [-(dot_half + 1.5), 2], [-(amb_half + 1.5), 2], [-(amb_half + 1.5), amb_offset]]
];
// (double) Base pillars: on the 3 corners without a magnet, 33 mm from the center
pillars = [for (k = [0 : 2]) [33 * cos(-(vertex_off + 60 + 120 * k)),
                               33 * sin(-(vertex_off + 60 + 120 * k))]];
// (double) Plate holes to route the wires down into the double bottom
dbl_holes = master ? [[master_leds * dots_pitch / 2 + 1.5, 0], [-(master_leds * dots_pitch / 2 + 1.5), 0]]
                   : (dots_on ? wire_holes : [[dot_half + 1.5, 0], [-(dot_half + 1.5), 0]]);
// Centered keyhole, at the top of the tile once mounted
key_x = 0;
// (flat: below the dog bone pocket of the top side)
key_y = pointy ? -(plate_R - 12.5) : -0.225 * flat;
wire_x = pointy ? 0.25 * flat : 0;
wire_y = pointy ? 0.22 * flat : 0.25 * flat;

// ---------------------------------------------------------------------

module hex2d(f, r) {
    rotate(hex_rot)
        offset(r = r) offset(delta = -r) circle(r = f / sqrt(3), $fn = 6);
}

// Places the child at the middle of side k (local X axis = outward normal)
module side(k) {
    rotate([0, 0, side_off + 60 * k]) children();
}

module label2d() {
    // Mirrored: the text reads correctly when seen from the front
    ts = text_size > 0 ? text_size : (border ? 0.12 : 0.14) * flat;
    // with the dot row (on the LED axis), the name moves up a bit:
    // the bottom of the name (descenders included) stays above the boxes
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

// Border: hexagonal outline set in from the edge. In stencil style, it is
// cut at the 6 vertices so that the center of the front stays attached.
module border2d() {
    difference() {
        hex2d(flat - 2 * border_inset, max(corner_r - border_inset, 0.5));
        hex2d(flat - 2 * (border_inset + border_w), 0.5);
        if (style == "stencil")
            for (k = [0 : 5]) rotate(hex_rot + 60 * k)
                translate([flat / 2, 0]) square([flat, 2], center = true);
    }
}

// Dot row, centered on the LED strip axis (Y = 0)
module dots2d() {
    for (i = [0 : dots_n - 1])
        translate([(i - (dots_n - 1) / 2) * dots_pitch, 0])
            circle(d = dots_d);
}

// Built-in logo: a beacon emitting waves (no islands: compatible
// with all styles, including stencil)
module beacon_logo2d() {
    sc = logo_size / 34;
    scale(sc) translate([0, -8]) {
        circle(d = 6);                                  // the beacon
        translate([-1.2, -12]) square([2.4, 12]);       // its mast
        translate([-6, -13.2]) square([12, 2.4]);       // its foot
        for (r = [10, 16])                              // the waves
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

// Everything that lights up on the front
module art2d() {
    if (master && master_logo) logo2d(); else label2d();
    if (border) border2d();
    if (dots_on) dots2d();
}

// Boxes closed on 4 sides around the dots, from the front up to the
// strip. Walls between LEDs: go down onto the strip PCB, between
// two LEDs. Top/bottom walls and ends: stop above the rails.
module dot_ribs3d() {
    w = dots_n * dots_pitch;
    ex = 2.6;                            // ends spread apart: solder joints and wires
    translate([0, 0, face - eps]) {
        for (i = [0 : dots_n]) {
            x = (i - dots_n / 2) * dots_pitch - rib_t / 2
                + (i == 0 ? -ex : (i == dots_n ? ex : 0));
            inner = (i > 0 && i < dots_n);
            // central part (over the strip)
            translate([x, -strip_w / 2 + 0.2, 0])
                cube([rib_t, strip_w - 0.4, inner ? rib_h_in : rib_h_out]);
            // junction with the top/bottom walls
            translate([x, -cell_y / 2 - rib_t / 2, 0])
                cube([rib_t, cell_y + rib_t, rib_h_out]);
        }
        for (s = [-1, 1])
            translate([-w / 2 - ex - rib_t / 2, s * cell_y / 2 - rib_t / 2, 0])
                cube([w + 2 * ex + rib_t, rib_t, rib_h_out]);
    }
}

// ----------------------------- Tile ----------------------------------

module boss() {
    // Magnet boss with a 45° slope to print without supports
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

// With the PCB, the connectors on the right and left sides (front
// view) are raised by 8 mm (room for the dot strip): so are their notches.
// Model sides (mirrored from the front view): 0 = left, 3 = right.
function notch_shift(k) = 0;   // connectors centered on each side

module notch() {
    // in knockout mode, stop before the outer face
    nl = notch_knockout ? wall + ledge_w + 1 - knockout_skin
                        : wall + ledge_w + 2;
    translate([apothem - wall - ledge_w - 1, -notch_w / 2,
               depth - back_t - notch_h])
        cube([nl, notch_w, notch_h + back_t + eps]);
}

module usb_cut() {
    if (pcb_on && master)
        // closed window, centered on the module's socket
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

// Screw column in a corner, from the front up to the ledge,
// joined to the wall (printable without supports).
// The column only touches the front against the wall: it starts
// higher with a slope toward the corner, so as not to cast a shadow
// on the border (printable without supports).
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
                    // magnet pocket at the top of the column
                    translate([0, 0, col_top - mag_h])
                        cylinder(d = mag_d, h = mag_h + 1);
                } else if (use_insert) {
                    // insert pocket, open on the plate side
                    translate([0, 0, depth - back_t - insert_len - 0.5])
                        cylinder(d = insert_d, h = insert_len + 1);
                    // clearance for the screw tip
                    translate([0, 0, depth - back_t - insert_len - 4.5])
                        cylinder(d = 2.6, h = 4.5);
                } else {
                    pz = max(face + 0.8, depth - back_t - 12);
                    translate([0, 0, pz])
                        cylinder(d = screw_pilot, h = depth - pz + 1);
                }
            }
        if (style == "glow")
            // Text thinned from the inside
            translate([0, 0, text_skin])
                linear_extrude(face - text_skin + eps) art2d();
        else if (style == "swap")
            // Letters recessed into the front, through the black layer
            translate([0, 0, -eps])
                linear_extrude(swap_z + eps) art2d();
        else
            // Through-cut text: filled by the "letters" part
            translate([0, 0, -eps])
                linear_extrude(face + 2 * eps) art2d();
        if (magnets) for (k = [0 : 5], t = mag_offsets)
            if (!(master && k == USB_SIDE)) side(k) translate([0, t, 0]) magnet_pocket();
        // notches in the shell: only in inset (in tray and double,
        // they are in the tray / the base)
        if (notches && plate_style == "inset") for (k = notch_sides)
            side(k) translate([0, notch_shift(k), 0]) notch();
        if (master) side(USB_SIDE) usb_cut();
    }
}

// ------------------------- Back plate --------------------------------

// PCB spacer: flared base (sturdy, no supports) and
// pilot hole for an M2.5 self-tapping screw
module pcb_standoff3d() {
    ins = (pcb_fix == "insert");
    dd = ins ? pcb_insert_d + 3 : 5.5;            // wall of at least 1.5 mm around the insert
    difference() {
        union() {
            cylinder(d = dd, h = pcb_standoff + eps);
            cylinder(d1 = dd + 2.5, d2 = dd, h = 1.5);
        }
        if (ins) {
            // insert pocket (open at the top) + clearance for the screw tip
            translate([0, 0, pcb_standoff - pcb_insert_len - 0.3]) cylinder(d = pcb_insert_d, h = pcb_insert_len + 1);
            translate([0, 0, 0.8]) cylinder(d = 2.7, h = pcb_standoff);
        } else
            translate([0, 0, 0.8]) cylinder(d = pcb_pilot, h = pcb_standoff);
    }
}

// PCB silhouette (preview only)
module pcb2d() {
    difference() {
        polygon(pcb_outline);
        for (h = pcb_holes) translate(h) circle(d = 2.7);
    }
}

module back_plate() {
    rail_w = 1.2;
    rail_h = 1.5;
    half = strip_w / 2 + 0.2 + rail_w;          // half-width of the LED channel
    // --- flat orientation: strip perpendicular to the cradle (as before)
    y_back = inner_flat / 2 - ledge_w - 0.5 - esp_l - 1.2;
    r_off_flat = master ? min(0, y_back - 1 - half) : 0;
    rl_flat = min(rail_len,
             2 * (plate_R - (half + abs(r_off_flat)) * tan(30) - 2),
             screws ? 2 * (screw_r - column_d / 2 - 1) : 1000);
    // --- pointy orientation: strip horizontal and centered, along the
    // text. The master tile's ESP32 is diagonal, clear of the strip.
    r_off_pt = 0;
    rl_pt = min(rail_len, 2 * (inner_flat / 2 - tol - 2));
    rail_rot = pointy ? 0 : cradle_angle - 90;
    r_off = pointy ? r_off_pt : r_off_flat;
    // logo tile: rails as long as its strip (master_leds)
    rl = min(pointy ? rl_pt : rl_flat, master ? master_leds * dots_pitch + 6 : 1000);
    difference() {
        union() {
            if (tray) {
                // tray bottom, at the outer size of the tile
                linear_extrude(back_t) hex2d(flat, corner_r);
                // tray rims
                translate([0, 0, back_t - eps]) linear_extrude(base_wall_h + eps)
                    difference() { hex2d(flat, corner_r); hex2d(inner_flat, r_in); }
                // centering lip (fits into the shell)
                translate([0, 0, back_t + base_wall_h - eps]) linear_extrude(base_lip_h + eps)
                    difference() {
                        hex2d(inner_flat - 2 * tol, r_in);
                        hex2d(inner_flat - 2 * tol - 2 * base_lip_w, max(r_in - base_lip_w, 0.5));
                    }
            } else {
                // old flat plate, fitted inside the shell
                linear_extrude(back_t) hex2d(inner_flat - 2 * tol, r_in);
            }
            // PCB: 3 spacers instead of the rails
            if (pcb_on) for (h = pcb_holes)
                translate([h[0], h[1], back_t - eps]) pcb_standoff3d();
            // LED strip guide rails (not with D1 mini: strip on the bridge)
            if (!d1 && !pcb_on) rotate([0, 0, rail_rot])
                for (s = [-1, 1])
                    translate([-rl / 2,
                               r_off + s * (strip_w / 2 + 0.2 + rail_w / 2) - rail_w / 2,
                               back_t - eps])
                        cube([rl, rail_w, rail_h]);
            // Ambient LED rails (plate -Y = top of the tile):
            // at the top on all tiles, at the bottom except on the master
            if (amb_on && (!master || master_amb) && !pcb_on)
                for (ay = master ? [-amb_offset] : [-amb_offset, amb_offset])
                    for (s = [-1, 1])
                        translate([-(amb_leds * dots_pitch + 2) / 2,
                                   ay + s * (strip_w / 2 + 0.2 + rail_w / 2) - rail_w / 2,
                                   back_t - eps])
                            cube([amb_leds * dots_pitch + 2, rail_w, rail_h]);
        }
        // Windows for the board's DIP switches (front view x -> plate -x)
        if (pcb_on && pcb_dip_window) for (dx = pcb_dip_x_front)
            translate([-dx - 3.6, -8.6, -1]) cube([7.2, 17.2, back_t + 2]);   // DIP 6.7 x 16.8 mm
        // Optional wire hole (non-master tiles)
        if (wire_hole && !master)
            translate([wire_x, wire_y, -eps]) cylinder(d = wire_hole_d, h = back_t + 1);
        // Magnet pockets open on the back side of the plate, with an
        // entry chamfer (this face is on the build plate: the squished first
        // layer narrows the hole entrance)
        if (screws && use_magnet && plate_mag_side == "back") for (a = screw_angles)
            rotate(-a) translate([screw_r, 0, -eps]) {
                cylinder(d = mag_d, h = mag_h + eps);
                cylinder(d1 = mag_d + 1, d2 = mag_d, h = 0.5);
            }
        // Magnet pockets open on the top (0.4 mm floor)
        if (screws && use_magnet && plate_mag_side == "top") for (a = screw_angles)
            rotate(-a) translate([screw_r, 0, back_t + plate_boss_h - mag_h])
                cylinder(d = mag_d, h = mag_h + 1);
        // Screw holes (mirrored positions: the plate is flipped)
        if (screws && !use_magnet) for (a = screw_angles)
            rotate(-a)
                translate([screw_r, 0, -eps])
                    cylinder(d = use_insert ? insert_screw_clear : screw_clear,
                             h = back_t + 1);
        // Wire holes and grooves (on the back of the plate)
        // (double) holes for the pillar pegs + wire pass-through holes
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
        // Rim notches (cables and dog bones), open at the top,
        // knockout; the shell closes them when it is put in place
        if (tray && notches) for (k = notch_sides)
            if (!(master && k == USB_SIDE))
                rotate(-(side_off + 60 * k)) {
                    nl = notch_knockout ? wall + 1 - knockout_skin : wall + 2;
                    translate([inner_flat / 2 - 1, -notch_w / 2, back_t])
                        cube([nl, notch_w, base_wall_h + base_lip_h + 1]);
                }
        // USB opening of the master tile in the rim
        if (tray && master) rotate(-usb_angle)
            translate([inner_flat / 2 - 1, -usb_w / 2, back_t])
                cube([wall + 2, usb_w, base_wall_h + base_lip_h + 1]);
        // Dog bone pockets (link with the neighboring plates),
        // in the middle of each side; not on the USB side of the master tile
        if (plate_links && !dbl) for (k = [0 : 5])
            if (!(master && k == USB_SIDE))
                rotate(-(side_off + 60 * k)) link_pocket3d(back_t);
        // Oblong slot of the T-Clip receivers, through the plate
        if (tclip_on) for (p = tclip_pos)
            translate([p[0], p[1], -1]) hull()
                for (s = [-1, 1]) translate([0, s * (15.2 - 5.2) / 2, 0])
                    cylinder(d = 5.2, h = back_t + 2);
        // Holes for the LED bridge legs (D1 mini)
        if (d1) for (p = bridge_legs)
            translate([p[0], p[1], -1]) cylinder(d = 3.1, h = back_t + 2);
        // Skådis slots (D1 mini: only on the left, the board takes the right)
        if (slot_on && !dbl) for (sx = d1 ? [-slot_x] : [-slot_x, slot_x])
            translate([sx - slot_w / 2, slot_cy - slot_h / 2, -eps])
                cube([slot_w, slot_h, back_t + 1]);
        // Keyhole: narrow end of the slot toward -Y of the plate,
        // which becomes the top once the plate is flipped and mounted.
        // (removed with T-Clips: it would land on the top receiver)
        if (keyhole && !tclip_on && !dbl && (pointy || !amb_on)) {
            translate([key_x, key_y, -eps]) cylinder(d = 8, h = back_t + 1);
            hull() {
                translate([key_x, key_y, -eps]) cylinder(d = 4, h = back_t + 1);
                translate([key_x, key_y - 7, -eps]) cylinder(d = 4, h = back_t + 1);
            }
        }
    }
    // ESP32 cradle (not with the PCB: the module is soldered onto it)
    if (master && !pcb_on) rotate([0, 0, cradle_angle - 90]) esp_cradle();
    if (tclip_on) for (p = tclip_pos) translate([p[0], p[1], 0]) tclip_receiver();
    // Magnet mode: low bosses facing the columns. The magnet is inserted from
    // the BACK of the plate; a 0.4 mm skin on the shell side holds it
    // (the attraction presses it against the skin).
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

// T-Clip receiver (dimensions measured on the sample part of the "Skadis
// T-Clip System"): 5.2 x 15.2 mm oblong slot, 2.5 mm deep on the pegboard side,
// then a cone from 16.4 to 21.4 mm up to 5.4 mm total thickness.
// The clip is inserted from the inside (shell removed) and given a 1/4
// turn: its 28 mm bar sweeps a ~29 mm circle above.
tclip_total = 5.4;
module tclip_receiver() {
    difference() {
        // boss on the inner side, to reach 5.4 mm thickness
        translate([0, 0, back_t - eps])
            cylinder(d = 24, h = tclip_total - back_t + eps);
        // vertical oblong slot (along the plate's Y axis)
        translate([0, 0, -1]) hull()
            for (s = [-1, 1]) translate([0, s * (15.2 - 5.2) / 2, 0])
                cylinder(d = 5.2, h = 3.5 + 1);
        // bearing cone for the clip flanks
        translate([0, 0, 2.5])
            cylinder(r1 = 8.2, r2 = 10.7, h = tclip_total - 2.5 + eps);
    }
}

// LED bridge (D1 mini): 52 x 35 deck on 4 legs of 6 mm, sitting above
// the board. The 5-LED strip is glued into the groove, LEDs facing the
// front. Printed LED side down on the build plate, legs up.
bridge_legs = [[-23.5, -4], [23.5, -16.5], [-23.5, 16.5], [23.5, 16.5]];
bridge_h = 6;      // height under the deck (D1 mini without pin headers: ~5 mm)
bridge_t = 2;
module led_bridge() {
    difference() {
        translate([-26, -17.7, 0]) cube([52, 35.4, bridge_t]);
        // strip groove, 0.6 mm, LED side (on the build plate)
        translate([-26 - 1, -(strip_w + 0.4) / 2, -1]) cube([54, strip_w + 0.4, 1.6]);
    }
    for (p = bridge_legs) translate([p[0], p[1], 0]) {
        translate([-1.2, -1.2, bridge_t - eps]) cube([2.4, 2.4, bridge_h]);
        // peg that fits into the plate
        translate([0, 0, bridge_t + bridge_h - eps]) cylinder(d = 2.8, h = back_t);
    }
}

// DOUBLE BOTTOM base (plate_style = double). Printed bottom down on the build plate.
// Bottom at the tile size + dbl_space-high rims (the shell sits
// on them) + 3 pegged pillars that carry the LED plate. The wall
// mounting features are here: Skådis slots, keyhole, dog bones.
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
        // fastening pockets at the top of the pillars
        for (q = pillars) translate([q[0], q[1], 0]) {
            if (dbl_fix == "insert") {
                translate([0, 0, back_t + H - insert_len - 0.5])
                    cylinder(d = insert_d, h = insert_len + 1);
                translate([0, 0, back_t + H - insert_len - 3.5]) cylinder(d = 2.6, h = 3.1);
            }
            if (dbl_fix == "self_tap")
                translate([0, 0, back_t + 0.8]) cylinder(d = screw_pilot, h = H + 1);
        }
        // knockout notches in the rims (JST cables, dog bones)
        if (notches) for (k = notch_sides)
            rotate(-(side_off + 60 * k)) {
                nl = notch_knockout ? wall + 1 - knockout_skin : wall + 2;
                translate([inner_flat / 2 - 1, -notch_w / 2, back_t])
                    cube([nl, notch_w, H + 1]);
            }
        // dog bones
        if (plate_links) for (k = [0 : 5])
            rotate(-(side_off + 60 * k)) link_pocket3d(back_t);
        // Skådis slots
        if (skadis_mount == "clips") for (sx = [-slot_x, slot_x])
            translate([sx - slot_w / 2, slot_cy - slot_h / 2, -1])
                cube([slot_w, slot_h, back_t + 2]);
        // keyhole (above the tile center)
        if (keyhole) {
            translate([0, -12, -1]) cylinder(d = 8, h = back_t + 2);
            hull() for (y = [-12, -19]) translate([0, y, -1]) cylinder(d = 4, h = back_t + 2);
        }
    }
}

// Dog bone: 2 round heads joined by a neck that spans the gap
// between two plates (2 shell walls + clearance = 4.5 mm at 80 mm).
link_head_r = 3.5;
link_neck_w = 6;
link_in = 5;          // head to plate edge distance
link_clr = 0.15;      // clearance in the pockets
link_gap = 2 * (wall + tol);
module link2d() {
    c = link_in + link_gap / 2;
    for (s = [-1, 1]) translate([s * c, 0]) circle(r = link_head_r);
    translate([-c, -link_neck_w / 2]) square([2 * c, link_neck_w]);
}
// Dog bone pocket with a chamfer on the build plate side
// (compensates for the squished first layer, "elephant's foot")
module link_pocket3d(h) {
    translate([0, 0, -1]) linear_extrude(h + 2) link_pocket2d();
    translate([0, 0, -eps]) linear_extrude(0.25 + eps) offset(delta = 0.5) link_pocket2d();
    translate([0, 0, 0.25 - eps]) linear_extrude(0.25 + eps) offset(delta = 0.25) link_pocket2d();
}

// Dog bone with chamfered edges (bottom: elephant's foot;
// top: easier insertion)
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

// ESP32 cradle (built toward +Y then rotated toward the USB side).
// Once the plate is flipped and mounted, the USB-C port faces
// the tile opening.
module esp_cradle() {
    g = 1.2;          // guide thickness
    gh = 2.5;         // guide height
    y_port = inner_flat / 2 - ledge_w - 0.5;   // USB-side edge
    y_back = y_port - eL;
    // Narrow end stop and guides starting 3 mm further: diagonally,
    // the cradle corners thus stay clear of the LED strip.
    translate([0, 0, back_t - eps]) {
        // rear end stop (the cable pushes the board against it)
        translate([-5, y_back - g, 0]) cube([10, g, gh]);
        // side guides, open on the USB side
        for (s = [-1, 1])
            translate([s > 0 ? eW / 2 : -eW / 2 - g, y_back + 3, 0])
                cube([g, eL * 0.6 - 3, gh]);
    }
}

// ------------------------- Desk stand --------------------------------
// Bar with one V-notch per tile (pointy orientation).
// Axes: X = length, Y = toward the back, Z = up.
// The master tile goes on the left: its USB exits through the side.

module tilted() {
    lift = (depth + 2 * tol + lip) * sin(tilt);
    translate([0, 0, lift]) rotate([-tilt, 0, 0]) children();
}

module stand() {
    D = depth + 2 * tol;
    L = stand_tiles * flat;
    h = stand_floor + lip_h;
    lift = (D + lip) * sin(tilt);
    // block height = highest point of the tilted lips
    top = lift + h * cos(tilt) + lip * sin(tilt);
    difference() {
        // straight block, vertical faces
        translate([-L / 2, -stand_front, 0])
            cube([L, stand_front + D + stand_back, top]);
        // one V-notch (tile outline + clearance) per tile
        for (i = [0 : stand_tiles - 1])
            tilted()
                translate([(i - (stand_tiles - 1) / 2) * flat, 0,
                           stand_floor + R_hex])
                    rotate([-90, 0, 0])
                        linear_extrude(D)
                            offset(delta = tol) hex2d(flat, corner_r);
        // passage for the master tile's USB plug (left tile,
        // slanted bottom-left side seen from the front, toward the back)
        if (stand_usb && pointy && esp_board != "d1mini")
            tilted()
                translate([-(stand_tiles - 1) / 2 * flat, 0, stand_floor + R_hex])
                    rotate([0, 120, 0])
                        translate([apothem - wall - 1, depth - usb_h - 1,
                                   -(usb_w + 4) / 2])
                            cube([40, 100, usb_w + 4]);
        // everything that goes below the desk
        translate([-500, -100, -100]) cube([1000, 300, 100]);
    }
}

// ---------------------------------------------------------------------

// Letters only (dark_face style): load together with the tile as
// a single multi-part object in the slicer.
module letters() {
    linear_extrude(face) art2d();
}

// Notch plug: fills the wall and the ledge cutout.
// Printed standing up, outer face (Y = 0) flush with the tile.
// The back plate rests on its "ledge" part.
module plug() {
    w = notch_w - 2 * tol;
    h = notch_h + back_t;
    cube([w, wall, h]);
    translate([0, wall - eps, notch_h - ledge_h]) cube([w, ledge_w, ledge_h]);
}

// Skådis adapter: 2 hooks on the back (slots 40 mm apart
// in the same row), an M3 brass insert at the front. An M3 screw left
// sticking out by ~3 mm acts as a "nail" for the tile's keyhole.
// Printed as is, bottom face on the build plate, no supports.
// Axes: X = width, Y = toward the tile (Y < 0 = behind the pegboard),
// Z = vertical.
module skadis_adapter() {
    hw = skadis_hook_w / 2;
    difference() {
        union() {
            // bar
            translate([-24, 0, 0]) cube([48, 6, 14]);
            for (sx = [-20, 20]) translate([sx - hw, 0, 0]) {
                // stem going through the slot (rests at the bottom of the slot)
                translate([0, -skadis_board, 6]) cube([2 * hw, skadis_board + eps, 6]);
                // tab hanging down behind the pegboard
                translate([0, -skadis_board - 2, 0]) cube([2 * hw, 2, 12]);
            }
        }
        // insert pocket, open toward the tile
        translate([0, -1, 7]) rotate([-90, 0, 0])
            cylinder(d = insert_d, h = 8);
    }
}

if (part == "skadis") skadis_adapter();

if (part == "led_bridge") led_bridge();

// Cable clip: a U on a base plate, with 2 tabs that hold the
// wires. Glue onto the plate (CA glue or double-sided tape).
module cable_clip() {
    w = cable_clip_gap + 2 * 1.2;
    cube([w, 7, 1]);
    for (sx = [0, w - 1.2]) translate([sx, 0, 1 - eps]) cube([1.2, 7, cable_clip_h]);
    // tabs
    for (sg = [0, 1])
        translate([sg == 0 ? 1.2 - eps : w - 1.2 - 0.4 + eps, 0, 1 + cable_clip_h - 0.8])
            cube([0.4, 7, 0.8]);
}
if (part == "cable_clips")
    for (i = [0 : cable_clip_count - 1])
        translate([(i % 4) * (cable_clip_gap + 6), floor(i / 4) * 10, 0]) cable_clip();
if (part == "base") {
    if (!dbl) echo("WARNING: part = base is only for plate_style = double");
    dbl_base();
}

if (part == "links")
    for (i = [0 : link_count - 1])
        translate([0, i * (2 * link_head_r + 3), 0])
            link3d();

// Fit test piece: 4 bones (0.05 / 0.10 / 0.15 / 0.20 mm),
// identified by 1 to 4 notches on the neck. Keep the one that goes in
// with slight force, then copy its value into link_fit.
if (part == "link_test")
    for (i = [0 : 3])
        translate([0, i * (2 * link_head_r + 4), 0])
            difference() {
                link3d(0.05 * (i + 1));
                for (j = [0 : i])
                    translate([(j - i / 2) * 1.6 - 0.3, link_neck_w / 2 - 0.6 + 0.05 * (i + 1), back_t - 0.5])
                        cube([0.6, 1, 1]);
            }

// Test piece: 4 knockout notches (0.4 / 0.6 / 0.8 / 1.0 mm skin),
// same wall and same notch as the tile. Printed standing up, like the tile.
module knockout_test() {
    skins = [0.4, 0.6, 0.8, 1.0];
    pitch = notch_w + 6;
    h = notch_h + back_t + 4;
    difference() {
        cube([pitch * len(skins) + 2, wall, h]);
        for (i = [0 : len(skins) - 1]) {
            // notch open at the top, skin on the Y = 0 side (outside)
            translate([3 + i * pitch, skins[i], h - notch_h - back_t])
                cube([notch_w, wall, notch_h + back_t + eps]);
            // marker: i+1 ticks engraved below the notch
            for (j = [0 : i])
                translate([3 + i * pitch + j * 2, -eps, 1])
                    cube([1, 0.4, 2]);
        }
    }
}

if (part == "knockout_test") knockout_test();

// SIMPLE SNAP Skådis clip (snap): two flexible arms ending in
// hooks go through the plate slot then the pegboard slot, squeeze
// together on the way and spread apart behind the pegboard (click).
// The arms fill the full height of the slot (no vertical play),
// the head (8 x 18 mm) clamps the plate against the pegboard. Hooks
// slanted on the back: it can be removed by pulling firmly.
// Side-view profile (U = toward the wall, V = vertical), extruded over the
// width; printed flat, preferably in PETG.
module skadis_snap() {
    L = back_t + skadis_board + 0.1;     // plate + pegboard
    o = slot_h / 2 - 0.4;                // outer edge of the arms (7.2)
    i = o - snap_arm_t;                  // inner edge
    b = 7.5 + snap_barb;                 // hook (pegboard slot: 15 mm)
    // head, wider than the slot (8 mm), over its full height
    translate([-2, -9, 0]) cube([2, 18, 8]);
    linear_extrude(skadis_hook_w)
        for (sg = [-1, 1]) scale([1, sg])
            polygon([[-eps, i], [-eps, o], [L, o], [L + 0.8, b],
                     [L + 3.2, o - 1.4], [L + 3.2, i - 1.0], [L + 0.8, i]]);
}

// QUARTER-TURN Skådis clip (same principle as the T-Clip, but smaller):
// 1. With the shell removed and the plate against the pegboard, push the
//    clip in from the inside, FOOT VERTICAL, through the slot of the
//    plate then the one in the pegboard.
// 2. Turn it a quarter turn by the head: the foot (14.8 mm) becomes
//    horizontal behind the pegboard and can no longer come out through the
//    5 mm slot; the head (13 mm) clamps the plate against the pegboard.
// Stem with rounded corners (5 mm diagonal) to turn inside the slots.
// Printed flat, no supports. To remove: reverse quarter turn.
module skadis_clip() {
    L = back_t + skadis_board + 0.15;    // plate + pegboard, slight clearance
    t = 4.8;                             // thickness (= print height)
    // foot (behind the pegboard), with entry chamfers
    hull() {
        translate([-7.4, 0, 0]) cube([14.8, 2, t]);
        translate([-6.4, -1, 0]) cube([12.8, 1, t]);
    }
    // stem: 4.8 square with rounded corners
    translate([0, 2 - eps, 0]) intersection() {
        translate([-t / 2, 0, 0]) cube([t, L + 2 * eps, t]);
        translate([0, 0, t / 2]) rotate([-90, 0, 0]) cylinder(d = 5.0, h = L + 2 * eps);
    }
    // head / handle (inside the tile)
    translate([-6.5, 2 + L, 0]) cube([13, 2.5, t]);
}

if (part == "skadis_clips") {
    if (!slot_on) echo("WARNING: enable skadis_slots, pointy orientation");
    if (master && flat < 80) echo("WARNING: Skådis master tile: flat >= 80");
    for (i = [0 : 1]) translate([i * 22, 0, 0])
        if (skadis_clip_type == "twist") skadis_clip(); else skadis_snap();
}

if (part == "plugs")
    for (i = [0 : plug_count - 1]) translate([i * (notch_w + 4), 0, 0]) plug();

if (master && pointy && !d1 && esp_l > 25)
    echo("WARNING: board too long for the diagonal: choose esp_board = d1mini (LED bridge) or an ESP32-C3 Super Mini.");

if (part == "tile" || part == "both") tile();
if (part == "letters") letters();
if (part == "back" || part == "both")
    translate([flat + 10, 0, 0]) {
        back_plate();
        // transparent preview of the PCB (not exported)
        if (pcb_on) %translate([0, 0, back_t + pcb_standoff])
            color("green") linear_extrude(pcb_t) pcb2d();
    }
if (pcb_on && (part == "back" || part == "both" || part == "tile"))
    echo(str("PCB: 3 M2.5 x 6 self-tapping screws. Strip raised by ",
             lift, " mm: dot walls shortened by the same amount ",
             "(reprint the shell, the old walls touch the PCB)."));
if (led_mount == "pcb" && !pcb_on)
    echo("PCB only supported in pointy orientation (and ESP32-C3 for the logo tile): strip on rails.");
if (pcb_on && master && depth - usb_from_back - usb_h / 2 < face + 1.2)
    echo("WARNING: USB window too close to the front: increase depth (26 recommended).");
if (pcb_on && master)
    echo(str("LOGO PCB: 4 M2.5 x 6 screws. Keep the plastic spacer of the pin headers ",
             "of the ESP32 (", esp_spacer, " mm): a screw goes under the module."));
if (part == "stand") {
    if (!pointy) echo("WARNING: the stand is designed for orientation = \"pointy\"");
    stand();
}
