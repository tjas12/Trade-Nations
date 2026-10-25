# Classic graphics and progression implementation

## Audit and sequence

Godot 4.7.2, GDScript, Compatibility renderer, single-thread Web/PWA export. Existing IDs and 2:1 projection retained. Baseline: all 12 regression phases passed; 48×48 desktop Compatibility probe: median process 3.799 ms, p95 5.960 ms, 175 draws, 59.35 MB static memory. This is a desktop idle scene, not an iPhone stress benchmark.

Before this phase, XP thresholds existed only for bootstrap/levels 1–7. Cottage/camp unlocked at level 0; Farm/Bakery and the one purchased expansion at level 1. Only four buildings were exposed. All 274 recovered definitions were scale-audited, but most were not playable. Dirt was flat tile geometry; paths were decorative and not required for movement.

Implemented sequence: central progression data and version-4 compatibility; roadmap/celebrations and catalog refresh; working Quarry/Rock chain and decorative entries; connected path mesh and terrain presentation; regression, migration, screenshots and Web checks. Changes are isolated on `codex/classic-graphics-progression`.

## Historical evidence and design choices

The supplied four-panel composite is the primary visual reference: compact straw cottages/farms, warm masonry/timber, clean 2:1 projection, dense peripheral woodland and richly green grass. Existing working sprites are retained; no portfolio/screenshot pixels were downloaded or copied into the game. Original code-generated meadow/path geometry and contact shadows improve their setting without repainting working buildings.

Bronwyn Burns’ [artist portfolio](https://www.behance.net/gallery/1827721/Trade-Nations) identifies her isometric building/environment work and castle upgrades. The [Gamezebo walkthrough](https://www.gamezebo.com/walkthroughs/trade-nations-walkthrough/) describes construction confirmation/rotation, cottages, quarrymen, haulers, storage and level unlocks; its early version mentions only 20 levels and fleece at level 10. [Pocket Gamer’s 2010 guide](https://www.pocketgamer.com/trade-nations/beginners-guide-to-trade-nations-for-iphone-and-ipad/) describes housing, farms/quarries and production. The Blogspot reference could not be fetched. These do not establish a complete historical 1–50 table.

Our 50-level curve, +10 material storage each level after 1, decorative unlock levels, costs and accelerated offline quarry cycles are reconstruction balance. Existing early unlocks/thresholds are preserved. `xp_total` retains its legacy meaning: XP within the current level, not lifetime XP; migration never recalculates or subtracts old progress. At level 50 further earned XP is retained. There are no premium requirements.

## Functional scope

`data/progression.json` defines all 50 levels, thresholds, benefits and playable building levels. The registry uses existing BuildingDefinition for stable ID, category, footprint, costs, capacity, recipes, art, description, limits and prerequisites. Recovered unfinished content is excluded from the playable catalog/roadmap. The themed advanced cloth/wool/workshop/landmark chains remain planned, not advertised unlocks. Later levels currently provide storage benefits rather than a full original catalog.

- Level 0: existing Small Cottage, Logging Camp.
- Level 1: existing Farm, Baker’s Shop and purchased expansion access.
- Level 2: Quarry producing Rock; Rock market sales and storage/HUD.
- Level 3: Barrel; 5: Bench; 8: Crates; 12: Birdbath; 16: Buttercups; 20: Daisies; 25: Birch; 30: Campfire; 35: Cart.
- Every level 2–50: +10 storage per supported finite stored material (cumulative +490 at 50).

Decorations are honestly labeled as decorations, not income-generating shops. Quarry uses the existing worker/hauler cycle, consumes existing worker food, stores Rock and sells through Market. It can be built on clear ground as an offline design choice. Existing one-time land expansion remains unchanged.

Levels opens a dismissible, scrolling 1–50 roadmap with XP bar, locked previews, thumbnails/categories, and past/future benefits. Construction locks explain the requirement without charging. Level gains aggregate into a dismissible non-pausing celebration. Unlocks are derived/persisted when earned; load does not emit celebrations. Construction XP has a persistent once-only flag.

## Terrain and artwork

Added original cached mesh artwork: worn dirt with earth flecks/embedded stones, small warm cobbles and larger pale slabs, grassy fringes, all 16 connection masks. All three materials connect; changing a material costs the full new material price; identical repaint costs nothing. Erase refunds nothing, as before. Dirt costs 1 Gold, cobbles 2 Gold + 1 Rock, slabs 3 Gold + 2 Rock per unique effective cell. All remain cosmetic and nonblocking. Neighbor edits rebuild the cached mesh; no per-frame path geometry regeneration.

Grass has warm green variation and tiny meadow flecks in the existing shared mesh. Farm art is reduced slightly within its 2×2 footprint, quarry fitted to 3×3, and contact shadows ground structures. Permanent building perimeter lines are removed; placement ghosts retain footprint feedback. Existing transparent-padding correction and mirror/default-view rotation fallback remain. Detailed roofs, windows, fences and equipment in the existing sprites are retained without lossy upscaling. No new raster assets/dependencies were added; new visual source is `classic_paths.gd` plus mesh/rendering changes.

## Save safety

Version 4 adds `unlocked_buildings` and `construction_xp_awarded`. Versions 1–3 migrate in memory through the existing validated pending-write/backup mechanism. Legacy completed buildings are marked rewarded and grandfathered; locations, rotations, staff, timers, resources, objectives and paths remain. Unfinished legacy construction can still complete normally. Earned unlocks do not disappear if level is later lower. No browser storage clearing, catch-up production, or backlog dialogs. Older game versions cannot read version-4 saves, so do not deploy an older build over this one after playing it.

## Validation

See README and the final deployment record for checks actually run. New ClassicTests cover every level/registered unlock, cap/multi-level/invalid XP, repeated construction events, legacy version-3 serialization/migration, grandfathering, locked purchases, 16 mixed-material junctions, replacement costs, path save/reload/erase, and actual quarry production/sales. Existing version-1/2 tests continue to cover housing, worker assignment and rotation migrations. Desktop event injection/Chromium do not establish physical iPhone or Safari performance.

## Desktop rendering observations

With the same 48×48 idle probe, draw calls changed from 175 to 177; a 1,024-tile mixed-path scene used 178 (one cached path mesh). Static memory was approximately 59.35 → 61.27 MB, and 61.35 MB with paths. Final repeat idle median process was 5.599 ms; path-stress median 3.057 ms, p95 7.274 ms. Earlier concurrent probe runs varied up to 11 ms, so timings are noisy rather than evidence of a speedup. No per-path sprites or per-frame topology rebuilding were introduced. This probe does not simulate a busy town with many workers; that and Safari/device profiling remain manual follow-up work.
