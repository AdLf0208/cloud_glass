# Validation

> **Current package (2026-11-20, SDK `0b14f8a`).** One flat `.hmod`:
> `cloudglass.hmod` **55,220 B** SHA-256
> `af0a220fda3d19b06fe3803d56cacdd84d0140f50687bf8084476dd5f8effc5c`, version
> **0.2.1**, 164 entries. `cargo test` **8/8**, clippy/fmt clean, `check` and
> `fits` EXIT 0, `verify-sdk-package.py` **1/1**, and the **in-game leg** is green
> on a launcher-built game at the pin (`PASS` + `EXIT:0`) with its control leg at
> `EXIT:1` and `check-e2e-logs.py cloudglass-e2e --strict` 6/6. See
> `notes.md` *Slice 2 — the in-game leg at SDK `0b14f8a`*. Everything below it is
> history.

> **2026-11-18 (SDK format migration).** One flat `.hmod`: **54,752 B** SHA-256
> `4a8b9fb7…bc497`, version 0.2.0, 164 entries; `cargo test` 7/7,
> `src/runtime.rs` byte-identical (`3458a54d…5331`). Superseded by the 0.2.1
> package above, which adds the in-game leg and one runtime test.

> **2026-11-12 (review repairs, PR #618).** The delivered bytes are now the
> content `.hmod` **46,889 B** `1d727def…6fe5b` (157 files, including
> `data/cloudglass/license/`) and the bundle **25,598 B** `3a3cc414…4953`
> (9 entries). Earlier sections below record older builds; `notes.md`,
> *Verification after the repairs*, has the fresh ladder and e2e evidence.

## 2026-11-09 — Horizon `1d63e0a`, both artifacts

Horizon `1d63e0a5a37a7a708eb0b32b49bf0dfeb28ed8a9` + horizon-mixins
`5a64af938ec86b00d53d16a408aabc0038fb3e57`, every step through
`ports/tools/build-slot.sh` with `CARGO_INCREMENTAL=0`.

| Check | Result |
|---|---|
| `cargo fmt` + `--check`, `cargo clippy --all-targets -- -D warnings` | exit 0, 0 warnings |
| `cargo test --locked --offline` | 7 passed |
| `horizon.py stage` / `check` / `test` / `build` | exit 0; 0 warnings; embedded 7 passed |
| `tools/package.sh` | `.hmod` 45,467 B `30394698…0a8ab6` (155 entries), `.hnmod` 5,110 B `2f6a30f7…4288cd9` (5) |
| `tools/e2e.sh` | every content phase passes; the HUD tint phase is **blocked**: `native_camera()` is `None` inside `gui_layer_pre` at this pin (12 layers logged) |
| `COUNTERFACTUAL=1 NEGATIVE=1 tools/e2e.sh` | `FAIL` + `EXIT:1` by design |

Evidence: `ports/_shared/evidence/cloudglass/`.
`upstream_ready.py cloudglass` still blocks on the one-file-per-project registry rule.

## 2026-11-10 — port version `0.1.0` (registry §1.7)

The artifacts carried the **original** mod's version (`1.1.0`); the registry entry
must carry the **port's** version so entry, file and release agree. Only the
version string changed — no behaviour, no content, no pin.

| File | Change |
|---|---|
| `content/horizon-mod.toml` | `version = "0.1.0"` |
| `mixins/cloudglass/horizon-mixin.toml` | `[mod] version = "0.1.0"` |
| `tools/gen_content.py` | its `horizon-mod.toml` template writes `0.1.0` (a regeneration cannot revert it) |

`tools/package.sh` now builds the `.hmod` **before** the `.hnmod` and refreshes
`mixins/cloudglass/data/cloudglass-content.hmod` from it, because `tools/package.py`
refuses a stale embedded copy (the old order packaged first and would have shipped
the previous content).

| Check | Result |
|---|---|
| `tools/package.sh` × 2 (through `build-slot.sh run`) | both runs: `.hmod` 45,467 B `a1f23df8…873d4a2c` (155 entries), `.hnmod` 22,948 B `c2f31cb3…2fe0392e` (7 entries) — **identical bytes, reproducible** |
| embedded content | `cmp content/cloudglass.hmod mixins/cloudglass/data/cloudglass-content.hmod` → identical |
| `cargo horizon-mod check cloudglass.hnmod --kind native-mod` | exit 0, `cloudglass 0.1.0 (native-mod, …1d63e0a5/5a64af93, for 26.3)` |
| `cargo horizon-mod check content/cloudglass.hmod` | exit 0, `cloudglass 0.1.0 (mod, API 0.2, both)`, "no code: content only" |
| `EMBEDDED=1 tools/e2e.sh` (through `build-slot.sh e2e`, rebuilt binary) | `PASS` + `EXIT:0`; the embedded file the bundle writes is 45,467 B and `cmp`-identical to `content/cloudglass.hmod`; the no-embedded-file control still has no cloud glass id (`evidence/e2e-embedded.log`) |
| `check-e2e-logs.py cloudglass --strict` | exit 0, 3/3 logs ok |
| `upstream_ready.py cloudglass` | exit 0, `READY` |

The e2e was re-run because `tools/e2e.sh` compares the cache file the bundle
writes against `content/cloudglass.hmod`; a new `.hmod` changes those bytes, and
the game binary embeds the file at compile time (`native_data!`), so the binary
had to be rebuilt as well. No assertion was weakened.

Publish tree `ports/_shared/horizon-mods/publish/cloudglass/`: artifact + the
`horizon-mod.toml`, `horizon-mixin.toml` and embedded content it ships were
refreshed; `registry.toml` `[[versions]]` is `version = "0.1.0"`,
`sha256 = "c2f31cb3…2fe0392e"`, `published = "2026-11-10"`.


## 2026-11-18 — SDK `0b14f8a`, flat package 0.2.0

Every step in a `BUILD_LOCAL=1 ports/tools/build-slot.sh run` lease, directly in
the port with `CARGO_INCREMENTAL=0` (the runner is the old staged tool; it does
not `cd`, so each command is `bash -c 'cd ports/cloudglass && …'`).

| Check | Command | Result |
|---|---|---|
| runtime before glue | `cargo test --offline` (`pub mod runtime;` only) | **7 passed**, 0 failed |
| runtime with glue | `cargo test --offline` | **7 passed**, 0 failed |
| lints | `cargo clippy --all-targets --offline -- -D warnings` | `CLIPPY_EXIT:0`, 0 warnings |
| formatting | `cargo fmt --check` | `FMT_EXIT:0` |
| package | `rm -f Cargo.lock && cargo horizon-mod build` | `target/horizon-mod/cloudglass.hmod`, EXIT 0 |
| reproducible | second build + `cmp` | identical bytes, same sha256 |
| check | `cargo horizon-mod check cloudglass.hmod` | `cloudglass 0.2.0 (native-mod, format native-1/0b14f8ac…/e59da909…, for 26.3)`, **54,752 B**, **`CHECK_EXIT:0`** |
| fits | `cargo horizon-mod fits cloudglass.hmod --build nightly` | `0b14f8a  made for`, **`FITS_EXIT:0`** |
| runtime carried | `cmp src/runtime.rs <retired>/mixins/cloudglass/runtime.rs` | identical, `3458a54d…5331`, 283 lines; the packaged copy hashes the same |
| content carried | 156 `assets/`+`data/` entries vs the retired content package | same set, no differing byte (aggregate `f5f4ddcf…`) |
| lock trap (measured) | build with / without `Cargo.lock` | 57,092 B `88c1db7b…` (165) vs 54,752 B `4a8b9fb7…` (164) |
| skills gate | `python3 ports/tools/check-skills.py --notes ports/cloudglass` | `SKILLS GATE: PASS` |

**Not run: the in-game e2e.** No `horizon-launcher` on this box and no game build
at `0b14f8a`. The scenario in `tools/e2e.sh` is updated for the flat package
(`--dev-mod cloudglass.hmod`; the retired `EMBEDDED=1` legs are gone) and its
historical three-leg evidence stands for the unchanged content; the next
launcher-capable box records the run (and the tint phase, which is still the
port's one missing behaviour).

Evidence: `ports/_shared/evidence/cloudglass/sdk-0b14f8a/` (`unit-before-glue.log`,
`unit.log`, `clippy.log`, `fmt.log`, `build.log`, `build-second.log`,
`sha256-build1.txt`, `sha256-build2.txt`, `check.log`, `check-json.log`,
`uses.txt`, `fits.log`, `runtime-carry.log`, `package-entries.log`,
`lock-trap.log`).

## 2026-11-20 — 0.2.1, the in-game leg on a launcher-built game

`ports/tools/launcher-game.sh build cloudglass --port ports/cloudglass` built
`native-0b14f8a-46b8cce79411` from the same Nightly, compiled the package in and
exported it beside the unmodified control. Every run went through
`build-slot.sh run --step e2e` with the `e2e-guard` shim.

| Run | Result | Log |
|---|---|---|
| `launcher-game.sh run cloudglass` | `PASS` + `EXIT:0` — 16/16 states bind (property-less), neighbour add/remove unchanged, 16/16 items give and place, tab lists 16, 16/16 loot tables drop exactly one, all 31 recipes craft their declared id+count and consume the grid, both `c:` tag families match their members only, cloud glass walk 8.59 = air 8.59 vs vanilla glass 1.20 and cobweb 2.09 | `evidence/cloudglass-e2e/e2e-launcher.log` |
| `COUNTERFACTUAL=1` | `PASS` + `EXIT:0` | `e2e-counterfactual.log` |
| `COUNTERFACTUAL=1 NEGATIVE=1` | `FAIL` + `EXIT:1` by design | `e2e-negative.log` |
| `SELFTEST=1` | `FAIL` + `EXIT:1` by design (`white cloud glass dropped 1, expected nothing`) | `e2e-selftest.log` |
| `RECIPE_SELFTEST=1` | `PASS` + `EXIT:0`; the deliberately wrong expected count is rejected inside the green leg | `e2e-recipe-selftest.log` |
| `CONTROL=1 GAME=$CONTROL_GAME` | `FAIL` + `EXIT:1` by design (`x=0 reads 'minecraft:air'`) | `e2e-control.log` |

`check-e2e-logs.py cloudglass-e2e --strict` → exit 0, 6/6 logs.

| Check | Result |
|---|---|
| `cargo test --offline` | 8 passed (`evidence/cloudglass/sdk-test.log`) |
| `cargo clippy --all-targets --offline -- -D warnings`, `cargo fmt --check` | 0 warnings, `FMT_EXIT:0` |
| `cargo horizon-mod build` ×2 + `cmp` | identical, 55,220 B |
| `cargo horizon-mod check cloudglass.hmod` | `cloudglass 0.2.1 (native-mod, …)`, 55,220 B, `af0a220f…c5c`, `CHECK_EXIT:0` |
| `cargo horizon-mod fits cloudglass.hmod --build 0b14f8a` | `0b14f8a  made for`, `FITS_EXIT:0` |
| `verify-sdk-package.py cloudglass` | 1/1 |
| new unit test is fail-capable | `red_cloud_glass.json` moved aside → `RED_EXIT:101`; restored, `cmp` identical |

The first run's red log (the stale "Unknown block tag" assumption) is kept at
`evidence/cloudglass-e2e/found-defect/`.
