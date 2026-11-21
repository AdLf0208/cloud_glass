// The client eye overlay: the one game-facing helper of this package.
//
// Upstream's `ClientTick.java:24-43` registers a GUI layer above vanilla's
// camera overlays and fills the frame with `0x80` + the diffuse colour of the
// dye while the block at the player's eye is a Cloud Glass block. The SDK
// package answers that moment with `Hooks::gui_layer_pre`, which fires before
// each vanilla HUD layer (and before the layer's own drawing, which is where
// upstream's layer sits relative to the crosshair).

use mod_api::{ClientHost, GuiLayerPreEvent};

use crate::runtime;

/// The HUD layer the overlay draws beneath, mirroring upstream's
/// `registerAbove(VanillaGuiLayers.CAMERA_OVERLAYS, …)`: the crosshair is the
/// first layer Horizon draws. Vanilla only draws the crosshair in first person
/// (`game.rs:8120`: `camera_type.first_person()`), and a layer F1 hides never
/// fires, so in the other camera modes the hotbar — the next layer that always
/// draws with the HUD — carries the fill instead.
fn under_layer(host: &dyn ClientHost) -> &'static str {
    if host.camera_type().is_first_person() {
        "minecraft:crosshair"
    } else {
        "minecraft:hotbar"
    }
}

/// Before one HUD layer: if the block containing the player's eye is a Cloud
/// Glass block, fill the frame with its diffuse colour at alpha `0x80`, as
/// upstream's layer does. Reads the eye through `Entity.getEyePosition`
/// (`entity_eye_position`), not through the camera: the camera is detached in
/// third person, and upstream keys on the player's eye in every camera mode.
pub fn on_gui_layer_pre(host: &dyn ClientHost, event: &mut GuiLayerPreEvent<'_>) {
    if event.layer != under_layer(host) {
        return;
    }
    let Some(player) = host.local_player() else {
        return;
    };
    let Some(eye) = player.entity().eye_position(host) else {
        return;
    };
    let Some(level) = player.level(host) else {
        return;
    };
    let Some(block) = level.block(host, runtime::block_at(eye)) else {
        return;
    };
    let Some(argb) = runtime::overlay_argb(&block.id(host)) else {
        return;
    };
    let [width, height] = event.draw.size();
    event.draw.fill([0.0, 0.0, width, height], argb);
}
