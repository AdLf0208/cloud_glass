#!/usr/bin/env bash
# In-game check for the Cloud Glass content: sixteen semi-transparent,
# no-collision blocks.
#
# Default run (creative launch, then survival for drops/crafting; The End):
#   1. every `cloudglass:<colour>_cloud_glass` id `setblock`s and reads back, so
#      all 16 default states bind — each with the bare id, i.e. the one
#      property-less state the declaration describes — and a neighbour added and
#      removed changes neither the state nor its property list;
#   2. every block item is `/give`-able and the one creative tab lists all 16;
#   3. mining every colour with a plain pickaxe drops exactly one of itself
#      (upstream dropSelf), with the vanilla glass control dropping nothing
#      without silk touch;
#   4. all 31 carried recipes craft in a table — the 16 wool + glass crosses make
#      4 and the 15 white-cloud-glass + dye rings make 8 — asserting the output
#      id and count and that the grid was consumed; both stick controls leave
#      the result empty;
#   5. `#c:glass_blocks/colorless` matches vanilla glass but not a cloud glass
#      block, and `#c:dyes/light_blue` matches the dye but not red (the recipes'
#      convention tags, which 26.3 does not ship);
#   6. the headline behaviour: walking through three cloud glass blocks moves
#      the player as far as walking through air, while the same line of
#      `minecraft:glass` stops them and `minecraft:cobweb` slows them down
#      (the WebBlock slowdown is name-keyed, so cloudglass is not slowed);
#   7. all 16 block items place and read back, and wrong-name `give`/`setblock`
#      controls fail.
#
# COUNTERFACTUAL=1 breaks `minecraft:glass` and `minecraft:white_wool` instead
# and asserts the vanilla loot (glass 0 without silk, wool 1) and that no
# Cloud Glass item drops. The same scenario against a block that is not ours
# is how the drop assertion proves it can fail.
#
# NEGATIVE=1 (with COUNTERFACTUAL=1) asserts that vanilla glass drops
# `cloudglass:white_cloud_glass`: the run MUST fail, proving the assertion is
# not vacuous.
#
# SELFTEST=1 asserts that a mined cloud glass block drops nothing, so the run
# must fail: the counterfactual proving the drop assertion can fail.
#
# RECIPE_SELFTEST=1 runs the recipe phase's counterfactual (a deliberately
# wrong expected count must be rejected) and keeps the rest of the leg green,
# so the output-count assertion is proven fail-capable without a red log.
#
# TINT_SELFTEST=1 asserts that a cloud glass block at the *feet* (the eye is
# clear) tints the frame, which the correct overlay must not do: the run MUST
# fail there, proving the screenshot differential is not vacuous.
#
# The tint phase is a screenshot differential: the same frame with a cloud
# glass block only at the eye (tinted), only at the feet (not tinted), with
# vanilla glass at the eye (not tinted) and with nothing at the eye. It is the
# only evidence the client overlay exists — a readout cannot see a frame.
#
# STATUS (2026-11-20, SDK 0b14f8a): the port is one flat `.hmod`, and this
# script runs against the **launcher-built game** that carries it
# (`ports/tools/launcher-game.sh run cloudglass`). When `$GAME` is such a build
# its `horizon-native-mods/cloudglass/` is the package, so no `--dev-mod` is
# passed (a dev path *and* the installed package would load the same id twice);
# with any other game the package is passed as `--dev-mod`.
#
# CONTROL=1 launches the same Nightly **without the package** (no `--dev-mod`):
# the first cloud-glass assertion must then fail, so the leg ends `FAIL` +
# `EXIT:1`. That is the differential proving the phases are not vacuous.
set -euo pipefail

CLONE=/home/adlf/Desktop/all_the_mods_10_rust_rewrite
PORT=$CLONE/ports/cloudglass
# The control binary is shared at the campaign pin; the game is this port's build.
CTL=${CTL:-$CLONE/ports/_shared/bin/horizon-1d63e0a5/horizon-ctl}
GAME=${GAME:-$PORT/target/horizon-cargo/fast/horizon-client}
RES=${RES:-${HORIZON_RES:-/home/adlf/Desktop/horizon/.local/horizon-client/26.3}}
E2E_TMP=${E2E_TMP:-/tmp/opencode}
SOCK=${SOCK:-$E2E_TMP/cloudglass-e2e.sock}
COUNTERFACTUAL=${COUNTERFACTUAL:-0}
NEGATIVE=${NEGATIVE:-0}
SELFTEST=${SELFTEST:-0}
CONTROL=${CONTROL:-0}
DEV_MOD=${DEV_MOD:-auto}
RECIPE_SELFTEST=${RECIPE_SELFTEST:-0}
TINT_SELFTEST=${TINT_SELFTEST:-0}
WORLD=CloudGlassE2E

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/cloudglass.hmod" ] || { echo "missing package: $PORT/cloudglass.hmod (run cargo horizon-mod build)" >&2; exit 1; }

COLOURS=(white orange magenta light_blue yellow lime pink gray light_gray \
    cyan purple blue brown green red black)

SCRATCH=$(mkdir -p "$E2E_TMP" && mktemp -d "$E2E_TMP/cloudglass-home.XXXXXX")
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
say() { echo "+ $*"; }
count_item() { ctl inventory | jq -r --arg i "$1" '.counts[$i] // 0'; }
block_state() { ctl block "$1" "$2" "$3" | jq -r '.block // "unknown"'; }
end() { ctl command "execute in minecraft:the_end run $1"; }
moved() { ctl move forward 2 | jq -r '.moved // -1'; }

cleanup() {
    local status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    # Keep the game's own log (it holds the port's log lines) beside the run.
    if [ -f "$SCRATCH/game/logs/latest.log" ]; then
        cp "$SCRATCH/game/logs/latest.log" "$PORT/target/last-game.log" 2>/dev/null || true
    fi
    rm -rf "$SCRATCH" || true
    # Last line of every run: `check-e2e-logs.py` reads it as the verdict.
    echo "EXIT:$status"
}
trap cleanup EXIT

launch() { # launch [WORLD]
    local world=${1:-$WORLD}
    rm -f "$SOCK"
    local args=(--game "$GAME" --world "$world" --seed 20261105 --creative --offscreen --wait
                --game-dir "$SCRATCH/game" --resources "$RES")
    # The launcher-built game already carries the package; only pass a dev path
    # when it does not. CONTROL=1 never loads the package.
    local installed
    installed=$(dirname "$GAME")/horizon-native-mods/cloudglass/horizon-mod.toml
    if [ "$CONTROL" != 1 ] && { [ "$DEV_MOD" = 1 ] || { [ "$DEV_MOD" = auto ] && [ ! -f "$installed" ]; }; }; then
        args+=(--dev-mod "$PORT/cloudglass.hmod")
    fi
    "$CTL" --socket "$SOCK" launch "${args[@]}" >/dev/null
    ctl wait-ready 180
}

if [ "$CONTROL" = 1 ]; then
    say "CONTROL leg: the same Nightly without the package; every cloud glass id must be absent"
fi
say "launch (offscreen renderer, creative)"
launch
ctl wait-ready 180

say "The End platform at y=79 and an empty box above it"
end "forceload add -16 -16 40 16"
end "tp @s 0.5 80 2.5"
ctl wait 40
end "fill -16 79 -16 40 79 16 minecraft:stone"
end "fill -16 80 -16 40 90 16 minecraft:air"
end "kill @e[type=minecraft:item]"
# Remove the dragon (and its crystals) so survival mining and walking stay
# deterministic; killing it opens the win screen, which is closed once.
end "kill @e[type=minecraft:ender_dragon]"
end "kill @e[type=minecraft:end_crystal]"
end "difficulty peaceful"
end "tp @s 0.5 80 2.5"
ctl wait 10
ctl close >/dev/null 2>&1 || true
ctl wait 3

# ---------------------------------------------------------------- state bind
# `ctl block` prints the state as `id` or `id[prop=value,...]`, so equality with
# the bare id asserts both the binding and that the block really has the single
# property-less state the declaration describes.
say "every cloud glass id binds its default state"
for i in "${!COLOURS[@]}"; do
    c=${COLOURS[$i]}
    x=$i
    end "setblock $x 80 -2 cloudglass:${c}_cloud_glass" >/dev/null || fail "setblock cloudglass:${c}_cloud_glass failed"
done
ctl wait 10
for i in "${!COLOURS[@]}"; do
    c=${COLOURS[$i]}
    x=$i
    got=$(block_state "$x" 80 -2)
    [ "$got" = "cloudglass:${c}_cloud_glass" ] || fail "x=$x reads '$got', expected cloudglass:${c}_cloud_glass"
    case "$got" in *"["*) fail "cloudglass:${c}_cloud_glass bound with properties ($got); the declaration has one state" ;; esac
done
echo "16/16 default states bound (one property-less state each)"

# --------------------------------------------------- neighbour stability
# These are not connected-texture blocks: a neighbour must neither add a
# property (no `[...]` appears) nor change the block itself. Both directions
# are asserted, so a future connection-state or neighbour-dependent bug fails
# here instead of passing as "the block exists".
say "a neighbour neither adds a state property nor changes the block"
end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
end "setblock 0 80 5 cloudglass:white_cloud_glass" >/dev/null
ctl wait 3
alone=$(block_state 0 80 5)
[ "$alone" = "cloudglass:white_cloud_glass" ] || fail "isolated white reads '$alone'"
end "setblock 1 80 5 cloudglass:light_blue_cloud_glass" >/dev/null
ctl wait 3
paired_a=$(block_state 0 80 5)
paired_b=$(block_state 1 80 5)
[ "$paired_a" = "cloudglass:white_cloud_glass" ] || fail "white changed with a neighbour: '$paired_a'"
[ "$paired_b" = "cloudglass:light_blue_cloud_glass" ] || fail "light blue changed with a neighbour: '$paired_b'"
end "setblock 1 80 5 minecraft:air" >/dev/null
ctl wait 3
after=$(block_state 0 80 5)
[ "$after" = "$alone" ] || fail "white changed when the neighbour was removed: '$after' vs '$alone'"
echo "neighbour states: alone '$alone', paired '$paired_a' + '$paired_b', after removal '$after' (no property ever appeared)"
end "setblock 1 80 5 minecraft:air" >/dev/null

# --------------------------------------------------------------- item side
say "every cloud glass item is give-able"
ctl command "clear @s" >/dev/null
for c in "${COLOURS[@]}"; do
    ctl give "cloudglass:${c}_cloud_glass" 1 >/dev/null || fail "give cloudglass:${c}_cloud_glass failed"
done
ctl wait 10
for c in "${COLOURS[@]}"; do
    [ "$(count_item "cloudglass:${c}_cloud_glass")" -ge 1 ] || fail "cloudglass:${c}_cloud_glass is missing"
done
echo "16/16 cloud glass items are give-able"

# The content overlay is built in `mod-content/<stamp>/` under the game's
# cache (one folder per mod set), so the file is found rather than assumed.
CREATIVE=$(find "$SCRATCH/game/.horizon-cache/mod-content" -name creative-inventory.json 2>/dev/null | head -1)
if [ -n "$CREATIVE" ] && [ -f "$CREATIVE" ]; then
    for c in "${COLOURS[@]}"; do
        grep -q "cloudglass:${c}_cloud_glass" "$CREATIVE" || fail "creative tab misses cloudglass:${c}_cloud_glass"
    done
    echo "creative tab lists all 16 entries"
else
    fail "no creative-inventory.json under $SCRATCH/game/.horizon-cache/mod-content"
fi

if [ "$COUNTERFACTUAL" = 1 ]; then
    # ------------------------------------------------------- differential
    say "counterfactual: mine minecraft:glass and white wool"
    end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
    end "setblock 0 80 -2 minecraft:glass" >/dev/null || fail "cannot set vanilla glass"
    end "setblock 1 80 -2 minecraft:white_wool" >/dev/null || fail "cannot set white wool"
    ctl wait 3
    ctl command "gamemode survival @s" >/dev/null
    ctl command "clear @s" >/dev/null
    ctl give minecraft:diamond_pickaxe 1 >/dev/null
    ctl wait 2
    ctl select minecraft:diamond_pickaxe >/dev/null
    ctl wait 2
    ctl command "tp @s 0.5 80 0.5" >/dev/null
    ctl wait 10
    ctl look-at-block 0 80 -2 >/dev/null || true
    broken=$(ctl break 0 80 -2) || { echo "break reply: $broken"; fail "cannot break the vanilla glass"; }
    echo "$broken" | jq -c '{scenario:"vanilla glass",block,block_before,drops}'
    [ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "vanilla glass did not break"
    vanilla_glass=$(echo "$broken" | jq -r '.drops["minecraft:glass"] // 0')
    cloud_glass=$(echo "$broken" | jq -r '.drops["cloudglass:white_cloud_glass"] // 0')
    if [ "$NEGATIVE" = 1 ]; then
        [ "$cloud_glass" -ge 1 ] || fail "NEGATIVE run correctly failed: the false claim (vanilla glass drops a Cloud Glass block) did not hold (cloudglass glass=$cloud_glass)"
        fail "NEGATIVE run: the false claim held, so the drop assertion is vacuous"
    fi
    [ "$vanilla_glass" -eq 0 ] || fail "vanilla glass dropped $vanilla_glass without silk touch"
    [ "$cloud_glass" -eq 0 ] || fail "vanilla glass dropped $cloud_glass cloudglass:white_cloud_glass"
    echo "vanilla glass without silk touch dropped nothing (vanilla loot)"

    say "white wool with shears drops itself, never a Cloud Glass item"
    ctl command "clear @s" >/dev/null
    ctl give minecraft:shears 1 >/dev/null
    ctl wait 2
    ctl select minecraft:shears >/dev/null
    ctl wait 2
    ctl command "tp @s 1.5 80 0.5" >/dev/null
    ctl wait 10
    ctl look-at-block 1 80 -2 >/dev/null || true
    broken=$(ctl break 1 80 -2) || { echo "break reply: $broken"; fail "cannot break the white wool"; }
    echo "$broken" | jq -c '{scenario:"white wool",block,block_before,drops}'
    white_wool=$(echo "$broken" | jq -r '.drops["minecraft:white_wool"] // 0')
    cloud_wool=$(echo "$broken" | jq -r '.drops["cloudglass:white_cloud_glass"] // 0')
    [ "$white_wool" -ge 1 ] || fail "white wool dropped $white_wool of itself"
    [ "$cloud_wool" -eq 0 ] || fail "white wool dropped $cloud_wool cloudglass:white_cloud_glass"
    echo "COUNTERFACTUAL PASS: vanilla glass needs silk touch, vanilla wool drops itself, and none drops a Cloud Glass item"

    say "walking through vanilla glass is blocked (the movement differential's control)"
    end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
    end "fill 2 80 9 4 80 11 minecraft:glass" >/dev/null
    ctl command "tp @s 0.5 80 10.5" >/dev/null
    ctl look-at 50 80 10.5 >/dev/null
    ctl wait 5 >/dev/null
    d_glass=$(moved)
    echo "vanilla glass moved=$d_glass"
    [ "$(echo "$d_glass < 2.5" | bc)" = "1" ] || fail "the player passed through vanilla glass (moved=$d_glass)"

    say "wrong-name controls still fail"
    if ctl give cloudglass:not_a_glass 1 >/dev/null 2>&1; then
        fail "give cloudglass:not_a_glass succeeded"
    fi
    end "setblock 6 80 5 cloudglass:bogus_cloud_glass" >/dev/null 2>&1 || true
    [ "$(block_state 6 80 5)" = "minecraft:air" ] || fail "cloudglass:bogus_cloud_glass became a block"
    echo "unknown cloud glass ids are refused"
    echo "PASS: counterfactual differential"
    exit 0
fi

# ------------------------------------------------------------------- drops
# Every loot table the package carries (one per colour) is exercised: the block
# is mined with a plain pickaxe and must drop exactly one of itself.
say "mine all sixteen cloud glass colours: each drops itself"
end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
ctl command "gamemode survival @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give minecraft:diamond_pickaxe 1 >/dev/null
ctl wait 2
ctl select minecraft:diamond_pickaxe >/dev/null
ctl wait 2
for i in "${!COLOURS[@]}"; do
    c=${COLOURS[$i]}
    end "setblock $i 80 -2 cloudglass:${c}_cloud_glass" >/dev/null
    # In reach: the player is moved beside the block it is about to mine.
    ctl command "tp @s $((i)).5 80 0.5" >/dev/null
    ctl wait 2
    ctl look-at-block "$i" 80 -2 >/dev/null || true
    broken=$(ctl break "$i" 80 -2) || { echo "break reply: $broken"; fail "cannot break $c cloud glass"; }
    echo "$broken" | jq -c --arg c "$c" '{block,block_before,drops}'
    [ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "$c cloud glass did not break"
    got=$(echo "$broken" | jq -r --arg i "cloudglass:${c}_cloud_glass" '.drops[$i] // 0')
    if [ "$SELFTEST" = 1 ]; then
        [ "$got" -eq 0 ] || fail "selftest: $c cloud glass dropped $got, expected nothing (must FAIL)"
    else
        [ "$got" -eq 1 ] || fail "$c cloud glass dropped $got of cloudglass:${c}_cloud_glass (expected exactly 1)"
    fi
done
echo "drop table: 16/16 colours dropped exactly one of themselves with a plain pickaxe (upstream dropSelf)"

# ------------------------------------------------------------------ recipes
# Every carried recipe is crafted in a real crafting table (tools/craft_check.py):
# 16 wool + glass crosses make 4, 15 white-cloud-glass + dye rings make 8, and
# each shape's stick control leaves the result empty. Each case also proves the
# ingredients were consumed.
say "craft all 31 recipes in a table: 16 wool + glass, 15 white + dye"
end "setblock 6 80 2 minecraft:crafting_table"
ctl command "tp @s 5.5 80 2.5" >/dev/null
ctl wait 5
if [ "$RECIPE_SELFTEST" = 1 ]; then
    # Counterfactual: the same craft with a deliberately wrong expected count
    # must be rejected, so the output-count assertion is fail-capable.
    if python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 6 80 2 --selftest; then
        fail "recipe selftest: a wrong expected output count was accepted"
    fi
    echo "recipe selftest: a wrong expected output count is rejected (the count assertion can fail)"
fi
python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 6 80 2 || fail "the cloud glass recipe checks failed"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl wait 3

# --------------------------------------------------------------------- tags
# The recipes above prove the tags by construction; at this pin the command
# predicate can also name them (it validates against the game's own tag set,
# which carries content tags). Both families get a positive and a negative
# assertion, so "the tag exists" cannot pass on a blanket yes.
say "content c: tags resolve for blocks and items, and only for their members"
end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
end "setblock 0 80 5 minecraft:glass" >/dev/null
end "setblock 1 80 5 cloudglass:white_cloud_glass" >/dev/null
ctl wait 3
ctl command "execute if block 0 80 5 #c:glass_blocks/colorless run say TAG_BLOCK_GLASS" >/dev/null
ctl command "execute if block 1 80 5 #c:glass_blocks/colorless run say TAG_BLOCK_CLOUD" >/dev/null
ctl command "clear @s" >/dev/null
ctl give minecraft:light_blue_dye 1 >/dev/null
ctl wait 3
ctl command "execute if items entity @a container.* #c:dyes/light_blue run say TAG_ITEM_DYE" >/dev/null
ctl command "execute if items entity @a container.* #c:dyes/red run say TAG_ITEM_RED" >/dev/null
ctl wait 3
messages=$(ctl messages 20 | jq -r '.chat[]')
echo "$messages" | grep -q "TAG_BLOCK_GLASS" || fail "#c:glass_blocks/colorless does not match minecraft:glass"
echo "$messages" | grep -q "TAG_ITEM_DYE" || fail "#c:dyes/light_blue does not match minecraft:light_blue_dye"
if echo "$messages" | grep -q "TAG_BLOCK_CLOUD"; then
    fail "#c:glass_blocks/colorless matched a cloud glass block, but the tag ships only minecraft:glass"
fi
if echo "$messages" | grep -q "TAG_ITEM_RED"; then
    fail "#c:dyes/red matched light_blue_dye"
fi
echo "tags: #c:glass_blocks/colorless matches glass (not cloud glass), #c:dyes/light_blue matches the dye (not red)"
ctl command "clear @s" >/dev/null

# ------------------------------------------------------- no-collision walk
say "walk through cloud glass: air, cloud glass, vanilla glass and cobweb"
end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
ctl command "gamemode survival @s" >/dev/null
ctl command "effect clear @s" >/dev/null
ctl command "clear @s" >/dev/null

walk() {
    ctl release >/dev/null 2>&1 || true
    ctl command "tp @s 0.5 80 10.5" >/dev/null
    ctl look-at 50 80 10.5 >/dev/null
    ctl wait 10 >/dev/null
    moved
}
d_air=$(walk)
echo "air moved=$d_air"
[ "$(echo "$d_air > 5.0" | bc)" = "1" ] || fail "the air control did not walk (moved=$d_air)"

end "fill 2 80 9 4 80 11 cloudglass:light_blue_cloud_glass" >/dev/null
d_cloud=$(walk)
echo "cloud glass moved=$d_cloud"
[ "$(echo "$d_cloud >= $d_air - 1.5" | bc)" = "1" ] || fail "cloud glass blocked or slowed the walk (air=$d_air, cloud=$d_cloud)"

end "fill 2 80 9 4 80 11 minecraft:glass" >/dev/null
d_glass=$(walk)
echo "vanilla glass moved=$d_glass"
[ "$(echo "$d_glass < 2.5" | bc)" = "1" ] || fail "the player passed through vanilla glass (moved=$d_glass)"

end "fill 2 80 9 4 80 11 minecraft:cobweb" >/dev/null
d_web=$(walk)
echo "vanilla cobweb moved=$d_web"
[ "$(echo "$d_web < $d_cloud - 2.0" | bc)" = "1" ] || fail "vanilla cobweb did not slow the walk (cloud=$d_cloud, web=$d_web)"
echo "no collision: cloud glass $d_cloud vs air $d_air; vanilla glass stops at $d_glass; cobweb slows to $d_web"

# --------------------------------------------------------------- placement
# Every variant is placed by its own item and read back, so the item model,
# the block item and the placement path are all exercised per colour.
say "all sixteen block items place and read back"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
ctl command "tp @s 10.5 80 5.5" >/dev/null
for i in "${!COLOURS[@]}"; do
    c=${COLOURS[$i]}
    x=$i
    ctl command "tp @s $((x)).5 80 4.5" >/dev/null
    # Creative placement does not consume the item, so the nine hotbar slots
    # would fill after nine colours and the tenth `select` would fail on an
    # item sitting in the main inventory. Clear before each colour.
    ctl command "clear @s" >/dev/null
    ctl give "cloudglass:${c}_cloud_glass" 1 >/dev/null || fail "cannot give $c cloud glass"
    ctl wait 2
    ctl select "cloudglass:${c}_cloud_glass" >/dev/null || fail "cannot select $c cloud glass"
    ctl wait 2
    reply=$(ctl place "$x" 80 6 --item "cloudglass:${c}_cloud_glass" 2>&1) || { echo "place reply: $reply"; fail "cannot place $c cloud glass"; }
    ctl wait 3
    got=$(block_state "$x" 80 6)
    [ "$got" = "cloudglass:${c}_cloud_glass" ] || fail "placed $c cloud glass reads '$got'"
    echo "cloudglass:${c}_cloud_glass placed at $x 80 6"
done
echo "placement: 16/16 block items placed and read back"

say "wrong-name controls fail"
if ctl give cloudglass:not_a_glass 1 >/dev/null 2>&1; then
    fail "give cloudglass:not_a_glass succeeded"
fi
end "setblock 6 80 5 cloudglass:bogus_cloud_glass" >/dev/null 2>&1 || true
[ "$(block_state 6 80 5)" = "minecraft:air" ] || fail "cloudglass:bogus_cloud_glass became a block"
if ctl setblock 6 80 5 cloudglass:bogus_cloud_glass >/dev/null 2>&1; then
    fail "setblock accepted cloudglass:bogus_cloud_glass"
fi
echo "unknown cloud glass ids are refused (give, command setblock)"

echo "== screen tint while the eye is inside cloud glass (screenshot differential) =="
# Upstream `ClientTick.java:24-43` fills the frame with ARGB `0x80` +
# `CloudGlassBlock.getTintRgb()` when the block at
# `BlockPos.containing(player.getEyePosition())` is a Cloud Glass block. This
# phase measures the same frame three ways, from the central 40% so the HUD and
# the hand do not matter:
#   off   — nothing at the eye or the feet;
#   glass — vanilla glass at the eye (the control that must not tint);
#   eye   — cloud glass at the eye and air at the feet (must tint);
#   feet  — cloud glass at the feet and nothing at the eye (must NOT tint: the
#           block is read at the eye, as upstream does, not at the player).
mean_rgb() {
    python3 - "$1" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
crop = im.crop((w * 3 // 10, h * 3 // 10, w * 7 // 10, h * 7 // 10))
px = list(crop.getdata())
n = len(px)
print(sum(p[0] for p in px) / n, sum(p[1] for p in px) / n, sum(p[2] for p in px) / n)
PY
}
# Euclidean distance to orange's diffuse colour (0xF9801D), the tint's colour.
orange_distance() {
    awk -v r="$1" -v g="$2" -v b="$3" 'BEGIN { printf "%.1f", sqrt((r-249)^2 + (g-128)^2 + (b-29)^2) }'
}
tint_shot() { # <eye block> <feet block> <tag> -> the frame's mean RGB
    ctl command "setblock 0 81 0 $1" >/dev/null
    ctl command "setblock 0 80 0 $2" >/dev/null
    ctl wait 10 >/dev/null
    ctl screenshot "$SCRATCH/tint-$3.png" >/dev/null
    mean_rgb "$SCRATCH/tint-$3.png"
}

end "fill -16 80 -16 40 90 16 minecraft:air" >/dev/null
ctl command "tp @s 0.5 80 0.5" >/dev/null
ctl look-at 0.5 80 -40 >/dev/null
ctl wait 10
read -r r0 g0 b0 <<<"$(tint_shot minecraft:air minecraft:air off)"
read -r rg gg bg <<<"$(tint_shot minecraft:glass minecraft:air glass)"
read -r r1 g1 b1 <<<"$(tint_shot cloudglass:orange_cloud_glass minecraft:air eye)"
read -r rf gf bf <<<"$(tint_shot minecraft:air cloudglass:orange_cloud_glass feet)"
d0=$(orange_distance "$r0" "$g0" "$b0")
dg=$(orange_distance "$rg" "$gg" "$bg")
d1=$(orange_distance "$r1" "$g1" "$b1")
df=$(orange_distance "$rf" "$gf" "$bf")
echo "  mean off:   $r0 $g0 $b0 (orange distance $d0)"
echo "  mean glass: $rg $gg $bg (orange distance $dg)"
echo "  mean eye:   $r1 $g1 $b1 (orange distance $d1)"
echo "  mean feet:  $rf $gf $bf (orange distance $df)"

if [ "$TINT_SELFTEST" = 1 ]; then
    # Counterfactual: a cloud glass block at the feet, with the eye clear, must
    # NOT tint. Asserting that it does makes the run fail — the proof that the
    # assertion below can fail.
    awk -v a="$df" -v b="$d0" 'BEGIN { exit !(a < b - 30) }' \
        || fail "tint selftest: a block at the feet did not tint (feet=$df, off=$d0), so this MUST fail: the overlay reads the eye, not the feet"
fi
awk -v a="$d1" -v b="$d0" 'BEGIN { exit !(a < b - 30) }' \
    || fail "cloud glass at the eye did not tint the frame (eye=$d1, off=$d0, needs > 30 closer to 0xF9801D)"
awk -v a="$d1" -v b="$dg" 'BEGIN { exit !(a < b - 30) }' \
    || fail "the tint did not follow the cloud-glass block (vanilla glass eye=$dg, cloud eye=$d1)"
if awk -v a="$dg" -v b="$d0" 'BEGIN { exit !(a < b - 30) }'; then
    fail "vanilla glass at the eye tinted the frame: the overlay ignores the block"
fi
awk -v a="$df" -v b="$d0" 'BEGIN { exit !(a >= b - 30) }' \
    || fail "a cloud glass block at the feet alone tinted the frame (feet=$df, off=$d0): the overlay does not read the eye"
TINT_VERDICT="the eye overlay tints the frame with cloud glass at the eye (orange distance $d1 vs off $d0) and not with vanilla glass ($dg) or a cloud glass block at the feet alone ($df)"
echo "eye overlay: $TINT_VERDICT"
ctl command "setblock 0 81 0 minecraft:air" >/dev/null
ctl command "setblock 0 80 0 minecraft:air" >/dev/null

echo "PASS: 16/16 states bind with no property and stay unchanged when a neighbour is added or removed, 16/16 items give, the tab lists 16, 16/16 colours drop exactly one of themselves, all 31 carried recipes craft their declared output and consume their ingredients while both stick controls stay empty, #c:glass_blocks/colorless and #c:dyes/light_blue match their members and nothing else, walking through cloud glass matches air while vanilla glass stops the player and cobweb slows them, 16/16 block items place and read back, $TINT_VERDICT, and unknown ids are refused by give and setblock"
