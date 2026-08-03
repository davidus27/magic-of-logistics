# Godot 4 import checklist

- SVG textures: use lossless import.
- Paper grain: repeat disabled for full-screen stretch; repeat enabled for large world surfaces.
- Terrain tiles: repeat enabled.
- Pixel snap: optional; review at zoom 0.85, 1.00, and 1.20.
- Audio: mono, non-looping except the portal tone if the cast logic restarts it.
- Portal tone duration: 4.0 seconds.
- UI minimum target sizes: preserve source aspect ratios.
- Do not derive collision from visual outlines.
