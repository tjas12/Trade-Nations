# Visual layout milestone — 2026-10-24

## A. Scale and anchors

BuildingVisuals measures alpha bounds in corrected legacy-art coordinates, compensates transparent padding, and applies one native pixel scale with a footprint-width safety cap. Shared data provides explicit width calibration for the active Town Hall, Cottage, Camp, Farm and Bakery. Native image bytes, gameplay dimensions, economy data and the original XML remain untouched. The active Cottage and Farm remain 2×2. Ground anchors drive sorting; world picking follows draw depth and alpha/footprint bounds. Previews keep their validity tint and do not display duplicated harvest bubbles.

Existing converted sprites were linked using exact normalized object names and source XML IdleAnim references. The developer preview visits all 274 definitions against a fixed grid/villager reference; the scale audit measures every definition and tests synthetic transparent padding. 108 definitions now have mapped artwork; 166 remain explicitly unmapped placeholders. No claim is made that all of those require newly drawn artwork.

## B. Orientation and safe editing

TownGridGeometry owns quarter turns, rectangle dimensions, occupied cells, rotated entrances and legacy perimeter cells. Placement validation, move/rotate, navigation, rendering and sorting share it. Rotation is logical grid orientation plus verified mirroring; flat textures never rotate on screen. No verified four-direction building set was found. Numbered cottages are colors and seasonal prefixes are skins. Clock/text-bearing civic/shop/store/market sprites expose one view; other mapped buildings generally expose original/mirrored front views. Placeholder geometry can represent four quarter turns, clearly labelled as such.

Existing rotation opens a pinned-position ghost. R/Shift+R and visible buttons cycle supported views; Confirm/Cancel are separate GUI actions. Move position explicitly unlocks movement. The original instance remains intact and faintly visible until confirmation; only confirmation changes coordinates/facing. Staffing, identity, inputs already reserved, construction and production progress remain on that original resource. Cancel has no resource transaction. Paths are invalidated after confirmation, not while previewing. Future edits preserve access to previously reachable buildings.

Save version 3 adds cosmetic tiles and legacy entrance metadata. Older saves keep buildings and logical facings. If the default entrance is blocked or disconnected, migration can retain a reachable free perimeter entrance, preserving old town usability without moving structures. Subsequent explicit edits validate and replace this compatibility entrance. Invalid layouts with no viable route remain in place for the player to arrange; nothing silently deletes or relocates them.

## C. Paths and decorations

GroundDecorations stores Vector2i tile positions independently from building occupancy. Dirt connects through shared diamond edges; flower beds and fences use recovered DAISIES/FENCEWOOD sprites. All brushes are non-blocking cosmetic layers. Whole-stroke cost preview and atomic application use the same effective-cell calculation, deduplicate cells and skip already decorated/occupied tiles. Erasing costs/refunds nothing. New paint follows the active land bounds, including expansion. Landscape updates do not reset worker routes or production.

## D. UI and verification

The selected panel is 288×380 at 1152×648, with prominent name/Close and Overview, Workers, Layout tabs. Shared-scale catalog thumbnails show dimensions, costs and supported-view counts. The layout bar exposes facing, turns, confirm/cancel and movement pinning. The landscape brush exposes per-stroke resource totals. Villager names/activity are shown for only the nearest hovered person; floating notifications have three separated lanes and never intercept input.

The Windows validator runs import/parsing, foundation, restoration, real-input interaction, the complete economy/save scenario, all-definition scale audit and layout/decor regressions, headless main startup, Compatibility rendering and Forward Plus runtime checks. Layout tests include all four rectangle/entrance transformations, boundary/neighbor rejection, blocked entrances, preview/placed-scale agreement, cancellation, staffing/recipe preservation, rotated worker access, v2 migration/legacy access, unique stroke charges, no-charge repaint/erase, unaffordable strokes and saved decorations. Interaction tests exercise actual rotate/cancel/confirm buttons, keyboard R, pinned preview motion, brush dragging and UI input isolation.

Native RAW color/orientation verification remains enabled. Actual runtime screenshots are inspected at 1152×648. Known root-certificate and ObjectDB/resource-in-use shutdown diagnostics remain explicitly disclosed by the validation runner; they are not claimed fixed. No human timed balance playtest or exhaustive manual inspection of every unmapped placeholder is claimed. The existing complete economic chain remains covered with normal starting resources and simulated time.
