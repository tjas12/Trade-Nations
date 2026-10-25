# Panning and landscape — 2026-10-24

Scope: navigation and environment only. The reported Wood issue was a missing
hauler, as confirmed by the player. Production, hunger, worker sprites/behavior,
resource values and save data were not changed in this update.

## Controls

- Left-drag empty ground to pan. A short movement threshold separates a drag from
  a click. Clicking buildings still selects them; placement still uses left-click.
- Middle-drag remains available, including while positioning a building.
- WASD or arrow keys pan while the game has focus and a building/menu overlay is
  not open. Key release and application focus loss clear movement state.
- Mouse-wheel zoom remains anchored to the pointed location.
- Center town (or Home) resets zoom and brings the average building location back
  into view. Camera movement is bounded by the playable diamond.
- Grid: Off/On toggles the grid. It is hidden in normal play by default and appears
  automatically while placing a building.

Ground dragging starts only after GUI handling. Once started, the drag is tracked
before GUI handling so releasing over the toolbar cannot leave movement stuck.
Starting a drag on a UI control does not pan the map underneath it.

## Landscape

The native Godot renderer now draws smoothly varying grass shades, small grass
clumps and a shallow earth-colored edge. There are no new raster/generated assets.

Landscape creates deterministic trees, flowers and stumps using the existing OAK,
BIRCH, MAPLE, SPRUCE, DAISIES and STUMP converted textures with the existing legacy
color/orientation shader. These assets retain the provenance/limitations in
ASSET_LICENSE_AUDIT.md. No archive, converted image or audio bytes were changed.

Scenery is decorative, not a restored finite forest/resource system. It does not
produce resources, grant decoration bonuses, block placement, create buildings,
consume inventory or enter the save file. It derives the same layout from tile
coordinates on reload, clears a margin around existing/new buildings, and rebuilds
when the active land size changes. Existing saves/layout coordinates are preserved.

## Validation

The Windows validation workflow passes import, 60 foundation checks, 27 restoration
checks, and 29 input interaction checks. The graphical restoration run adds the
existing artwork pixel comparison; the interaction run also passes in Forward Plus.
Known restricted certificate-store and headless audio shutdown diagnostics remain
reported separately; no runtime GDScript error was observed in these runs.

New input checks cover left dragging, middle dragging, release over the toolbar,
keyboard release, Center town, GUI drag isolation, stable scenery regeneration,
unchanged saved structures/occupancy, and automatic placement grid visibility.
A rendered frame was inspected. These are engine-injected input checks, not a
complete manual gameplay session or original-game visual fidelity certification.

Stop the running game with F8, then run F5 again to load the updated scene. If using
an older ZIP copy, import the current workspace project.godot or download the latest
codex/offline-restoration-audit branch. Local editor project settings and pre-existing
Godot import metadata changes are preserved rather than included in this commit.
