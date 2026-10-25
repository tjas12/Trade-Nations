# Freeze and grid repair — 2026-10-24

## Confirmed failures

The user's normal Godot log showed an active_trades assignment failure in
SocialManager._simulate_social_tick. The local filtered list was an untyped Array,
but SaveGame.active_trades is Array[Dictionary]. The simulation runs every 15
seconds. Repeating this exception can interrupt a game launched in Godot's debugger.
The fix keeps the filtered list typed.

A longer simulation regression also exposed a gift template with no format
placeholder being passed through the percent formatter. Replacement now safely
handles templates with and without a resource placeholder.

Actual mouse-event tests exposed a separate Build menu bug: forward iteration over
tab indices while removing children could skip children and access an invalid index
on reopening. The menu now iterates over a snapshot of child references.

The initial UI tests called scene methods and button signals directly. They missed
this player-input path and the periodic simulation failures. The new regression
uses viewport mouse movement, button press/release, tab clicks and Escape events,
with an explicitly sized viewport, instead of emitting the action signals.

## Grid and picking

TownGridGeometry supplies one isometric projection for terrain, building anchors,
preview snapping, screen-to-tile conversion, worker endpoints and floating labels.
Diamond footprints follow the exact saved width/height and swap dimensions on
rotation. Sprites are scaled across the footprint and bottom-aligned with its base;
they remain upright when the footprint is rotated. Y sorting handles town layering.

Saved x/y values are still tile coordinates. No save file, original archive or
image/audio asset byte was modified. Old layouts derive their new screen positions
from the same tile coordinates when loaded.

Building selection runs after GUI handling in Main._unhandled_input. It tests
sprite alpha and the diamond footprint, so transparent padding does not steal
neighbor clicks. Preview buildings cannot be picked. Escape closes overlays; opening
Build hides the old popup. Native Area2D picking is disabled to avoid competing
selection paths. The unused broad-phase rectangle is not a villager navigation
obstacle: pathfinding remains unfinished.

Continuous fractional hauling also used to spawn '+0 Wood' labels every frame.
Notices now accumulate until a whole unit can be displayed, reducing needless UI
allocation while preserving the actual transferred resources.

## Verification

- Godot 4.7.2 editor import and 60 foundation assertions.
- Existing 27 restoration assertions; graphical artwork comparison remains intact.
- 17 interaction assertions: Town Hall selection/Close, tutorial dismissal, Build
  reopening, tab selection, mouse-driven cottage placement, saved tile coordinates,
  cottage picking, Escape, camp picking, worker/hauler buttons, and producer Close.
- Geometry round-trips for 144 tile centers within the interaction assertion.
- 41 simulated 15-second social ticks and 30 seeded gift generations execute without
  script errors. These are explicit simulation calls, not ten minutes of wall time.
- Interaction tests run headlessly and through Forward Plus, matching the renderer
  recorded in the user's actual log. Existing graphical tests use Compatibility.
- An extended 18-second headless Main run crosses the real first social tick.

Known root-certificate access and headless audio cleanup diagnostics remain
explicitly reported by the validation script. No runtime GDScript error is exempted.
The tests inject real input events into the viewport, but do not constitute a full
manual session in Godot's embedded game window or a complete economy playthrough.

## Run the fixed copy

Godot's project list includes separately downloaded ZIP copies. Updating this
workspace does not change those copies. Stop the current run with F8 and import:

C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\Faithful_reboot\project.godot

from Godot's Project Manager, then run F5. Alternatively, download the updated
codex/offline-restoration-audit branch into a new folder and import its project.godot.
Do not overwrite or delete existing saves to apply this code fix. Old error-counter
entries belong to the previous run; stop and start a new debug session to distinguish
new failures. Original asset clearance and incomplete gameplay limitations from the
prior audits still apply.
