# SnowPlay — Vector Asset Library v1.0

Hand-authored SVG illustrations based on the two supplied concept sheets. Every SVG is **vector-only**, self-contained, has transparent background and an explicit viewBox. Corresponding PNG is a 2× raster preview for inspection, not the primary asset.

## Visual language
Soft 2D Cartoon / Cute Winter Illustration; rounded shapes, clean gently tinted edges, pastel highlight, minimal gradients. No backgrounds, captions or raster images inside SVGs. Built for small on-screen sizes (usually 14–64 pt), not for showing all assets simultaneously.

## Integration
* Use `manifest.json` to map IDs to sources, viewBox, anchor and optional layer groups. Anchor coordinates normalized from top-left of the SVG canvas.
* For independent animation prefer individual SVG components (`snowplow_wheels`, `gift_lid`, `parachute_canopy`, etc.) or groups marked in `animated_layers`. Some components share a **common composition canvas** for predictable alignment. Do not trim their transparent padding independently if combining by the same origin.
* SpriteKit cannot render SVG directly as SKTexture: pre-rasterize SVG at scale appropriate for the current display (or use build-time PNG/WebP) and cache textures. Convert assets with CoreGraphics SVG rendering library or at build time; PNGs are previews and can be interim sprites.
* `snow_particle_1..3` are intentionally drawn at a larger viewBox; use 1–3 pt in application. Generate wind and falling movement procedurally rather than thousands of nodes if necessary.
* Frost is only for **corners of inactive windows**. No snow is drawn along window top borders in this release.
* Garland is illustrated as a reference segment; adjustable sag and anchor points should be implemented by dynamically laying out wire curves + bulbs, not by stretching one texture.
* The countdown panel has no baked-in text: add a native, localized live countdown as an overlay.
* Snowplow and Santa should avoid covering interaction regions; render behind normal windows when possible.
* The concepts show Mochi, Puffy, Bubi, but they are **intentionally excluded** per updated brief.

## Notes
No pixel-perfect tracing or automatic raster-to-vector conversion was used; shapes were reconstructed as editable vectors in the reference aesthetic. Art is designed for iteration and testing at final small-scale sizes.
