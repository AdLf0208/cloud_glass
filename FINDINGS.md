# Cloud Glass — upstream findings

Analysis of the original Java repository, read to write a clean-room Rust
content port. The port does not copy or translate Java code; the textures,
models and lang are the mod's own MIT assets and are carried byte for byte.

## Identity and version

| | |
|---|---|
| Mod | Cloud Glass |
| Repository | <https://github.com/Mrbysco/CloudGlass> |
| Branch cloned | `main` (the repository has no `1.21` or `26.x` branch; `git branch -a` lists only `origin/main`) |
| Commit | `cdfe025f71d382527dad6bd8051d5a9bd4a350cc` (2026-10-10, "Increment version [build] [publish]") |
| `gradle.properties` | `mc_version=1.21.1`, `neo_version=21.1.252`, `mod_id=cloudglass`, `version=1.1.0` |
| ATM10 pack row | `cloudglass, Cloud Glass, 1.1.0` (`horizon/docs/modpacks/atm10-mods.csv`); matches the repository |
| Licence | MIT, `Copyright (c) 2024 Mrbysco` (`LICENSE`); `neoforge.mods.toml` says `license="MIT"` |
| Modrinth id | `6SJ1bO6n` (matches `ports/_shared/source-map/atm10-sources.csv`) |
| CurseForge id | `1157074` |

There is no 26.x branch: 1.1.0 targets 1.21.1/NeoForge 21.1.252. The port
therefore adapts the 1.1.0 assets and data to the 26.3 formats the pinned
Horizon loader reads (see `../notes.md`).

## Files and areas read

```
src/main/java/com/mrbysco/cloudglass/
  block/CloudGlassBlock.java
  registry/CloudRegistry.java
  CloudGlassMod.java
  client/ClientTick.java
  datagen/server/CloudLootProvider.java
  datagen/server/CloudRecipeProvider.java
  datagen/client/CloudBlockstateProvider.java
  datagen/client/CloudItemModelProvider.java
  datagen/client/CloudLanguageProvider.java
  datagen/CloudDataGenerator.java
src/main/resources/META-INF/neoforge.mods.toml
src/main/resources/assets/cloudglass/lang/{pt_br,tr_tr}.json
src/main/resources/assets/cloudglass/textures/block/*.png
src/main/resources/assets/cloudglass/textures/block/transparent/*.png
src/generated/resources/**  (blockstates, models, lang, 31 recipes, 16 loot tables)
```

## Behaviours extracted

1. **Sixteen blocks, one per vanilla dye colour** (`CloudRegistry.java:14-46`),
   ids `cloudglass:<colour>_cloud_glass` in `white, orange, magenta,
   light_blue, yellow, lime, pink, gray, light_gray, cyan, purple, blue,
   brown, green, red, black` order. There are **no panes**: the 1.1.0
   registry, blockstates and models only define the sixteen blocks (the
   dispatch's "blocks/panes" was an assumption; the README says "16
   semi-opaque, no-collision decorative blocks").
2. **Block properties** (`CloudRegistry.java:31-45`): `mapColor(color)`,
   `instrument(NoteBlockInstrument.HAT)`, `strength(0.3F)` (0.3 hardness and
   0.3 explosion resistance), `sound(SoundType.GLASS)`, `noOcclusion()`,
   `noCollission()`, `isValidSpawn(false)`, `isRedstoneConductor(false)`,
   `isSuffocating(false)`, `isViewBlocking(false)`.
3. **Class** (`CloudGlassBlock.java:14-45`): `TransparentBlock` implementing
   `BeaconBeamBlock` (`getColor()`) and `LiquidBlockContainer` with both
   `canPlaceLiquid`/`placeLiquid` returning false, i.e. **not waterloggable**.
   `getTintRgb()` returns `color.getTextureDiffuseColor() & 0xFFFFFF`.
4. **Creative tab** (`CloudRegistry.java:48-58`): one tab titled
   `itemGroup.cloudglass.tab`, icon `light_blue_cloud_glass`, listing every
   registered block, inserted before `CreativeModeTabs.SPAWN_EGGS`.
5. **Loot** (`CloudLootProvider.java:29-34`): `dropSelf` for every block; the
   generated tables are a single `survives_explosion` pool.
6. **Recipes** (`CloudRecipeProvider.java:32-78`): 31 shaped recipes.
   - `cloudRecipe`: pattern ` W ` / `WGW` / ` W `, `W` = that colour's
     `minecraft:<colour>_wool`, `G` = `Tags.Items.GLASS_BLOCKS_COLORLESS`,
     result 4 blocks; one per colour including white.
   - `dyeRecipe`: pattern `CCC` / `CDC` / `CCC`, `C` =
     `cloudglass:white_cloud_glass`, `D` = `Tags.Items.DYES_<COLOUR>`, result
     8 blocks; one per colour except white (15).
7. **Assets** (`CloudBlockstateProvider.java:24-31`,
   `CloudItemModelProvider.java:23-36`): every block is a single-variant
   `cubeAll` with `renderType("translucent")`; the item model is a parent of
   the block model. `CloudLanguageProvider.java:20-38` adds
   `block.cloudglass.<name>` and the tab title.
8. **Screen tint** (`ClientTick.java:24-43`): a client `RegisterGuiLayersEvent`
   overlay fills the screen with ARGB `0x80` + `getTintRgb()` when the
   player's eye block is a `CloudGlassBlock`. This is client rendering, not
   content.
9. **Textures**: the sixteen top-level `textures/block/<name>.png` are solid
   colour with alpha 163 (0.64). The extra `textures/block/transparent/*.png`
   set (alpha 102) is **referenced by no model, blockstate, recipe or Java
   code** in 1.1.0; it is not carried.

## Where the rewrite differs

- **Template choice.** 26.3 has no single-state vanilla block that is
  simultaneously collision-free, non-occluding, `MODEL`-rendered and has an
  item, so the port declares the blocks on `minecraft:cobweb`: its collision
  table is empty, `can_occlude` is false, it renders a `MODEL`, and its one
  state carries an item. Its `WebBlock` slowdown is keyed on the literal
  block name `"minecraft:cobweb"` in the pin (`motion.rs:1763`,
  `entities.rs:462`, `game.rs:5611`), so a `cloudglass:*` block is not
  slowed. The residual template facts are recorded in `../notes.md`
  (light dampening 1, pistons pop it).
- **Beacon beam colour** is not reproducible from content: the pin derives
  beam colours from `minecraft:*_stained_glass` names.
- **Screen tint** needs a GUI-layer render hook; the pin (`c9d474d`) has no
  `gui_layer_pre`/`gui_layer_post` and no `draw_quad` helper.
- **Note-block instrument HAT** has no field in the content block schema.
