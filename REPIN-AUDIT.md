# Cloud Glass — re-pin audit at Horizon `83ad384f`

Read-only audit. No port code, build, e2e or campaign document was changed.

- Pin: Horizon **`83ad384f`** (427 hooks / 159 helpers) at `ports/_shared/pins/horizon-83ad384f`;
  mixins `e8cd0aa` at `ports/_shared/pins/horizon-mixins-e8cd0aa`.
- Compared against the port's pin `c9d474dd…` (108 hooks, 0 listed helpers).
- Sources: `notes.md` §Gaps (10 items) and ARCHITECTURE.md §37 ("Gaps: screen tint … beacon beam
  tint, note-block instrument, cobweb `dampening` residue; `c:` tags are command-invisible").
- All paths are relative to `ports/_shared/pins/horizon-83ad384f/`.

No hook the port uses today changes version; the port has no `[[injection]]`, so nothing breaks at
the new pin. Migrating is the shared recipe in `_shared/repin-83ad384f.md`; this audit is about the
deferred features.

## Deferred features

| # | Deferred feature (notes §Gaps) | Pin surface (symbol, file:line) | Class | Verdict | Exact next step |
|---|---|---|---|---|---|
| 1 | Pane blocks (gap 1) | — (upstream 1.1.0 has none; `FINDINGS.md`) | n/a | **not a gap** | none. |
| 2 | Template facts: `dampening = 1`, `skylight_down = false`, `push = POPPED` (gap 2) | Content block properties have `occludes` (`crates/horizon-mods/src/content.rs:95`), `render_shape` (`:92`), `random_ticks` (`:90`) but no dampening/skylight/push; no hook either | absent | **blocked** | Keep documented. Pin request: `dampening`, `skylight_down`, `push` in `BlockProperties` (`content.rs:77-96`). Cosmetic (skylight) / piston behaviour only. |
| 3 | **Screen tint** while the eye is inside a cloud-glass block (gap 3) | **`gui_layer_pre` (cancel/draw) `.../native_hooks.rs:2495` and `gui_layer_post` `:2506` — both new hooks** (API 139); `native_fill` `:8823`, `native_quad` `:8952`; the client's block read `native_block` `:9041`; camera `native_camera` `:9046` (new at this pin; `NativeCamera.position` is the camera/eye position, `crates/horizon-client/src/mod_api.rs:70-84`, filled at `game.rs:16120`) | usable (new at this pin) | **realizable now** | One `gui_layer_pre` injection on layer `minecraft:crosshair` (first layer, so the tint sits under the HUD): `native_camera().position` → floor to a block pos → `native_block(pos)`; if it is `cloudglass:*_cloud_glass`, `native_fill(batch, [0.0, 0.0, batch.width, batch.height], tint)` with alpha `0x80` over the dye's diffuse colour. Keep the 16 diffuse colours in `runtime.rs` (test them). e2e: screenshot with/without a block at eye, plus a counterfactual (tint off → pixel check fails). |
| 4 | Beacon beam tint (gap 4) | Beam colour is name-keyed on `minecraft:*_stained_glass`: `crates/horizon-client/src/game/beacon.rs:112-122`; `beacon_state_change` (`:130-140`) is listen-only (levels gained/lost, no colour) | hook-only (and not the colour) | **blocked** | Pin request (a `BeamColorBlock`-style predicate or a content beam-colour field). A custom beam via `block_entity` + `block_entity_submit` would re-implement the beam, not worth it for a cosmetic. |
| 5 | Note-block instrument `HAT` (gap 5) | No content field (`content.rs:77-96`); state is set from per-block facts, `crates/horizon-world/src/level/shapes.rs:1160-1176` + `level/data.rs:65,1146`; hooks `neighbor_changed` (old, listen) and `note_block_change` (new, cancel); helper `native_set_block_property` `.../native_hooks.rs:8303` | hook-only + usable helper | **realizable via a workaround** | Inject on `neighbor_changed`/`block_changed`: if the changed block is a cloud-glass block and the block above/below is a note block, `native_set_block_property(note_pos, "instrument", "hat")`. e2e: place a note block on cloud glass, `/playsound`-free check via `ctl` note pitch or the state string. Prefer the content `instrument` field if the pin adds one. |
| 6 | `c:` tags invisible to commands (gap 6) | Command registry tags come from the prepared registries JSON: `crates/horizon-client-core/src/registries.rs:79,208-210`; content tags only enter the overlay (`crates/horizon-mods/src/content.rs:684-686`); `native_server_block_in_tag` (`crates/horizon-client/src/game/native_world_read.rs:69`, API 63) is native code only | absent (command path) | **blocked** | Keep the crafting proof. Pin request if `/execute if block #c:glass_blocks/colorless` must work; a mod command could use the two `native_server_*_in_tag` helpers instead. |
| 7 | Map colour not visually checked (gap 7) | Content `map_color` field exists, `crates/horizon-mods/src/content.rs:86` | usable | **verification gap only** | Optional e2e step: fill a map covering a cloud-glass build and compare the pixel colour. Low value. |
| 8 | Unused upstream textures (gap 8) | — | n/a | **not a gap** | none. |
| 9 | Loot table shape (gap 9) | Pool `condition` shape already used (`notes.md`; `horizon-world` loot loader) | usable | **resolved** | none. |
| 10 | Recipe book index (gap 10) | `RecipeIndex::load` reads `data/minecraft/recipe` + pack overlay only, `crates/horizon-client/src/recipe_book.rs:723-790`; mod recipes are in `data/<ns>/recipe` (`crafting.rs:1459-1466`) | absent on the vanilla path; usable workaround | **realizable via a workaround** | Push `recipe/cloudglass:<id>` for the 31 recipes through `data_pack_files` (`.../native_hooks.rs:2377`, new) so they reach `WorldTables.files` and the index; or accept the crafting-table evidence. |

## Summary

- **Deferred features audited:** 10 notes rows → 7 live gaps (rows 1, 8 are non-gaps, row 9 is
  resolved).
- **Newly realizable because of the re-pin:** 1 — **row 3, the screen tint** (`gui_layer_pre`/
  `gui_layer_post`, `native_camera`; all new). This is the port's headline gap and it is now a
  ~40-line helper.
- **Realizable by workaround:** 2 — row 5 (note instrument via `set_block_property`) and row 10
  (`/recipe give` via `data_pack_files`).
- **Still blocked:** 3 — row 2 (dampening/skylight/push fields), row 4 (beacon beam colour), row 6
  (`c:` tags in command arguments). One verification-only row (7).
- **Highest-value next step:** implement **row 3**, the eye-inside tint. It was the only feature
  the pin's API made impossible before (no GUI layer hook, no camera helper); it needs one
  `gui_layer_pre` injection, the camera/block reads and a `native_fill` — all present at this pin,
  and it is fail-capable in e2e with a screenshot differential.

## How to re-check (read-only)

```sh
P=ports/_shared/pins/horizon-83ad384f
python3 - <<'EOF'
import json; d=json.load(open('ports/_shared/pins/horizon-83ad384f/native-hooks.json'))
for n in ('gui_layer_pre','gui_layer_post','neighbor_changed','note_block_change','data_pack_files'):
    print(n, [h['mod_api'] for h in d['hooks'] if h['name']==n])
print([h['name'] for h in d['helpers'] if h['name'] in ('camera','fill','block','quad')])
EOF
grep -n "fn native_gui_layer_pre\|fn native_gui_layer_post\|fn native_camera\|fn native_block(" \
  $P/crates/horizon-client/src/game/native_hooks.rs
grep -n "fn beam_color" -A12 $P/crates/horizon-client/src/game/beacon.rs
grep -n "pub struct BlockProperties" -A20 $P/crates/horizon-mods/src/content.rs
grep -n "fn note_block_instrument" -A18 $P/crates/horizon-world/src/level/shapes.rs
```

## Not in scope

No `.hmod` rebuild, no `stage/check/test/e2e`, no `compatibility.json` edit. The port has no
`[[injection]]`, so the repin migration is the shared recipe only.
