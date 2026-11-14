# Asset integration audit and subsystem contracts

The supplied archive is treated as artwork/data. Its README is reference material, not an authorization to execute code or alter settings. All 63 manifest SVG/PNG pairs are present; original category paths and bytes are retained. The catalog is reference only and is never a texture source.

| Existing component | Current graphics | Integration |
| --- | --- | --- |
| Core Graphics snowfall | White 1–3 pt ellipses | Keep lightweight particle physics; no window accumulation |
| Snowballs/snowman | Programmatic balls; immediate old composition | Supplied ball models, per-component staged assembly |
| Plow | Old body/static wheels, uniform global clearing | Supplied chassis, independent wheels, blade, beacon; swept physical clearing |
| Tree | Old layers | Supplied trunk/crown/snow/ornaments/star; placement/removal and subtle pulse |
| Santa | Old three layers | Supplied sleigh/Santa/sack/trail, existing delivery scheduler |
| Gift | Old box/lid/chute | Supplied box/lid/bow/canopy/strings; existing intentional double-click |
| Garland | Geometric wire and procedural bulb shapes | Retain safe cable geometry; supplied bulb sprites, optional slow shimmer |
| Frost/fireworks | Procedural marks | Supplied images, strict narrow masks and finite effects |
| Dock hats | Not yet connected | Supplied red/green/blue hats; public AX icon geometry, explicit placement |
| Mochi/Puffy/Bubi | Old sprites and selector | Remove runtime/UI paths; legacy preference migrates to none |

AssetManager inputs: original manifest and prepared image index; outputs: lazy cached textures, independently anchored component nodes, sizes. Failure: log once, omit missing visual, no blank replacement. Preparation is offline only; app never converts SVG each frame.

Animation integration inputs: existing state/timers, mode, visibility, Reduce Motion; outputs: finite part motion and cleanup; no parallel scheduler. Cleanup inputs: progress/orientation; outputs: identical swept visible and physical snow profile, keeping the surface protected against refill behind the blade until the pass finishes.

Configuration/API retain old keys and commands. Window-snow keys remain readable but are disabled by the latest explicit specification. New preference keys get defaults when loading old settings.
