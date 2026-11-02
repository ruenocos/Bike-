"""Declutter pass (v0.34): strip the small stuff out of the landscape chunks.

Wons (2026-11-02): "reduce the amount of SHIT on the landscape, and just make it
have bigger things happening, and less stupid small shit" / "i die a lot cause
of small stupid shit". Haste / Neon White style: clean, sparse play space, big
readable shapes.

Rules, per prop under Terrain/Props of every chunks/landscape/*.tscn:
- ChokeRock*, GapTree*, Log*, Fence*, Barrier*: removed everywhere (they exist
  only to be dodged).
- Tree / Rock on the valley floor (|x| < half play width - wall width): removed.
- On the banks (the walls up to the crest): one in KEEP_WALL kept.
- Past the crests (scenery): one in KEEP_OUTSIDE kept, trees grown by
  OUTSIDE_TREE_GROW so the frame is fewer, bigger shapes.

Needs the valley position of each prop, which only Godot can work out (bending
valleys), so run the survey first:
    SURVEY_OUT=/abs/survey.json <godot> --headless --path . --script res://debug/prop_survey.gd
    python3 chunks/tools/declutter.py /abs/survey.json
It edits the .tscn text in place (only removes prop blocks and rescales kept
outside trees), so it can be re-run after other branches move props around.
Running it twice thins again: run it once per fresh checkout of the chunks.
"""
import json
import re
import sys
from pathlib import Path

KEEP_WALL = 3
KEEP_OUTSIDE = 2
OUTSIDE_TREE_GROW = 1.6
ALWAYS_REMOVE = ("ChokeRock", "GapTree", "Log", "Fence", "Barrier")

ROOT = Path(__file__).resolve().parents[2]
HEADER = re.compile(r"^\[")


def zone(row: dict) -> str:
    x = abs(row["x"])
    if x < row["half"] - row["wall"]:
        return "floor"
    if x < row["half"]:
        return "wall"
    return "outside"


def grow_transform(line: str, k: float) -> str:
    m = re.match(r"transform = Transform3D\(([^)]*)\)", line)
    if not m:
        return line
    v = [float(s) for s in m.group(1).split(",")]
    for i in range(9):
        v[i] *= k
    return "transform = Transform3D(%s)" % ", ".join("%.7g" % f for f in v)


def process(path: Path, rows: list) -> tuple:
    plan = {}
    counters = {"wall": 0, "outside": 0}
    for row in rows:
        name = row["name"]
        prefix = re.sub(r"\d+$", "", name)
        if prefix.startswith(ALWAYS_REMOVE):
            plan[name] = "remove"
            continue
        if prefix not in ("Tree", "Rock"):
            continue
        z = zone(row)
        if z == "floor":
            plan[name] = "remove"
        elif z == "wall":
            counters["wall"] += 1
            plan[name] = "keep" if counters["wall"] % KEEP_WALL == 0 else "remove"
        else:
            counters["outside"] += 1
            if counters["outside"] % KEEP_OUTSIDE != 0:
                plan[name] = "remove"
            elif prefix == "Tree":
                plan[name] = "grow"

    lines = path.read_text().split("\n")
    out = []
    removed = grown = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r'^\[node name="([^"]*)"[^\n]*parent="Terrain/Props"', line)
        if m and plan.get(m.group(1)) in ("remove", "grow"):
            j = i + 1
            while j < len(lines) and not HEADER.match(lines[j]):
                j += 1
            block = lines[i:j]
            if plan[m.group(1)] == "remove":
                removed += 1
            else:
                grown += 1
                out.extend(grow_transform(b, OUTSIDE_TREE_GROW) for b in block)
            i = j
            continue
        out.append(line)
        i += 1
    # Collapse the blank lines left behind.
    text = re.sub(r"\n{3,}", "\n\n", "\n".join(out))
    path.write_text(text)
    return removed, grown


def main() -> None:
    survey = json.loads(Path(sys.argv[1]).read_text())
    for file, rows in sorted(survey.items()):
        path = ROOT / "chunks" / "landscape" / file
        before = len(rows)
        removed, grown = process(path, rows)
        print("%-28s %4d props -> %4d (grew %d)" % (file, before, before - removed, grown))


if __name__ == "__main__":
    main()
