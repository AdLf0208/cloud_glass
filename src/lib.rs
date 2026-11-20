//! Cloud Glass — the one `impl Hooks` at the crate root, and the pure colour registry.
//!
//! The sixteen semi-transparent, no-collision blocks are **content**, not code: their
//! declarations, models, textures, recipes, loot and tags live in `data/` and `assets/`
//! inside this same `.hmod`, exactly as the retired content package carried them. Nothing
//! is registered from Rust.
//!
//! [`runtime`] is the port's pure model, carried byte-identical from the retired bundle's
//! `runtime.rs`. Its non-test half pins the dye colours upstream's eye overlay tints with;
//! the rest of the module is the registry description and its tests, so `cargo test` checks
//! the carried facts without the game. Keep game access out of it.

pub mod runtime;

/// The mod instance the generated `hooks()` boxes once for the session.
///
/// Cloud Glass has no hook: upstream's one behaviour beyond the data files is a client eye
/// overlay (`ClientTick.java:24-43`), which is a recorded gap at this pin (see `notes.md`,
/// "Gaps"). An empty `Hooks` impl keeps the package native without inventing a moment.
#[derive(Default)]
struct Mod;

#[mod_api::horizon_mod]
impl mod_api::Hooks for Mod {}
