//! Cloud Glass — the one `impl Hooks` at the crate root, and the pure colour registry.
//!
//! The sixteen semi-transparent, no-collision blocks are **content**, not code: their
//! declarations, models, textures, recipes, loot and tags live in `data/` and `assets/`
//! inside this same `.hmod`, exactly as the retired content package carried them. Nothing
//! is registered from Rust.
//!
//! [`runtime`] is the port's pure model, carried byte-identical from the retired bundle's
//! `runtime.rs`. Its non-test half pins the dye colours upstream's eye overlay tints with, the
//! overlay's ARGB and the eye-block rule; the rest of the module is the registry description
//! and its tests, so `cargo test` checks the carried facts without the game. [`support`] is
//! the glue: the one `gui_layer_pre` moment. Keep game access out of `runtime`.

pub mod runtime;
pub mod support;

/// The mod instance the generated `hooks()` boxes once for the session.
#[derive(Default)]
struct Mod;

#[mod_api::horizon_mod]
impl mod_api::Hooks for Mod {
    /// Before the layer above vanilla's camera overlays: the eye overlay
    /// upstream's `ClientTick` registers there. [`support::on_gui_layer_pre`]
    /// reads the block at the player's eye and fills the frame with its dye
    /// colour at alpha `0x80`.
    fn gui_layer_pre(
        &self,
        host: &dyn mod_api::ClientHost,
        event: &mut mod_api::GuiLayerPreEvent<'_>,
    ) -> mod_api::Flow {
        support::on_gui_layer_pre(host, event);
        mod_api::Flow::Continue
    }
}
