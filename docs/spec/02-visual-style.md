# Visual style — §10

Implemented by `autoload/ink_clock.gd` (the two-frame line clock),
`scripts/ink_sprite.gd` (its only consumer), `scripts/palette.gd` (colours) and
`ui/paper_grain.gd`.

See also the `modulate` rule in [`../engine-notes.md`](../engine-notes.md) — it
decides whether a given file is tinted at runtime or not.

## 10. Visual design

### 10.1 General style

The game uses a paper and ink style.

The game uses black, white, and gray colors only.

The background uses an off-white paper color.

| Colour | Value |
|---|---|
| Background paper | `#F3EFE4` |
| Primary ink | `#1A1A1A` |
| Light line | `#B7B2A8` |
| Medium gray | `#77736C` |

The game does not use realistic textures.

The game uses simple lines, circles, rectangles, and symbols.

### 10.2 Paper effect

A static paper grain covers the full screen.

The paper grain opacity is 8 percent.

The paper grain does not move.

The game does not use a complex paper shader in the MVP.

### 10.3 Line effect

Important world objects use two slightly different line frames.

The game changes the line frame every 0.15 seconds.

This effect gives a simple hand-drawn result.

**The line effect must not change collision shapes.** `InkSprite` touches nothing
but the texture, which is what guarantees this.

### 10.4 Entity symbols

The cargo unit is a large rectangle with two wheel circles.

The rider is a small circle at the front of the cargo unit.

The wizard is a triangle inside the cargo rectangle.

A defender is a circle with a shield mark.

A short-range enemy is a filled black circle.

A long-range enemy is a hollow triangle.

A barrier is a thick cross-line on the road.

The final portal is a double ink circle.

### 10.5 Selection symbols

A selected defender has a double circle around its body.

The circle uses the primary ink color.

A selected defender portrait also has a double border.

An ordered defender shows a small order symbol above its body.
