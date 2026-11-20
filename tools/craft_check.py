#!/usr/bin/env python3
"""Craft **every** Cloud Glass recipe in a real crafting table.

Called by `tools/e2e.sh` with the open game's control socket. Uses the
harness's crafting grid (`ctl screen`: slots 100-108 row-major, result 200),
gives the ingredients, and, for every recipe the package carries:

1. places the ingredients exactly as the recipe declares;
2. asserts the result slot holds the declared **output id and count**;
3. takes the result, asserts it reached the inventory, and asserts the grid is
   now **empty** — the ingredients were consumed.

That is 16 wool + glass recipes (all colours, including white) and 15 dye
recipes (every colour but white), i.e. all 31 carried recipes, plus the two
deliberately unmatched stick controls that must leave the result empty.

The table is replaced before every case, so a failed/untaken result cannot leak
into the next grid. Exits 1 with the observed result on the first mismatch
after trying every case (so one run reports all failures).
"""
import json
import subprocess
import sys

# The sixteen colours, in `CloudRegistry` order (`src/runtime.rs::COLOURS`).
COLOURS = [
    "white", "orange", "magenta", "light_blue", "yellow", "lime", "pink",
    "gray", "light_gray", "cyan", "purple", "blue", "brown", "green", "red",
    "black",
]

CROSS = [101, 103, 105, 107]
CENTRE = 104
RING = [100, 101, 102, 103, 105, 106, 107, 108]
GRID = [100, 101, 102, 103, 104, 105, 106, 107, 108]


def main():
    sock, ctl, x, y, z = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
    selftest = "--selftest" in sys.argv[6:]

    def run(*args):
        out = subprocess.run([ctl, "--socket", sock, *args], text=True, capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise SystemExit(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(ticks=4):
        run("wait", str(ticks))

    def slots():
        screen = run("screen")
        if "slots" not in screen:
            raise SystemExit(f"no menu is open: {screen}")
        return screen["slots"]

    def find(item):
        for slot in slots():
            if slot.get("item") == item:
                return slot["slot"]
        raise SystemExit(f"missing ingredient {item} in the inventory")

    def open_table():
        wait()
        print("debug interact:", run("interact", x, y, z))
        wait(5)

    def result():
        """The result slot's stack, or None: an empty slot has `item: null`."""
        stack = [s for s in slots() if s["slot"] == 200]
        if not stack or not stack[0].get("item"):
            return None
        return stack[0]

    def place(item, mode, targets):
        slot = find(item)
        run("click-slot", str(slot))
        wait(1)
        for target in targets:
            if mode == "right":
                run("click-slot", str(target), "right")
            else:
                run("click-slot", str(target))
            wait(1)
        run("click-slot", str(slot))
        wait(2)

    def setup(items):
        try:
            run("close")
        except SystemExit:
            pass
        wait(5)
        # Replace the table so its block entity, and therefore the crafting
        # grid, is fresh for this case.
        run("setblock", x, y, z, "minecraft:air")
        run("setblock", x, y, z, "minecraft:crafting_table")
        wait(2)
        print("debug tp:", run("command", f"tp @s {float(x) - 0.5} {y} {float(z) + 0.5}"))
        wait(3)
        run("command", "clear @s")
        for item, count in items:
            run("give", item, str(count))
        wait(3)
        open_table()

    failures = []

    def craft(label, items, placements, want_item, want_count):
        """Craft one recipe: output id+count, then consumption of the grid."""
        setup(items)
        for item, mode, targets in placements:
            place(item, mode, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if not got or got.get("item") != want_item or got.get("count") != want_count:
            failures.append(f"{label}: expected {want_count} {want_item}, got {got}")
            return
        # Take the result out: the crafted stack must reach the inventory, and
        # taking it is what consumes the grid.
        run("click-slot", "200")
        wait(3)
        run("click-slot", "9")
        wait(3)
        made = run("inventory")["counts"].get(want_item, 0)
        if made < want_count:
            failures.append(
                f"{label}: the crafted stack reached the inventory as {made}, not {want_count}")
        left = [s for s in slots() if s["slot"] in GRID and s.get("item")]
        if left:
            failures.append(f"{label}: the grid still holds {left} — ingredients were not consumed")
        print(f"  consumed: grid empty, inventory holds {made} {want_item}")

    def empty_control(label, items, placements):
        setup(items)
        for item, mode, targets in placements:
            place(item, mode, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if got is not None:
            failures.append(f"{label}: control crafted {got['item']}")

    # ------------------------------------------------------------ 16 wool recipes
    if selftest:
        # One case with a deliberately wrong expected count: the assertion that
        # compares the result stack must reject it, so the count check is
        # fail-capable. The caller expects exit 1 and fails if this passes.
        craft(
            "SELFTEST 4 white_wool + glass, expecting 5",
            [("minecraft:white_wool", 4), ("minecraft:glass", 1)],
            [
                ("minecraft:white_wool", "right", [str(slot) for slot in CROSS]),
                ("minecraft:glass", "right", [str(CENTRE)]),
            ],
            "cloudglass:white_cloud_glass",
            5,
        )
        run("close")
        wait(3)
        if not failures:
            print("SELFTEST: the wrong expected count was accepted", file=sys.stderr)
            raise SystemExit(2)
        print("SELFTEST: the wrong expected count was rejected, as required", file=sys.stderr)
        raise SystemExit(1)

    for colour in COLOURS:
        craft(
            f"4 {colour}_wool + glass",
            [(f"minecraft:{colour}_wool", 4), ("minecraft:glass", 1)],
            [
                (f"minecraft:{colour}_wool", "right", [str(slot) for slot in CROSS]),
                ("minecraft:glass", "right", [str(CENTRE)]),
            ],
            f"cloudglass:{colour}_cloud_glass",
            4,
        )

    # ------------------------------------------------------------- 15 dye recipes
    for colour in COLOURS:
        if colour == "white":
            continue  # white is the dye recipe's base; upstream has no white recipe
        craft(
            f"8 white cloud glass + {colour}_dye",
            [("cloudglass:white_cloud_glass", 8), (f"minecraft:{colour}_dye", 1)],
            [
                ("cloudglass:white_cloud_glass", "right", [str(slot) for slot in RING]),
                (f"minecraft:{colour}_dye", "right", [str(CENTRE)]),
            ],
            f"cloudglass:{colour}_cloud_glass",
            8,
        )

    # ------------------------------------------------------- deliberately unmatched
    empty_control(
        "4 sticks + glass",
        [("minecraft:stick", 4), ("minecraft:glass", 1)],
        [
            ("minecraft:stick", "right", [str(slot) for slot in CROSS]),
            ("minecraft:glass", "right", [str(CENTRE)]),
        ],
    )
    empty_control(
        "8 white cloud glass + stick",
        [("cloudglass:white_cloud_glass", 8), ("minecraft:stick", 1)],
        [
            ("cloudglass:white_cloud_glass", "right", [str(slot) for slot in RING]),
            ("minecraft:stick", "right", [str(CENTRE)]),
        ],
    )

    run("close")
    wait(3)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "recipe PASS: all 31 carried recipes craft their declared output (16 wool + glass -> 4, "
        "15 white cloud glass + dye -> 8) and consume their ingredients; both stick controls "
        "leave the result empty"
    )


if __name__ == "__main__":
    main()
