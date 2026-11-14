> Актуальное обновление: [нижний зимний мир](Floor-World-Revision.md). Снег Dock и отдельная площадка лепки удалены, Йети получил две игры, ёлка — новые варианты. Ниже сохранён предыдущий проход.

> Обновление 13.11.2026: актуальные механики, результаты и ограничения нового ТЗ описаны в [Interactive Winter World](Interactive-Winter-World.md). Предыдущие результаты ниже относятся к указанным в них проходам.

# Subsystem contracts (recorded before implementation)

Coordinates: engine coordinates are global Quartz logical points, origin at main display top left, y down. AppKit and SpriteKit convert at the renderer boundary. No image or document data is collected.

| Subsystem | Inputs / dependencies | Outputs / events | Errors / fallback |
| --- | --- | --- | --- |
| Overlay | NSScreen, AppKit, SpriteKit | One transparent foreground and desktop window per display; Core Graphics canvas for snow/frost, lazy SpriteKit for ornaments, click-through by default | Remove detached screens; never activate foreground overlays |
| Physics | dt, bounded particle pool, wind, surfaces, config | Recycled particles; deposited volume; visual-only time scale | Clamp dt; bounded capacity; deterministic seeded RNG for tests |
| Surfaces | Dock/tree geometry, impacts, resizing | Sampled snow height, conserved volume within capacity, edge loss | Invalid geometry ignored; never allocate unbounded samples |
| Window observation | Public CG window metadata, AX window attributes; no titles read | Visible/moving/resizing/active/minimized/restored/confirmed closed | AX denied: snowfall + eligible Dock geometry, no guessed identity; off-Space/hidden windows retained |
| Animation director | Start/stop/cancel, priority, budget, completion | Limited concurrent timed effects; close coalescing | Focus/Reduce Motion suppress expensive effects; cancellation callback |
| Frost | Inactive duration, activation, visibility | Supplied translucent exterior frost art, 0.5 second melt | Disabled in Focus and on ambiguous/fullscreen geometry |
| Dock | Public CG Dock windows, AX frames, visibleFrame fallback | One horizontal/vertical strip, cleanup, snow interaction | Auto-hidden/ambiguous Dock: hide strip/icons; no guessed icon coordinates |
| Decorations | Per-display saved normalized positions, window occupancy, editor events | Desktop-level tree, garland, Dock hats, delivery/gift, snowman | Defer delivery without free space; suppress secondary objects behind occupied regions |
| Input | Explicit editor/interaction mode, local mouse events | Placement and snowballs in small overlay regions | Escape/Done cancels; normal mode ignores all mouse events; no keyboard logging |
| Local API | Loopback POSIX socket, bounded HTTP, random session token | Snapshot/config/actions on main queue, static web preview | Reject Host/Origin mismatch, absent token, unexpected methods, oversized/slow requests |
| Config | Codable, Application Support, atomic write | Clamped validated settings, persisted per-screen placement | Defaults on corruption; diagnostics without personal window data |
| Power/session | Workspace sleep/wake/session notifications, power-source API | Pause locked/asleep/inactive sessions; 30 FPS on battery | No integration claims until exercised on hardware |

## Stacking policy
Foreground snow is clipped against higher windows using the front-to-back CG list. Snow caps are limited to Dock/tree; frost lives outside the corners and avoids the upper-left controls. Desktop decoration windows use desktop-icon-level + 1 and explicitly clip decoration nodes against normal-window rectangles. Foreign-window interleaving cannot be guaranteed by a public NSWindow API; ambiguous geometry is hidden, not overdrawn. Mission Control/Spaces/Stage Manager remain manual compatibility gates.

## Visual precedence
Visual Design & Lightweight Assets 1.0 supersedes older conflicting sizes: 1–2 pt flakes (rare <=3), 40–100 normal particles/display, 5 pt default cap, at most 10 pt; miniature vector decorations and no sound.

## Asset integration revision, 2026-11-12

The newest brief disables all window-edge accumulation and window shedding at runtime. Old configuration keys and reusable core clock types remain compatible; they cannot reactivate those visuals. Dock snow and the small tree surface remain. Window metadata still drives frost, occlusion, and explicitly placed window-attached garlands.

AssetManager reads the original 63-entry manifest, validates each entry independently, and maps IDs to prepared 1×/2× resources. Five additional components are isolated from original vector primitives. A bounded lazy cache retains textures; scene removal and reset release node references. Compositions share a registered SVG canvas but keep independent anchors/pivots. No runtime SVG conversion or catalogue cropping occurs.

A plow blade's global trajectory drives the exact swept fraction of Dock samples; deposition behind an active blade is suppressed until the pass completes. SnowmanSystem keeps assembly origins while the visual layer animates each of three spheres into position. Santa's flight crosses the gift's target x before dropping the registered box/parachute composition. Countdown uses wall-clock Date, not animation time.

Dock hats are associated with application URLs supplied by public AX attributes. Explicit hat edit mode captures only available icon rectangles; ordinary drawing remains click-through. Window garlands capture only three small exterior key points, then track public window metadata. Missing/ambiguous geometry hides decorations.
