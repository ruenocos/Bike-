"""Adds a SpeedStrip (chunks/parts/speed_strip) in front of kickers (v0.34).

Wons (2026-11-02): "bigger things happening", "fun speed ramping". A glowing
strip on the run-up of each kicker pushes you up to speed so the kicker throws
you into a big air. Each strip is a normal node in the chunk scene (named
SpeedStrip<Pad>), so it can be moved or tuned in the editor afterwards.

    python3 chunks/tools/add_speed_strips.py

Idempotent: a chunk that already has a strip for a pad is left alone.
Text-only: reads the KickerPad transform (a TerrainFlatten under Terrain, which
sits at the chunk origin) and the Kicker's scale, and puts the strip's front
end GAP metres behind the kicker's foot, along the pad's slope.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STRIP = "res://chunks/parts/speed_strip/speed_strip.tscn"
LENGTH = 60.0
GAP = 4.0
KICKER_DEPTH = 8.0
LANE_WIDTH = 14.0
LANE_BLEND = 10.0  # kicker.tscn runs from local z 8 (foot) to 0 (lip)
# Set pieces whose jumps were tuned for a set speed (chasm, abyss, mesa sim):
# no extra push there.
SKIP = {"set_ravine.tscn", "set_world_tree.tscn", "set_narrows.tscn", "set_mesa_launch.tscn",
        "land_start.tscn", "land_finish.tscn"}


# Shorter strips where the full run-up would start on a bank or over a crest;
# 0 = no strip (this kicker aims across the valley: more speed overshoots onto
# the far bank and bails, see debug/speed_strip_test).
LENGTH_OVERRIDE = {"land_switchback_right.tscn/KickerPad1": 0.0}


def parse_transform(text: str) -> list:
    return [float(v) for v in text.split(",")]


def apply(t: list, p: tuple) -> tuple:
    # Godot writes Transform3D(...) as the basis rows, then the origin.
    x, y, z = p
    return (t[0] * x + t[1] * y + t[2] * z + t[9],
            t[3] * x + t[4] * y + t[5] * z + t[10],
            t[6] * x + t[7] * y + t[8] * z + t[11])


def process(path: Path) -> int:
    text = path.read_text()
    pads = []
    for m in re.finditer(r'\[node name="([^"]*Pad\d*)" type="Node3D" parent="Terrain"[^\n]*\]\ntransform = Transform3D\(([^)]*)\)', text):
        pad, tf = m.group(1), parse_transform(m.group(2))
        km = re.search(r'\[node name="Kicker" type="CSGCombiner3D" parent="Terrain/%s"[^\n]*\]\n(?:transform = Transform3D\(([^)]*)\))?' % re.escape(pad), text)
        if km is None:
            continue
        scale = 1.0
        if km.group(1):
            k = parse_transform(km.group(1))
            scale = (k[2] ** 2 + k[5] ** 2 + k[8] ** 2) ** 0.5  # z axis length
        pads.append((pad, tf, scale))
    if not pads:
        return 0
    if STRIP not in text:
        ids = re.findall(r'\[ext_resource [^\]]*id="([^"]*)"\]', text)
        last = list(re.finditer(r'\[ext_resource [^\n]*\]\n', text))[-1]
        text = text[:last.end()] + '[ext_resource type="PackedScene" path="%s" id="v34_strip"]\n' % STRIP + text[last.end():]
        m = re.search(r'load_steps=(\d+)', text)
        if m:
            text = text.replace(m.group(0), "load_steps=%d" % (int(m.group(1)) + 1), 1)
    added = 0
    for pad, tf, scale in pads:
        name = "SpeedStrip" + pad.replace("Pad", "")
        if ('[node name="%s"' % name) in text:
            continue
        length = LENGTH_OVERRIDE.get(path.name + "/" + pad, LENGTH)
        if length <= 0.0:
            continue
        back = KICKER_DEPTH * scale + GAP + length
        origin = apply(tf, (0.0, 0.0, back))
        basis = tf[:9]
        # Strip the pad's own scale (TerrainFlatten pads are unscaled, but be safe).
        node = ('\n[node name="%s" parent="." instance=ExtResource("v34_strip")]\n'
                'transform = Transform3D(%s, %.5f, %.5f, %.5f)\n'
                'length = %.1f\n' % (name, ", ".join("%.7g" % v for v in basis), origin[0], origin[1], origin[2], length))
        text = text.rstrip("\n") + "\n" + node
        added += 1
    path.write_text(text)
    return added


def main() -> None:
    for path in sorted((ROOT / "chunks" / "landscape").glob("*.tscn")):
        if path.name in SKIP:
            continue
        n = process(path)
        if n:
            print("%-28s +%d speed strip(s)" % (path.name, n))


if __name__ == "__main__":
    main()
