# Fantasy Convoy MVP Assets

Every asset the game loads lives here. Most of it is a pack that converts the visual and sound decisions in the MVP specification into editable assets for Godot 4.x. The exception is [`world/tintable/`](world/tintable), six hand-authored files drawn under a different colour convention; the section on them below is load-bearing and worth reading before you touch world art.

## Included

- Exact palette files in JSON and GIMP GPL format.
- Static transparent paper grain overlays at 512 and 1024 pixels.
- Road, mud, and off-road terrain tiles.
- Two hand-drawn frames for important world objects.
- Wizard, four defender variants, two enemy types, portal, damage, and death marks. Cargo body, rider, wizard and barrier come from `world/tintable/` instead; see below.
- Arc Bolt, Heal, and Shield effects.
- Selection, target, leash, return, health, and barrier feedback.
- HUD icons, defender portraits, order buttons, spell buttons, profile badges, and mana widgets.
- Mockups for all major game states and all four control profiles.
- Five mono 44.1 kHz WAV placeholder sounds.
- `asset_manifest.json` with file purpose and export metadata.

## Exact specification decisions represented

- Background: `#F3EFE4`.
- Primary ink: `#1A1A1A`.
- Light line: `#B7B2A8`.
- Medium gray: `#77736C`.
- Static paper grain: up to 8 percent opacity.
- Important world objects: alternate frame `_a` and `_b` every 0.15 seconds.
- Cargo: top-down wagon (rectangle, two wheel circles), rider at the front, wizard on the bed.
- Defender: circle with shield mark.
- Short-range enemy: filled black circle.
- Long-range enemy: hollow triangle.
- Barrier: thick cross-line.
- Final portal: double ink circle.
- Selected defender: double circle or double portrait border.

## Implementation assumptions

The specification does not define typography, source canvas dimensions, stroke thickness, icon spacing, or exact screen margins. The pack therefore uses neutral serif/sans-serif fallbacks, scalable SVG sources, and documented export sizes. No font files are included.

The four role-specific defender variants preserve the required circle-and-shield silhouette. Their small G, S, E, and W monograms are optional accessibility identifiers. Use `defender_generic_a/b` to omit them.

## Godot import notes

1. Import SVG world assets as textures with filtering disabled for a crisp ink result, or enabled for smooth zooming after visual review.
2. Place frame A and frame B in a two-frame `SpriteFrames` resource. Set playback to approximately 6.67 frames per second to change frames every 0.15 seconds.
3. Keep collision shapes separate from art. The line-frame change must never alter collision.
4. Display `paper_grain_1024.png` as a full-screen overlay. Do not animate its position.
5. Use the SVG assets directly for resolution-independent UI. Use PNG exports only where the target pipeline requires raster textures.
6. WAV files are mono, 44.1 kHz, and intentionally simple placeholders.
7. Screen files are layout references, not final interactive scenes.

## Hand-authored tintable art

[`world/tintable/`](world/tintable) holds the only eight assets not from the pack. They exist because the pack draws these objects for a side-on view, which does not survive a top-down camera that rotates the object through every heading.

| Asset | Why it is here |
|---|---|
| `cargo_body_a/b` | The pack drew a wagon in side view, with both wheels below the body. The cargo turns through every heading on a winding road, so the wheels have to straddle the long edges instead. |
| `cargo_rider_a/b` | The pack rider was a head on a stalk above the body, which only reads from the side. This one is a top-down circle with a heading chevron, per sections 10.4 and 13.4. |
| `cargo_wizard_a/b` | The pack wizard triangle is upright on a 256 canvas and needs a runtime rotation. This one is drawn facing forward at wagon size, with a body circle and staff so it reads as a wizard on the bed. |
| `barrier_a/b` | The pack barrier was a single cross symbol. A barrier blocks the full 420 pixel road width of section 28, so this one spans it. |

The pack's superseded versions (`cargo_unit_a/b`, `rider_prop`, `barrier_closed_a/b`, `barrier_open`) have been deleted. Do not restore them, and do not add an asset to `world/tintable/` that the pack already covers — except where the pack silhouette only works from the side, which is why the cargo set lives here.

### Two colour conventions, on purpose

`InkSprite.ink_color` multiplies a colour over the art, so:

- **Pack art is drawn in its final ink colours.** Leave `ink_color` white.
- **Art in `world/tintable/` is drawn in white** and is tinted at runtime.

White source art is what makes tinting possible at all. `modulate` multiplies, so it can darken art but never lighten it: black art multiplied by anything stays black. White art multiplied by `InkPalette.INK` gives exactly the ink colour, and the same file can also flash pale after damage (section 13.2), render as a light grey paper mark (sections 15.11 and 29), or grey out to mark an opened barrier — `Barrier._open()` recolours to `InkPalette.LINE_LIGHT` rather than swapping texture, which is why the pack's separate `barrier_open` file is not needed.

Getting this backwards fails quietly rather than loudly: a tintable asset left untinted draws white on `#F3EFE4` paper and is nearly invisible, not obviously broken.

To view a white asset outside Godot, composite it over a dark background:

```sh
rsvg-convert -b '#33312c' -z 2 assets/world/tintable/cargo_body_a.svg -o /tmp/preview.png
```

### Two line frames per object

Important world objects have an `_a` and a `_b` variant. `InkClock` swaps between them every 0.15 seconds for the hand-drawn effect of section 10.3. Frame B is frame A with each vertex moved one or two pixels. Keep the difference small: it must read as a redrawn line, not as a vibration.

Objects that neither move nor carry state are single frame. A vibrating crack reads as damage happening rather than damage already taken.

### Godot rasterises SVG with ThorVG, which supports a subset of SVG

Stay inside it or the asset imports blank:

- Inline `fill` and `stroke` attributes only. No `<style>` blocks, no CSS classes.
- `<path> <rect> <circle> <ellipse> <polygon> <line> <g transform>` only.
- No filters, masks, gradients, `<use>`, `<text>`, or external references.
- Always declare `xmlns` and an explicit `viewBox`.

`rsvg-convert` is more permissive than ThorVG, so a preview that looks right is not proof the asset imports right. Verify through Godot with `tools/screenshot_run.tscn`.

### Two canvas conventions

`world/tintable/` art is authored at the pixel size the object occupies in the game, so it agrees with the collision shapes in the data resources. Canvases are larger than the object where a shape overhangs it: the cargo wheels straddle the body edge, so the cargo canvas is 132x96 while the body is the 120x64 of `CargoData.body_size`. The drawing stays centred so a centred `Sprite2D` lines up with the collision shape.

Pack art is drawn on a common 256 pixel canvas instead, so each use sets `InkSprite.extra_scale` to bring it down to the size that object occupies.

### Import settings are set when an asset is wired in

Every `.import` used by the game sets `svg/scale=2.0` and generates mipmaps, and `InkSprite.supersample` scales the sprite back down. That keeps lines clean across the whole 0.85 to 1.20 zoom range of section 9.

Assets not yet used by any scene are still at the pack's `svg/scale=1.0` with mipmaps off. That is expected. Raise the pair when you first reference the asset, not in bulk.

## Suggested anchors

- World entities and effects: center.
- UI icons: center.
- UI buttons, portraits, widgets, and screens: top-left.
- Terrain tiles and paper grain: top-left with repeat or stretch as appropriate.

## File naming

- `_a` and `_b`: hand-drawn line variants.
- `selected`: double-border selection state.
- `frame` and `fill`: scalable widgets intended to be layered.
- `world/tintable/`: white source art, tinted at runtime. Everything else is drawn in its final ink colours.
