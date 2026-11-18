# Cloud Glass — port notes

Ported from **Cloud Glass 1.1.0** (`Mrbysco/CloudGlass`, branch `main`, commit
`cdfe025f71d382527dad6bd8051d5a9bd4a350cc`, `gradle.properties:17`) for
Minecraft Java 26.3 on Horizon **c9d474d** / horizon-mixins **d9c83d7**. The
ATM10 pack row is `cloudglass, Cloud Glass, 1.1.0` (same version).

**Licence: MIT** (`LICENSE`, `Copyright (c) 2024 Mrbysco`;
`neoforge.mods.toml` says `license="MIT"`). Local-only until the maintainer
approves publishing (ARCHITECTURE.md §8).

> **Current package (2026-11-18):** the port is one flat SDK `.hmod` at
> `ports/cloudglass/cloudglass.hmod`, version **0.2.0**, API `native-1/0b14f8a/e59da90`.
> The `.hnmod` container below is retired (Horizon's mod-API merge); its tree is kept
> under `../_shared/evidence/cloudglass/retired-hnmod-0.1.0/`. The migration record —
> file map, the hook mapping, the trap list and the supersede text for PR #907 — is
> the last two sections of this file.

Status: **slice 1 implemented and verified in-game.** Cloud Glass is a
content-only mod: sixteen semi-transparent, no-collision decorative blocks,
their two shaped recipe families, loot, lang and one creative tab. There is no
gameplay hook and no block entity. The full `stage → check → test → build`
ladder is green with 0 warnings, and the fail-capable in-game e2e passes in its
default and counterfactual modes while the negative control fails as required.

## Scope

Upstream 1.1.0 registers **sixteen blocks**, one per vanilla dye colour
(`CloudRegistry.java:14-46`). The dispatch's "blocks/panes" was an assumption:
the repository has **no panes** — no pane block, blockstate, model, recipe or
lang key exists in 1.1.0. The README calls the mod "16 semi-opaque,
no-collision decorative blocks". The port therefore ships the sixteen blocks
and nothing else. Details and file:line evidence are in
[`FINDINGS.md`](FINDINGS.md).

| # | id | MapColor |
|---|---|---|
| 1 | `cloudglass:white_cloud_glass` | 8 (SNOW) |
| 2 | `cloudglass:orange_cloud_glass` | 15 |
| 3 | `cloudglass:magenta_cloud_glass` | 16 |
| 4 | `cloudglass:light_blue_cloud_glass` | 17 |
| 5 | `cloudglass:yellow_cloud_glass` | 18 |
| 6 | `cloudglass:lime_cloud_glass` | 19 |
| 7 | `cloudglass:pink_cloud_glass` | 20 |
| 8 | `cloudglass:gray_cloud_glass` | 21 |
| 9 | `cloudglass:light_gray_cloud_glass` | 22 |
| 10 | `cloudglass:cyan_cloud_glass` | 23 |
| 11 | `cloudglass:purple_cloud_glass` | 24 |
| 12 | `cloudglass:blue_cloud_glass` | 25 |
| 13 | `cloudglass:brown_cloud_glass` | 26 |
| 14 | `cloudglass:green_cloud_glass` | 27 |
| 15 | `cloudglass:red_cloud_glass` | 28 |
| 16 | `cloudglass:black_cloud_glass` | 29 |

## Behaviour

Each colour has:

- a `CloudGlassBlock` (`CloudGlassBlock.java:14-45`): `TransparentBlock` with
  `noCollission()`, `noOcclusion()`, `isValidSpawn(false)`,
  `isRedstoneConductor(false)`, `isSuffocating(false)`, `isViewBlocking(false)`,
  `strength(0.3F)`, `sound(SoundType.GLASS)` and `mapColor(dye)`
  (`CloudRegistry.java:31-45`); not waterloggable (`canPlaceLiquid`/
  `placeLiquid` return false);
- a self-drop loot table (`CloudLootProvider.java:29-34`);
- the shaped wool recipe ` W `/`WGW`/` W ` → 4 blocks, and (except white) the
  dye recipe `CCC`/`CDC`/`CCC` → 8 blocks (`CloudRecipeProvider.java:32-78`);
- a `cube_all` blockstate and translucent model (`CloudBlockstateProvider.java:24-31`),
  the block model as its item model (`CloudItemModelProvider.java:23-36`), and
  the `block.cloudglass.<name>` lang key (`CloudLanguageProvider.java:20-38`);
- membership of the one creative tab (`CloudRegistry.java:48-58`).

## Content adaptations to 26.3

All recorded because the pin does not read the 1.21.1 shapes blindly:

1. **Item model definitions.** 1.21.1 generated only `models/item/*`; 26.3
   needs `assets/cloudglass/items/*.json`. Each points at its block model,
   exactly as the upstream item model's parent did.
2. **Translucency.** 1.21's `render_type: "minecraft:translucent"`
   (`CloudBlockstateProvider.java:27`) became 26.3's
   `{"sprite": ..., "force_translucent": true}` on the `cube_all` texture
   reference, exactly as vanilla `minecraft:glass` does.
3. **Recipes** are rewritten to the 26.3 `"#tag"`/string ingredient and
   `{id, count}` result shape. The 1.21 `{"tag":...}` object form is not
   parsed by the pin's `Ingredient::parse`.
4. **Loot tables** put `{"type":"minecraft:survives_explosion"}` on the pool;
   the 1.21 `conditions` array is not read by the 26.3 loot loader.
5. **Convention tags.** 26.3 ships no `c:` tags. The recipes name
   `c:glass_blocks/colorless` and `c:dyes/<colour>`; the port supplies those,
   plus the aggregate `c:dyes` and the `c:glass_blocks`/`c:glass_blocks/tinted`
   sets NeoForge also had. The cloud glass blocks themselves are **not** added
   to a tag, because upstream's datagen has no tag provider.
6. **Creative tab.** One `cloudglass` tab with the sixteen items replaces
   upstream's insertion before the spawn-egg tab (Horizon content mods cannot
   insert into vanilla tabs).
7. **Template.** The blocks are declared on `minecraft:cobweb`. It is the only
   26.3 vanilla block with a single state, an empty collision table,
   `can_occlude: false`, a `MODEL` render shape and an item, i.e. the only one
   that can carry a walk-through translucent cube. Its `WebBlock` slowdown is
   keyed on the literal block name `"minecraft:cobweb"` in the pin
   (`motion.rs:1763`, `entities.rs:462`, `game.rs:5611`), so a `cloudglass:*`
   block is not slowed — proved in the e2e with a vanilla cobweb differential.
8. **Unused textures.** The upstream `textures/block/transparent/*.png` set is
   referenced by no model, blockstate, recipe or Java code in 1.1.0 and is not
   carried; the sixteen used textures are copied byte for byte.

## Runtime

There is no gameplay logic and no hook. `mixins/cloudglass/runtime.rs` is a
**test-only** model (the whole module is `#[cfg(test)]`, so the injected copy
is empty in a normal game build and adds no dead code): it pins the sixteen
colour names, their vanilla `DyeColor` map colours, the block-id shape and the
template choice. **6 tests**, the same count the content generator reads.

The native bundle exists only to run those tests at the pin; the deliverable is
the `.hmod`. There is no `[[injection]]`.

## Verification

### Runtime (standalone crate)

| Check | Command | Result |
|---|---|---|
| fmt | `cargo fmt --all -- --check` | exit 0 |
| clippy | `cargo clippy --all-targets --locked --offline -- -D warnings` | exit 0, **0 warnings** |
| tests | `cargo test --locked --offline` | exit 0, **6 passed**, 0 failed |

TDD red/green: the six registry tests were written against an empty
`COLOURS` table and failed 6/6 (`left: 0, right: 16/15`); the table and its
lookups were then implemented and the suite went 6/6 green.

### Staged pin (`stage → check → test → build → ctl`)

`HORIZON_MIXINS=…/horizon-mixins python3 tools/horizon.py <step> --horizon
…/horizon` with `CARGO_INCREMENTAL=0 CARGO_BUILD_JOBS=2`, one step at a time.

| Step | Result |
|---|---|
| stage | exit 0, `stage_changed: true`, revision `c9d474dd…`, 270 s |
| check | `cargo_exit: 0`, **0 warnings**, 20 min |
| test | `cargo_exit: 0`, **6 passed; 0 failed; 531 filtered out**, **0 warnings** (`target/horizon-test.log`, filter `game::cloudglass::tests`) |
| build | `cargo_exit: 0`, **0 warnings**, 66 min, `target/horizon-cargo/fast/horizon-client` (81,601,376 B) |
| ctl | exit 0, 255 s, `target/horizon-cargo/fast/horizon-ctl` |

### Content

| Check | Command | Result |
|---|---|---|
| build | `cargo-horizon-mod build` (from `content/`) | exit 0 |
| check | `cargo-horizon-mod check cloudglass.hmod` | exit 0, `cloudglass 1.1.0 (mod, API 0.2, both)`, **45,467 bytes**, SHA-256 `3039469827865115055543476d1a2abe89cddcd7aea903d6d7193227bf0a8ab6`, unsigned, **155 files**, "no code: content only" |

Delivered `.hmod`: [`content/cloudglass.hmod`](content/cloudglass.hmod),
**45,467 bytes**, SHA-256
`3039469827865115055543476d1a2abe89cddcd7aea903d6d7193227bf0a8ab6`
(verified on the delivered file with `sha256sum`).

### In-game e2e (`tools/e2e.sh`, offscreen renderer, The End)

| Run | Result |
|---|---|
| default | exit 0: 16/16 states bind; 16/16 items give; the tab lists 16; four sampled blocks drop themselves; the wool + glass and white + dye recipes craft while both stick controls stay empty; walking through cloud glass matches air (8.37 vs 8.37 blocks in 2 s) while vanilla glass stops at 1.20 and vanilla cobweb slows to 2.09; three block items place; unknown ids are refused (`/tmp/opencode/cloudglass-e2e-default.log`) |
| counterfactual (`COUNTERFACTUAL=1`) | exit 0: vanilla glass drops nothing without silk and no Cloud Glass item, vanilla white wool drops itself and no Cloud Glass item, and vanilla glass blocks the walk at 1.20 (`/tmp/opencode/cloudglass-e2e-counterfactual.log`) |
| negative (`COUNTERFACTUAL=1 NEGATIVE=1`) | exit 1, as required: the false claim that vanilla glass drops a Cloud Glass block did not hold (`cloudglass glass=0`) (`/tmp/opencode/cloudglass-e2e-negative.log`) |

State/drop table (default run):

| set | colours | state bind | drop |
|---|---|---|---|
| cloud glass | 16 | 16/16 (one state each) | plain pickaxe: 1 of itself |

The movement differential is the fail-capable core: the same 2 s walk from
`(0.5, 80, 10.5)` through a 3×3 block wall gives **8.37** blocks through air,
**8.37** through cloud glass, **1.20** through vanilla glass (stopped) and
**2.09** through vanilla cobweb (slowed, the control that proves the
displayed block is not inheriting WebBlock's `entityInside`).

## Gaps and deviations

1. **No panes.** Upstream 1.1.0 has no pane block, blockstate, model, recipe
   or lang key; the dispatch's "blocks/panes" was an assumption. The port
   ships the sixteen blocks the README and registry define.
2. **Template facts.** `minecraft:cobweb` is the only 26.3 block with a single
   state, an empty collision table, `can_occlude: false`, a `MODEL` render
   shape and an item. Two template facts differ from upstream's
   `noOcclusion()`: `dampening` is 1 and `skylight_down` is false (vanilla
   glass is 0/true), so cloud glass slightly attenuates skylight; and
   `push` is `POPPED`, so pistons pop it rather than push it. The `WebBlock`
   class is present but its slowdown is keyed on the literal block name
   `"minecraft:cobweb"` at the pin, so a `cloudglass:*` block is not slowed —
   proved by the e2e's cobweb differential.
3. **Screen tint blocked.** Upstream 1.1.0 (`ClientTick.java:24-43`) draws a
   client GUI overlay (`0x80` + the dye's texture diffuse colour) when the
   player's eye is inside a cloud glass block. The pin (`c9d474d`) has no
   `gui_layer_pre`/`gui_layer_post` hook and no `draw_quad` helper, so the
   content port cannot implement it. Issue shape: a client GUI-layer render
   hook with a coloured quad and a block-at-eye read.
4. **Beacon beam tint not reproducible from content.** Upstream implements
   `BeaconBeamBlock.getColor()`; the pin derives beam colours from the
   `minecraft:*_stained_glass` name and the vanilla dye list, and a content
   block cannot override `getColor()`. Cosmetic only.
5. **Note-block instrument.** Upstream sets `NoteBlockInstrument.HAT`; the
   content block schema has no instrument field, so the note-block pitch
   differs. Cosmetic/audio only.
6. **Content `c:` tags are registry-invisible to commands.** The recipes
   resolve `#c:glass_blocks/colorless` and `#c:dyes/<colour>` (crafted in the
   e2e), but `/execute if block|items` validates its tag argument against the
   game registry's vanilla tags only and refuses `c:glass_blocks/colorless`
   (`Unknown block tag`). The e2e records that pin limitation instead of
   pretending a command proves the tags.
7. **Map colour not visually checked.** The declarations carry the vanilla
   `DyeColor` map colours, but the headless run did not open a map.
8. **Unused upstream textures.** The `textures/block/transparent/*.png` set
   (alpha 102) is unreferenced in 1.1.0 and is not shipped; the sixteen used
   textures are byte-for-byte copies.
9. **Loot table shape.** 1.21's `conditions` array became 26.3's pool
   `condition`; the drop is upstream's `dropSelf` (`survives_explosion`).
   Proven by mining four sampled colours with a plain pickaxe.
10. **Recipe book index.** The pin's `RecipeIndex` reads
    `data/minecraft/recipe` only, so `/recipe give` does not list mod recipes;
    the crafting table is the evidence (both shapes craft, both controls stay
    empty).

## Files

```
Cargo.toml, Cargo.lock, compatibility.json, LICENSE, rust-toolchain.toml,
.gitignore, README.md
mixins/cloudglass/horizon-mixin.toml   1 module, 0 injections
mixins/cloudglass/runtime.rs           test-only colour registry, 6 tests
content/horizon-mod.toml               API 0.2, registries, both
content/cloudglass.hmod                delivered 45,467-byte content mod
content/assets/cloudglass/             16 blockstates, 16 block models,
                                      16 26.3 item definitions, 16 textures,
                                      3 lang files
content/data/cloudglass/horizon/       16 block declarations, 1 creative tab
content/data/cloudglass/loot_table/    16 self-drop tables
content/data/cloudglass/recipe/        31 recipes
content/data/c/tags/                   23 convention tag files
tools/gen_content.py                   reproduces the content from upstream
tools/craft_check.py                   the wool/glass and white/dye table checks
tools/e2e.sh                           default/counterfactual/negative runs
tools/horizon.py                       stage/check/test/build/ctl ladder
notes.md, FINDINGS.md (upstream analysis)
```

## Skills used

- Superpowers: `test-driven-development` (the six registry tests were red
  against an empty table, then green), `systematic-debugging` (the
  `execute if items/block` tag-parser limitation was traced to the registry
  tag check in `horizon-command/src/item.rs`, and the movement differential
  was measured before it was asserted), and `verification-before-completion`
  (every claim re-run and logged).
- Beautiful Rust: `ports/_shared/skills/BeautifulRust/skills/rust-best-practices/SKILL.md`;
  `cargo fmt`, `cargo clippy --all-targets --locked --offline -- -D warnings`,
  `cargo test --locked --offline` clean; no `allow`/`expect` needed.

## Re-pin to Horizon `1d63e0a` and artifact rebuild (2026-11-09)

Mode A migration: the port pinned `83ad384f` and shipped only the `.hmod`; the
`.hnmod` half is new. The stamped hook catalog is byte-identical between the two
pins, so every injection, module and binding is unchanged; only the pin identity
moved.

| | Before | After |
|---|---|---|
| Horizon | `83ad384f48d0742746d518737511882680aab5b7` | **`1d63e0a5a37a7a708eb0b32b49bf0dfeb28ed8a9`** |
| horizon-mixins | `e8cd0aa38cffef49cb2e088ef716baa107148c02` | **`5a64af938ec86b00d53d16a408aabc0038fb3e57`** |
| `game.rs` SHA-256 | `996432b9f7f9461fa69c90ff798daf6b89fe3795f379d7c6f401916633296463` | `64813cf4db0b9c3983d42908609bb633b9fbbc705f0c890396f940a6c7cef80f` |

### Ladder (through `ports/tools/build-slot.sh`, `CARGO_INCREMENTAL=0`)

| Step | Result |
|---|---|
| `cargo fmt` + `--check` | exit 0 |
| `cargo clippy --all-targets -- -D warnings` | exit 0, **0 warnings** |
| `cargo test --locked --offline` | **7 passed**, 0 failed |
| `horizon.py stage` | exit 0 at `1d63e0a` |
| `horizon.py check` | `cargo_exit: 0`, **0 warnings** (53 s) |
| `horizon.py test` | **7 passed**, 1240 filtered |
| `horizon.py build` (fast) | `cargo_exit: 0` (574 s) |

### Delivered artifacts (reproducible)

| File | Size | SHA-256 | Entries |
|---|---:|---|---:|
| `content/cloudglass.hmod` | 45,467 B | `3039469827865115055543476d1a2abe89cddcd7aea903d6d7193227bf0a8ab6` | 155 |
| `cloudglass.hnmod` | 5,108 B | `4231e4936578d51c8aa30ef059efb71a1554c2d0ad276e31d04ebad622541226` | 5 |

The `.hmod` is built and checked by the pin's own `cargo-horizon-mod`
(`no code: content only`); the `.hnmod` is `tools/package.py`'s deterministic
archive. A second `tools/package.sh` run reproduced both hashes.

### In-game e2e (fast build, shared `horizon-ctl`)

`e2e.log` shows every content phase passing (16/16 states bound, 16 items,
creative tab, drops, recipes, tags, walking through cloud glass vs vanilla glass,
placement) and `e2e-negative.log` failing by design (`COUNTERFACTUAL=1
NEGATIVE=1` asserts a false drop claim). **Open — blocked on an engine behaviour:** the last phase (the HUD eye tint,
`gui_layer_pre`) does not move the screenshot's mean colour at this pin
(`orange distance` 201.8 off / 194.7 tinted, needs > 30).

Root cause, measured (2026-11-09, `target/last-game.log` from the diagnostic
build): the hook **does** fire — all twelve vanilla layers arrive
(`minecraft:crosshair` … `minecraft:chat`) — but
`game.native_camera()` returns `None` inside `gui_layer_pre` at `1d63e0a`, so
`on_gui_layer_pre` returns before it can read the block. The pin's own doc
comment on `native_camera` says "The most recently extracted world frame's
camera, if one exists. During GUI rendering this is the current frame"
(`game/native_hooks.rs:11064-11067`); at this pin the HUD pass runs with the
frame camera cleared, so the documented contract does not hold. The diagnostic
build logged, for every layer:

```
[cloudglass] hud layer 'minecraft:crosshair' #0 camera None block None
… #1 'minecraft:hotbar' … #11 'minecraft:chat' — all camera None
```

That is a named-hook/helper gap, not a port defect: the tint needs the eye
position (or the eye block) inside a GUI hook. Issue shape: *"`native_camera`
must be the current frame's camera during `gui_layer_pre`/`gui_layer_post`, or a
`native_eye_block()` helper for HUD layers"*. Until it lands the overlay is
inert at this pin; the blocks, items, recipes, drops, collision and craft
behaviour all pass in-game. The delivered `.hnmod` is the clean source (the
diagnostic was removed afterwards; the only difference from the tested build is
the removed `log::info!` lines).

Skills: superpowers/using-superpowers,verification-before-completion,systematic-debugging; BeautifulRust/rust-best-practices

> **2026-11-10 (after this record).** A parallel campaign session converged this
> port to the registry's one-file rule by embedding the carried content in the
> `.hnmod` (`mixins/<id>/embedded_content.rs` + `mixins/<id>/data/<id>-content.hmod`).
> The `.hnmod` size/SHA-256 above is therefore from this job's split build and is
> **superseded** by that port's own later record; the pin migration, the ladder
> results and the e2e findings in this section describe the code that was tested
> here and remain the basis for the harness fixes listed.

## Port version `0.1.0` (2026-11-10, registry §1.7)

The artifacts and the registry entry carried the **original** mod's version
(`1.1.0`) while the port is partial. The upstream reviewer's rule
(`AGENT_PLAYBOOK.md` §1.7) is that `[[versions]]` carries the **port's** version,
so entry, file and release agree. This slice changes version strings only — no
behaviour, no content, no pin.

| Where | Before | After |
|---|---|---|
| `content/horizon-mod.toml` (`version`) | `1.1.0` | **`0.1.0`** |
| `mixins/cloudglass/horizon-mixin.toml` (`[mod] version`) | `1.1.0` | **`0.1.0`** |
| `tools/gen_content.py` (its `horizon-mod.toml` template) | `1.1.0` | **`0.1.0`** |
| `horizon-native.json` inside the `.hnmod` | `1.1.0` | **`0.1.0`** (from `[mod] version`) |

`tools/package.sh` gained one fix on the way: it now builds the `.hmod` **first**
and refreshes `mixins/cloudglass/data/cloudglass-content.hmod` from it before
running `tools/package.py`. The old order packaged the `.hnmod` first, and since
`package.py` refuses an embedded copy that differs from the built one, a version
bump would have either failed or shipped the previous content.

`Cargo.toml`/`Cargo.lock` keep their crate version `1.1.0` deliberately: that is
the standalone test crate, it is neither read by `tools/package*.py` nor shipped
in either artifact, and rewriting it would force a lockfile edit for no gain in
the entry. Everything the registry, the launcher and the release see is `0.1.0`.

### Delivered artifacts (reproducible, two `tools/package.sh` runs)

> **Superseded 2026-11-12 (review repairs):** these bytes predate the licence
> stamping. The delivered artifacts are the content `.hmod` **46,889 B**
> `1d727def…6fe5b` (157 entries) and the bundle **25,598 B** `3a3cc414…4953`
> (9 entries); see *Verification after the repairs* for the current proof.

| File | Size | SHA-256 | Entries |
|---|---:|---|---:|
| `content/cloudglass.hmod` | 45,467 B | `a1f23df87bc7d3d5040bd1f4bff596b3b2160bc1c1b62eb0582378b887d34a2c` | 155 |
| `cloudglass.hnmod` | 22,948 B | `c2f31cb3627c0cd604355924f01cfc3cd040aa301725ec9ad2778c1d2fe0392e` | 7 |

- `cmp content/cloudglass.hmod mixins/cloudglass/data/cloudglass-content.hmod` →
  byte-identical (the embedded copy is the built content mod).
- `cargo horizon-mod check cloudglass.hnmod --kind native-mod` → exit 0,
  `cloudglass 0.1.0 (native-mod, format native-1/1d63e0a5…/5a64af93…, for 26.3)`.
- `cargo horizon-mod check content/cloudglass.hmod` → exit 0,
  `cloudglass 0.1.0 (mod, API 0.2, both)`, "no code: content only".

### e2e re-run (required, not cosmetic)

`tools/e2e.sh` in `EMBEDDED=1` mode `cmp`s the `.horizon-cache` file the bundle
writes against `content/cloudglass.hmod`, and the bundle compiles that file into
the game (`native_data!`). A new `.hmod` therefore invalidates both the assertion
and the binary, so the leg was re-run through
`build-slot.sh e2e` (which rebuilds first): **PASS + EXIT:0**, the written file is
45,467 B and identical to `content/cloudglass.hmod`, and the no-embedded-file
control still has no cloud glass id. `check-e2e-logs.py cloudglass --strict` →
exit 0 (3/3 logs). No assertion was weakened; the HUD-tint engine gap stays as
recorded above (measured 194.8 vs off 201.8).

### Registry entry

`ports/_shared/horizon-mods/publish/cloudglass/registry.toml` `[[versions]]`:
`version = "0.1.0"`, `published = "2026-11-10"`, `file = "cloudglass.hnmod"`,
`sha256 = "3a3cc414…7074953"` (refreshed 2026-11-12 after the licence stamping;
it was `c2f31cb3…2fe0392e` before). The published tree was refreshed with that
artifact, `content/cloudglass.hmod`, `content/horizon-mod.toml`,
`mixins/cloudglass/horizon-mixin.toml`, `mixins/cloudglass/data/cloudglass-content.hmod`
and the changed tools; the prose, README and icon are unchanged.
`upstream_ready.py cloudglass` → exit 0 (`READY`).

## Review repairs (PR #618, 2026-11-11) — review items and what changed


Each item below is quoted from `ports/_shared/horizon-mods/reviews/pr-*-cloudglass.md` (the review is the specification), with what this repair did about it.

- **Reviewer:** attribution/description
  **Repair:** Rewritten: absolute upstream link, Mrbysco credited, the caveat finished, and the internal dispatch commentary replaced with player-visible limitations.
- **Reviewer:** licence notice
  **Repair:** Both archives now carry `Copyright (c) 2024 Mrbysco` and the MIT text.
- **Reviewer:** [P?] the eye overlay is inert and the harness passed anyway
  **Repair:** Disclosed as a limitation in the entry and the README: the tint is **not drawn** at this pin (`mixins/cloudglass/support.rs` returns without drawing when `native_camera()` is absent) and the harness reports it as a measured gap, not a pass. The harness leg *is* renderer-capable (`--offscreen` + `ctl screenshot`) and it fails if either a vanilla-glass eye or a wrong block tints the frame; the fresh run measured **cloud glass 194.9 vs off 202.1 vs vanilla glass 197.1** orange distance, i.e. no tint from either. The page claims exactly that and nothing more.
- **Reviewer:** registry artifact delivery
  **Repair:** **Staging (orchestrator, not ours)**: the artifact is not in registry release/staging as `<sha256>.<ext>`; the orchestrator answers it with `horizon-mods#686` (no write access to the registry's releases). Every repackaged artifact below has a fresh sha256 for that re-push, and the author release must be re-uploaded from the port repository.

### Verification after the repairs (2026-11-12)

Every step in a `ports/tools/build-slot.sh` lease with `CARGO_INCREMENTAL=0`.
`tools/package.sh` now runs `tools/stamp_license.py` before the build, so a
rebuild cannot produce a `.hmod` without the MIT notices (before this repair the
stamping was a manual step; the tree's `content/` did not carry the files). The
port's `tools/horizon.py` also gained the pin's paths as defaults
(`../_shared/pins/horizon-1d63e0a`, `../_shared/pins/horizon-mixins-5a64af9`);
the old `../horizon-mixins` default does not exist in this campaign tree.

| Check | Result |
|---|---|
| `tools/package.sh` twice (`--step package`) | both runs: content `cloudglass.hmod` **46,889 B** `1d727def…6fe5b`, 157 files, and `cloudglass.hnmod` **25,598 B** `3a3cc414…4953`, 9 entries; `cmp` identical on both artifacts |
| embedded copy | `cmp content/cloudglass.hmod mixins/cloudglass/data/cloudglass-content.hmod` → identical |
| notices in **both** archives | outer `.hnmod`: `mixins/cloudglass/LICENSE` (1,114 B, `Copyright (c) 2024 Mrbysco`) + `LICENSE-NOTICE.md` (802 B); embedded `.hmod`: `data/cloudglass/license/{license,notice}.txt` |
| `registry.toml` | `file = "cloudglass.hnmod"` exists beside it; `sha256 = 3a3cc414…4953` = `sha256sum` of that file |
| runtime | `cargo test --locked --offline` **7 passed**, 0 failed; clippy `-D warnings` clean; `cargo fmt --all --check` clean |
| ladder | `stage` → `check` → `test` → `build`, `cargo_exit 0` each, **0 warnings**; embedded tests `game::cloudglass::tests` **7 passed**, 1240 filtered out |
| e2e, default (renderer leg) | `e2e-repair.log`: **`PASS` + `EXIT:0`** — 16/16 states bind, 16 items, the tab, four self-drops, the two recipes with stick controls, the tags, walking equal to air vs vanilla glass stopping the player, placements, unknown ids, and the tint phase: **off 202.1, cloud glass 194.9, vanilla glass 197.1** orange distance → `GAP (engine)` printed, PASS line carries the gap wording |
| e2e, fail-capable | `e2e-repair-selftest.log`: **`FAIL` + `EXIT:1`** — `white cloud glass dropped 1, expected nothing`; `e2e-repair-negative.log`: **`FAIL` + `EXIT:1`** — the false vanilla-glass claim does not hold |
| e2e, embedded bundle (fresh) | `e2e-repair-embedded.log`: **`PASS` + `EXIT:0`** with no `--dev-mod`; the cache file is **46,889 B** and identical to `content/cloudglass.hmod`; the no-embedded-file control has no cloud glass id; same measured tint gap (194.9 / 202.0 / 197.0) |
| log audit | `check-e2e-logs.py cloudglass --strict` exit 0, **8/8** logs ok |
| skills gate | `check-skills.py --notes ports/cloudglass` → `SKILLS GATE: PASS` |
| upstream gate | `upstream_ready.py cloudglass` → `READY`, exit 0 |

**What the entry may claim about the overlay, and what it may not.** The
renderer leg proves the blocks, items, drops, recipes, tags, walking behaviour
and placements; for the overlay it proves only that standing inside cloud glass
does **not** tint the frame at this pin (and that vanilla glass does not either,
so the measurement is not block-specific). `support.rs:32-34` shows why: the
helper returns before drawing when `native_camera()` is absent in the HUD pass.
The entry and README say exactly that and call it a limitation; no text in the
port, the entry or the README claims a working tint.

Skills: superpowers/using-superpowers,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices

## Migration to the SDK format (2026-11-18, SDK `0b14f8a`)

*Format migration only: the behaviour, the carried content and the rules are unchanged.
This port was PR **#907**, closed on 2026-11-18 by the format purge (`.hnmod` retired);
this is its resubmission as a new version, **0.2.0**.*

**Why.** Horizon's mod-API merge (#16941, launcher ≥ 0.2.70) retired `.hnmod`; the registry
closed every `.hnmod` submission with *"republish this as a native `.hmod` with the SDK from
the next Nightly"*. The new unit is **one flat `.hmod`**: content, native code, or both. For
this port that is a simplification — the retired bundle existed only to embed the content
package (the AE2 pattern) and to run the test-only runtime at the pin; the flat package
carries `assets/` and `data/` inside itself and the runtime lives in `src/`.

- **Pins:** Horizon / SDK **`0b14f8acfd97fa2c750e42795249dcc981178ca4`** (nightly
  2026-11-18, package format **6**, content API **0.2**), horizon-mixins
  **`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`**. The SDK is fetched into `.horizon/sdk/`
  by `cargo horizon-mod` and never packed; `SHA256SUMS` was already verified in-tree
  (`ports/_shared/sdk/0b14f8a/`), and this port's copy is the same signed slice.
- **Version:** **0.2.0** (the retired bundle was 0.1.0; a resubmission is always a new
  version).
- **Class + tier unchanged: class `content`, tier `data`** (`atm10-sources.csv`; the
  ledger row already says `content,data`). The sixteen blocks are carried-over content;
  the only code is the colour-registry model, and the client overlay is still the one
  missing half (see "Gaps after the migration"). No machine/deep feature is added.
- **Approach from `docs/modpacks.md`:** §"4. Carry-over: data and assets" is the whole job —
  `assets/` + `data/` are copied byte for byte — and §"5. Code: one agent per mod" covers
  the small `src/` crate that keeps the carried model testable.

### Checklist — files created, files deleted

| Created | What it holds |
|---|---|
| `horizon-mod.toml` | the only manifest: `id = "cloudglass"`, `version = "0.2.0"`, `api = "0.2"`, `side = "both"`, `capabilities`, and `[native]` with the exact three pins |
| `Cargo.toml` | one crate (`mod-cloudglass`); the only dependency is `horizon-mod-api` from `.horizon/sdk/` |
| `src/lib.rs` | `pub mod runtime;` and the one `#[mod_api::horizon_mod] impl Hooks` — **empty**, because the mod has no game moment to answer |
| `src/runtime.rs` | the old `runtime.rs`, **byte-identical** (`cp`, then `cmp`; SHA-256 `3458a54d64a186c9e81521a9ef70dbb9895b3c7112fa3df5ff5a73edb6fc5331`, 283 lines) |
| `assets/cloudglass/**`, `data/**` | the retired content package's own tree, moved to the package root: 156 files, byte-identical (aggregate SHA-256 `f5f4ddcf…`) |
| `.gitignore` | `/target`, `/.horizon`, `/Cargo.lock` |
| `cloudglass.hmod` | the delivered package, port root |

| Deleted | Why | Where it went |
|---|---|---|
| `mixins/cloudglass/` (`horizon-mixin.toml`, `runtime.rs`, `support.rs`, `gui_layer.rs`, `embedded_content.rs`, `data/cloudglass-content.hmod`) | the plan/injection schema, per-hook helpers and the embedded copy are not part of any SDK package | `runtime.rs` → `src/`; the gui helper → a recorded gap (the surface changed, see the hook table); the embedded copy → nothing (the package carries `assets/` + `data/`) |
| `content/` (`horizon-mod.toml`, `cloudglass.hmod`, `assets/`, `data/`, `target/`) | a second package; the flat package carries content itself | `assets/` + `data/` at the root; the old manifest and artifact to evidence |
| `cloudglass.hnmod` | the retired container | evidence (`retired-hnmod-0.1.0/`) |
| `compatibility.json` | the pin is `[native]` in `horizon-mod.toml` | evidence |
| `rust-toolchain.toml` (1.95.0) | "not part of any new package"; the launcher builds against the SDK's own toolchain | evidence |
| `tools/horizon.py`, `tools/package.py`, `tools/package.sh` | the staged/mixin build and `.hnmod` packaging are gone | evidence |
| `Cargo.lock` | written by `cargo test`; packing it changes the artifact (trap 5) | not kept; `/Cargo.lock` is gitignored |
| `tools/__pycache__/` | stale bytecode | deleted |

Kept on purpose: `tools/e2e.sh` (the in-game oracle; its two `EMBEDDED=1` legs are
retired, `--dev-mod` now names the package), `tools/craft_check.py`, `tools/gen_content.py`
(repointed at the package root; it no longer writes the manifest), `tools/stamp_license.py`
(repointed at `data/cloudglass/license/`), `notes.md`, `FINDINGS.md`, `VALIDATION.md`,
`README.md` (rewritten for the flat layout), `LICENSE`, `LICENSE-NOTICE.md`,
`REPIN-AUDIT.md` (history).

### Package file map (164 entries)

| Path | Entries | Role |
|---|---:|---|
| `horizon-mod.toml` | 1 | the manifest and the only identity |
| `Cargo.toml` | 1 | the crate; `horizon-mod-api` path dependency only |
| `src/lib.rs` | 1 | the one `impl Hooks` (empty) + `pub mod runtime;` |
| `src/runtime.rs` | 1 | the carried pure model (byte-identical) |
| `assets/cloudglass/**` | 16 blockstates + 16 block models + 16 item definitions + 16 textures + 3 lang = 67 | the carried resource pack |
| `data/cloudglass/**` | 16 block declarations + 1 creative tab + 16 loot tables + 31 recipes + 2 licence notices = 66 | the carried data pack |
| `data/c/tags/**` | 23 | the convention tags the recipes need |
| `LICENSE`, `LICENSE-NOTICE.md`, `README.md` | 3 | the MIT text, provenance, and the shipping readme |
| `uses.json` | 1 | generated: `capability:registries`, `macro:horizon_mod`, `part:block`, `trait:Hooks` — **no `hook:` entry**, i.e. the package really answers no moment |

`check --json` reports `kind: "native-mod"`, `capabilities: []`, `side: null` (the
manifest's `side = "both"` is still required; the native report does not echo it).

### Runtime carry (the campaign rule)

`src/runtime.rs` is the retired `mixins/cloudglass/runtime.rs`, copied before that file was
moved to evidence: `cmp` clean, SHA-256
`3458a54d64a186c9e81521a9ef70dbb9895b3c7112fa3df5ff5a73edb6fc5331`, 283 lines, and the copy
inside the delivered `.hmod` hashes to the same value. Its **7 tests ran green before any
SDK glue existed** (`src/lib.rs` was `pub mod runtime;` alone: `unit-before-glue.log`), then
again with the `impl Hooks` in place (`unit.log`). Nothing in the module changed.

The module is test-only in its lower half (`#[cfg(test)] mod tests`), so the package's
non-test code is only `DIFFUSE` + `tint_for`; `pub mod runtime;` keeps them reachable, which
is why `cargo clippy --all-targets -- -D warnings` reports no `dead_code` (imfast trap 8).

### Helper → hook table

| Retired | SDK (0.2) | Where |
|---|---|---|
| `[[module]] runtime` (`runtime.rs`) | no plan section: `pub mod runtime;` | `src/lib.rs` |
| `[[module]] state` (`support.rs`) — the eye-overlay glue | **not implemented; recorded gap** | see "Gaps after the migration" |
| `[[injection]] gui-layer-pre` (`gui_layer.rs`, `gui_layer_pre` HEAD) | no method: the SDK's `Hooks::gui_layer_pre` would be the mapping, but this slice ships no client hook | gap: the surface exists, the proof needs a launcher-built game |
| `[[injection]] embedded-content` (`content_root` HEAD, AE2 pattern) | **deleted** — the flat package carries `assets/` and `data/` itself | — |
| `horizon-mixin.toml` `[[module]]`/`[[injection]]` | `horizon-mod.toml` + one `impl Hooks` | `horizon-mod.toml`, `src/lib.rs` |

There is no `Part` to attach: the sixteen blocks have no code half. The empty `impl Hooks`
is deliberate and measured (`cargo horizon-mod build`/`check` accept it) — a native package
whose behaviour is all content does not need an invented moment.

### Content carry (proof it is mechanical)

The retired `content/cloudglass.hmod` (46,889 B, 157 entries) and the new package were
compared entry by entry: **156 `assets/` + `data/` files on both sides, no file only in one,
no differing byte** (aggregate SHA-256 `f5f4ddcf…`). The licence notices already rode at
`data/cloudglass/license/{license,notice}.txt` and still do; `LICENSE`/`LICENSE-NOTICE.md`
also sit at the package root now, because the publish tree is not the package.

### Build and check (verbatim, in a build slot)

`build-slot.sh` speaks the old staged tool, so each command runs **directly in the port**
with `BUILD_LOCAL=1`, `CARGO_INCREMENTAL=0` and no `--target-dir`:

```sh
BUILD_LOCAL=1 ports/tools/build-slot.sh run --job sdk-cg --port ports/cloudglass --step test \
    -- bash -c 'cd ports/cloudglass && CARGO_INCREMENTAL=0 cargo test --offline'
# → test result: ok. 7 passed; 0 failed

BUILD_LOCAL=1 ports/tools/build-slot.sh run --job sdk-cg --port ports/cloudglass --step lint \
    -- bash -c 'cd ports/cloudglass && CARGO_INCREMENTAL=0 cargo clippy --all-targets --offline -- -D warnings
        && cargo fmt --check'
# → Finished `dev` profile … (0 warnings); CLIPPY_EXIT:0 FMT_EXIT:0

BUILD_LOCAL=1 ports/tools/build-slot.sh run --job sdk-cg --port ports/cloudglass --step build \
    -- bash -c 'cd ports/cloudglass && rm -f Cargo.lock && CARGO_INCREMENTAL=0 cargo horizon-mod build'
# → SDK 0b14f8a (build 0b14f8acfd97fa2c750e42795249dcc981178ca4) in ./.horizon/sdk
# → Built ./target/horizon-mod/cloudglass.hmod

BUILD_LOCAL=1 ports/tools/build-slot.sh run --job sdk-cg --port ports/cloudglass --step check \
    -- bash -c 'cd ports/cloudglass && cargo horizon-mod check cloudglass.hmod
        && cargo horizon-mod fits cloudglass.hmod --build nightly'
# → cloudglass 0.2.0 (native-mod, format native-1/0b14f8ac…/e59da909…, for 26.3)
# → 54752 bytes, SHA-256 4a8b9fb7…, unsigned    CHECK_EXIT:0
# → Cloud Glass: / 0b14f8a  made for               FITS_EXIT:0
```

### Traps (measured here; the next port should read these first)

1. **`build-slot.sh` does not `cd` into the port.** `--port` is a label and the cache-link
   target; a bare `cargo` from the campaign root fails with "could not find `Cargo.toml`".
   Every command is `bash -c 'cd ports/<id> && …'`.
2. **Do not declare `rust-version`.** The scaffold declares none; a `rust-version = "1.99"`
   makes cargo refuse the box's older stable. The SDK's 1.99.1 is what the launcher builds
   with, not a floor for the port crate. (Pre-empted, not hit.)
3. **A leftover old path refuses the package** (`unexpected package path: mixins/…`). The
   project root may hold only package paths, so `mixins/` and the `.hnmod` were moved to
   evidence **before** the first build. (Pre-empted, not hit.)
4. **`Cargo.lock` is packed and changes the artifact — measured.** With the 8,835 B lock:
   **57,092 B**, 165 entries, SHA-256 `88c1db7b…`; without: **54,752 B**, 164 entries,
   SHA-256 `4a8b9fb7…` (+2,340 B compressed). `cargo test`/`clippy` write the lock, so
   `rm -f Cargo.lock` immediately before the delivery build, and `/Cargo.lock` is ignored.
5. **`cargo horizon-mod check` with no file checks wasm**, not the package
   (`can't find crate for 'core' … wasm32-unknown-unknown`). Always `check <file.hmod>`.
   (Pre-empted, not hit.)
6. **`cargo fmt --all` formats the fetched SDK** (it is a path dependency). Use
   `cargo fmt --check`, never "fix" `.horizon/sdk/`. (Pre-empted, not hit.)
7. **An empty `impl Hooks` is valid.** For a package whose behaviour is all content, do not
   invent a hook to look native: the macro, `build` and `check` all accept
   `#[mod_api::horizon_mod] impl mod_api::Hooks for Mod {}`, and `uses.json` then contains no
   `hook:` entry. This is the honest record.
8. **The pins are 40 hex, and the mixins pin is not the old campaign pin** (`e59da909…`, not
   `5a64af93…`); a short hash reads as "native requires game and exact revisions" without
   saying which one is short.
9. **`check <file> --uses` printed only the report on this tool build.** The list is the
   package's own `uses.json` (`unzip -p cloudglass.hmod uses.json`), so read that rather
   than concluding `--uses` is broken.
10. **`build-slot.sh` deletes `stage/modded` per lease, but the port tree is not affected**;
    the SDK build writes `target/horizon-mod/`. Copy the artifact to the port root — a
    package that exists only in `target/` is not delivered.
11. **The e2e needs a launcher-built game.** `horizon-launcher native-build <port>` is not
    installed on this box and there is no game build at `0b14f8a` (the shared binaries are
    at `1d63e0a5`/`41f822b6`). The script is updated to `--dev-mod cloudglass.hmod` and has
    a STATUS header; the run is the next slice's first job.

## Migration verification (SDK `0b14f8a`)

Skills: superpowers/using-superpowers,writing-plans,test-driven-development,verification-before-completion; BeautifulRust/rust-best-practices

| Check | Command | Result |
|---|---|---|
| Runtime tests before glue | `cargo test --offline` with only `pub mod runtime;` | **7 passed**, 0 failed (`evidence/cloudglass/sdk-0b14f8a/unit-before-glue.log`) |
| Runtime tests with glue | `cargo test --offline` | **7 passed**, 0 failed (`unit.log`) |
| Lints | `cargo clippy --all-targets --offline -- -D warnings` | `CLIPPY_EXIT:0`, 0 warnings (`clippy.log`) |
| Formatting | `cargo fmt --check` | `FMT_EXIT:0` (`fmt.log`) |
| Package | `cargo horizon-mod build` (no `Cargo.lock`) | `target/horizon-mod/cloudglass.hmod`, EXIT 0 (`build.log`) |
| Reproducible | second build, `cmp` | byte-identical, same sha256 (`build-second.log`, `sha256-build1.txt`, `sha256-build2.txt`) |
| Registry check | `cargo horizon-mod check cloudglass.hmod` | `cloudglass 0.2.0 (native-mod, format native-1/0b14f8ac…/e59da909…, for 26.3)`, **54,752 B**, SHA-256 `4a8b9fb7617faacad05ce489793d47a321a528fd2290cc7549671837b40bc497`, **CHECK_EXIT:0** (`check.log`, `check-json.log`) |
| Fits the pinned build | `cargo horizon-mod fits cloudglass.hmod --build nightly` | `0b14f8a  made for`, **FITS_EXIT:0** (`fits.log`) |
| `runtime.rs` untouched | `unzip -p cloudglass.hmod src/runtime.rs \| sha256sum` | `3458a54d…5331` = the retired file, byte for byte (`runtime-carry.log`) |
| Content untouched | 156 `assets/`+`data/` entries vs the retired content package | same set, no differing byte (`package-entries.log`; aggregate `f5f4ddcf…`) |
| Lock trap | build with and without `Cargo.lock` | 57,092 B / `88c1db7b…` vs 54,752 B / `4a8b9fb7…` (`lock-trap.log`) |
| Skills line | `python3 ports/tools/check-skills.py --notes ports/cloudglass` | `SKILLS GATE: PASS` |

### Not re-run in this migration

- **The in-game e2e.** No `horizon-launcher` and no game build at `0b14f8a`; the last
  verified run is the retired bundle's (`evidence/cloudglass/e2e-*.log`, three legs, the
  movement differential and the counterfactual/negative controls). What changed is the
  *transport* of the same content (one flat package instead of a `.hnmod` + embedded
  `.hmod`), not the blocks, recipes, loot or tags, which are byte-identical. The first
  launcher-capable box runs `tools/e2e.sh` with `GAME=<launcher build>` and records it.
- **The staged ladder** (`stage`/`check`/`test`/`build` through `tools/horizon.py`) — those
  tools are retired with the format.

### Gaps after the migration

1. **The client eye overlay is still missing — and the SDK has moved the surface.**
   Upstream `ClientTick.java:24-43` fills the frame with the dye's diffuse colour at alpha
   `0x80` while the eye is inside a cloud-glass block. At `1d63e0a` the retired injection
   *did* fire but `native_camera()` returned `None` in the HUD pass (measured, see the
   2026-11-09 record above), so the overlay was inert. At `0b14f8a` the surface is
   different and explicitly documented: `Hooks::gui_layer_pre(host, event)` with
   `event.layer`, `event.draw: &mut dyn DrawContext` (`fill`, `size`), and
   `ClientViewHost::camera()` whose doc says *"During GUI rendering this is the current
   frame, including bob/spin and FOV"*; a block read is `LevelsHost::level_block(level,
   pos)` and the colour is already in `runtime::tint_for`. What this slice lacks is a
   **launcher-built game at the pin** to prove the screenshot differential, and a decision
   on the client-level handle at the HUD moment (`level_block` is `WorldOnly`). So it is
   recorded, not faked: the next slice implements the overlay and proves it with
   `tools/e2e.sh`'s tint phase (which fails if vanilla glass tints and records a GAP
   otherwise). Issue shape is now a *port* task, not an engine gap.
2. **Beacon beam tint** — a content block cannot override the beam colour (the pin derives
   it from the `minecraft:*_stained_glass` name). Cosmetic only; unchanged from 0.1.0.
3. **Note-block instrument** — the content block schema has no instrument field; the pitch
   differs. Cosmetic/audio only.
4. **`c:` tags are registry-invisible to commands** — recipes resolve
   `#c:glass_blocks/colorless` / `#c:dyes/<colour>` (crafted in the e2e), but
   `/execute if block|items` validates its tag argument against the vanilla registry only.
   Pin limitation, recorded.
5. **Map colour not visually checked** — the declarations carry the vanilla `DyeColor` map
   colours; no map was opened in a run.
6. **No `title`-style creative-tab insertion** — one `cloudglass` tab, as in 0.1.0.
7. **The template facts** (`minecraft:cobweb`: `dampening` 1, `skylight_down` false, pistons
   pop it) are unchanged from 0.1.0; the `WebBlock` slowdown is name-keyed, so cloud glass
   is not slowed (proved in the 0.1.0 e2e's cobweb differential).

### Changelog for the resubmission

> Supersedes **#907**, closed because Horizon retired `.hnmod` (#17992). Changes: one flat
> SDK package with `api = "0.2"` and `[native]` pinned to `0b14f8a` / `e59da90`; the
> sixteen blocks, their models, textures, lang, loot, recipes, tags and licence notices now
> ship inside the package's own `assets/` and `data/` instead of a second embedded `.hmod`
> written from a `content_root` injection, so that injection and its `.horizon-cache` write
> are gone; `src/lib.rs` is the single `impl Hooks` (empty — this mod's behaviour is its
> content, and the client eye tint remains the recorded gap); `src/runtime.rs` and its 7
> tests are byte-identical to the retired bundle's. Version **0.2.0**.
