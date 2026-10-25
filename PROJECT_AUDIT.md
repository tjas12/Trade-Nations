# Project audit — 2026-10-15

## Verdict

Reuse this repository. It contains a useful data model, XML research/import tools,
13 autoload managers, seven scenes, static art/audio conversions, and a small
placement/assignment/production prototype. It is not a finished or faithful Trade
Nations recreation. The upstream comprehensive report's claims of zero bugs,
complete gameplay, and extensive validation are contradicted by execution.

Audited upstream: https://github.com/LumbleHamb/Faithful_reboot
Commit: `64d78f2f9c83ffb926c81e11fccaeebc5c44d65e`.
Local branch: `codex/offline-restoration-audit`. Upstream `main` is preserved.
No push, public repository, archive download, or original-file modification occurred.

## Engine and dependencies

`project.godot` targets Godot 4.7, Forward Plus, `scenes/Main.tscn`.
Validated with official portable Godot **4.7.2 stable**, GDScript edition.
No engine migration or project renderer change was made. Graphical verification
used the command-line Compatibility renderer on an NVIDIA GTX 1080 / OpenGL 3.3.
Git is available. Runtime needs no Python packages, account, backend, or network.
Optional image conversion tools require Python and Pillow; do not run importers
casually, because they overwrite generated content. No export preset is supplied.

## Repository coverage

| Area | Findings |
|---|---|
| README, AI_INSTRUCTIONS, comprehensive report | Read; claims checked against source and execution. Preserve original files. Video analysis is a secondary observational source with unresolved conflicts with XML. |
| assets/ | 737 PNGs in art/converted and 55 WAVs in audio; converted copyrighted material, not newly licensed artwork. Some icons are seasonal or incomplete representations. |
| data/ | 274 building files, 122 recipes, eight resource definitions, one layout, one three-step tutorial, no worker definition instances. Presence of data does not imply implemented gameplay. |
| docs/ | Nine pre-existing architecture, schemas, research, status, and roadmap files. Useful source references, but many completion claims and phase comments are stale. |
| original/ | 1,318 files including a 65,907,710-byte IPA, extracted app, XML, Lua, atlas/timeline formats, metadata and audio; `.gdignore` prevents editor import. Kept untouched. |
| research/ | Ignored reference directory and extracted executable strings; useful clues, not verified simulation logic. |
| resources/ | Static definitions, shared costs/prerequisites, and runtime save/building/villager state. Strong basis for extension, several fields unused. |
| scenes/ | Main, building, and five UI scenes. Actual UI lives here, rather than root ui/. |
| scripts/ | Managers, scene controllers, UI, and cosmetic walker. Core game orchestration lives here. |
| systems/, ui/ | README placeholders; the modular support systems in the architecture blueprint do not exist yet. |
| tests/ | Existing foundation checks plus new restoration integration runner. Existing checks do not cover the full player flow. |
| tools/ | XML DOM/import pipeline and image/audio conversion utilities; retained, not used to regenerate content during this audit. |
| saves/ | Placeholder; actual persistence uses Godot user://saves. |

All tracked paths were inventoried. A literal res:// reference scan across GD,
TSCN, TRES and project files found no missing literal paths outside comments and
dynamic formats. Main scene and test paths were also loaded by the engine. This
is not a proof that every optional dynamically constructed asset reference works.

## Observed baseline failures

1. Main scene repeatedly accesses nonexistent ResourceDefinition.name; correct
   property is display_name. HUD initializes before a save exists.
2. Placement calls removed Transform2D.xform API; fails when a preview moves.
3. Walker.configure accesses its Label before _ready creates the node.
4. Building popup refreshes while hidden and leaves worker buttons hidden after
   selecting a non-producing building.
5. Inventory capacities begin empty, capacity recalculation is a TODO, and Wood
   is confused with ID 101 in market/test fixtures. Actual Wood resource ID is 10.
6. Prototype Town Hall/Cottage/Logging Camp IDs collide with imported Town Hall,
   Poplar, and Lamp Post. Directory order can determine which definition wins.
7. Inline hash comments in tutorial/cottage TRES data cause following fields to
   disappear at runtime; the tutorial displays a blank objective.
8. Main never resumes a save. No in-game save controls. Save writes directly to
   primary without backup. Loaded assignments do not rebuild economy registries.
9. Initial building sprites overlap the top HUD and clip against the screen edge.

## Repairs in this branch

- Fixed resource names, deferred HUD initialization, popup visibility refresh,
  walker configuration order, Godot 4 coordinate transform, and TRES comments.
- Kept three legacy prototype definitions, now explicitly using IDs 10001 (Town
  Hall), 10012 (Cottage), 10008 (Camp), so original IDs remain intact. Updated
  layout/tutorial/tests/walker sound hooks. These remain temporary prototype data.
- Corrected Wood to resource 10 in offline market, fixtures and prototype storage.
- Implemented additive completed-building storage aggregation, clamped free space,
  and rejected negative/nonfinite inventory transactions.
- Rechecks building affordability on placement; uses unhandled input so GUI clicks
  cannot place buildings through panels. Offset initial world below HUD.
- Added Save/F5 and Load/F9, slot 1 startup continuation, staged validated writes,
  one previous-generation backup, structural validation/fallback, and deep cache
  bypass. Rebuilds production/hauling registrations and walkers after load.
- Blocks in-game saves if startup found an unrecoverable slot, preserving evidence.
- Added integration tests and Windows validation script; suppressed per-frame haul
  logging. No balance table, original asset, or original XML was regenerated.

## What is playable and what is not

Verified by engine-driven tests: town startup, readable HUD/tutorial, cottage
placement and cost deduction, selecting a producer after another building,
assigning two existing villagers, continuous gathering, instantaneous haul to
capacity-limited storage, and save/load/backup recovery. There is a graphical
Windows launch and captured initial frame. These tests invoke scene methods;
full manual mouse/keyboard playthrough, prolonged play, audio listening, default
Forward Plus rendering, Windows export, and iOS are not verified.

Current production is deliberately very slow: prototype gathering is 10 units per
worker-hour before the existing homelessness penalty. Tests advance a producer
explicitly by 360 simulation seconds; this is not evidence of ten minutes of
wall-clock play. A Stockpile fixture verifies storage; constructing the original
stockpile interactively is hindered by catalogue categorization and progression.

## Remaining bugs and technical risks

- Flat square coordinates, no isometric terrain, camera pan/zoom, or pathfinding.
  Rotation rotates the whole visual while collision bookkeeping swaps dimensions;
  these can disagree. Ghost click picking and rotated placements need coverage.
- Walkers use a Wood icon and random home/work motion. No actual pickup, carried
  cargo, storage destinations, or transit-dependent production. Haulers transfer
  every frame. Visuals are not authoritative citizen simulation.
- Two villagers are seeded. Houses add numeric capacity but do not attract new
  villagers. Adoption and unassignment are stubs. Hunger consumes one Wheat each
  60 seconds: an unverified substitute, not an original-game constant.
- No shop recipe selection/execution, input consumption for refining, construction
  timer advancement, or upgrade execution. New buildings default complete despite
  having build-time fields. Recipes/data alone do not implement these mechanics.
- Mayor begins at level 0; hardcoded XP thresholds begin at 1, so normal starting
  progression stalls. Prerequisites, upgrade-only flags, owned limits, premium
  costs and original menu manifests are not enforced. Most imported buildings
  have no category/icon and do not appear in the current category-only catalogue.
- CurrencyManager affordability returns true and spending/rewards are stubs.
  SocialManager contains local market/friends/mail functions, but Main provides
  no social menu. Prices, timer walks, beans exchange and gifts are substitutes.
  Empty inbox initialization can recreate gifts; special purchases append layout
  entries without main placement/collision bookkeeping. Do not call this balanced.
- Tutorials only react to build/worker events; completion isn't persisted. Continuing
  saves does not restore tutorial state. No complete original quest system.
- Saves serialize exposed Resource fields, but timer catch-up, migrations, checksums,
  full nested integrity validation, process-crash/power-loss durability and autosave
  are absent. Backup is one generation. Do not load untrusted Resource save files.
  Existing upstream prototype saves need an explicit ID migration before reuse;
  IDs 101/201 now correctly refer to original Poplar/Lamp Post definitions.
- Economy's pause state is not coordinated with TimeManager/GameManager. Test API
  state transitions are not a complete main-menu/pause implementation.
- AudioManager reads original/bundle/Sounds.xml at runtime, even though original/
  is ignored by Godot import. A redistributable/exported build needs a cleared
  standalone sound catalogue and cleared assets. No export package was created.
- No source license or permission grant found. Restricted material already exists
  in upstream Git history; merely ignoring it will not make a public fork cleared.

## Execution evidence

Logs are in the parent workspace (local, not committed); validation state is isolated
under parent `.validation/`, away from normal player AppData.

| Check | Result |
|---|---|
| Baseline editor import, 4.7.2 | Imported; no GDScript parse failure. Sandbox denied normal AppData/editor writes. |
| Baseline Main, headless | Repeated resource-name script errors; exit code alone falsely looked successful. |
| Baseline foundation tests with writable isolated AppData | 60 checks pass, but leaked objects/resources reported; did not exercise Main. |
| Repaired foundation tests | 60 checks pass. |
| Restoration integration | 18 checks pass, including placement costs, producer selection, assignments, production/storage, deep reload and invalid-primary backup fallback. |
| Graphical integration, Compatibility | Launch/render successful on Windows; initial frame inspected. |

Godot emits `Failed to read the root certificate store` in this restricted environment.
This is an engine environment diagnostic; no game HTTP request is required or made.
Backup recovery deliberately emits a warning. Final verification details are retained
in `validation-final.log` and the validation script's per-run logs.

## Recommended next increment

A single tested, source-traceable early-game slice: fix level-zero progression and
catalogue prerequisites, connect cottage completion to citizen arrivals, implement
real worker/hauler task state and delivery to a stockpile, then expose one bakery
recipe with Gold/XP rewards. Add save/load-in-transit tests. Keep prototype and
verified data visibly separate before expanding the content roster.

### Final run qualification

`tools/validate_windows.ps1 -Graphical` completed import, 60 foundation assertions,
18 restoration assertions, bounded Main launch and graphical integration. The
headless test processes also emitted resource-in-use cleanup diagnostics (2 audio
resources in foundation; 4 in restoration on the final run). The validator reports
these explicitly as known diagnostics instead of treating them as assertion or
script failures. Root-certificate access remains restricted. Main and graphical
runs had no game script errors. This is not an error-free or full-playthrough claim.
The foundation fixture now explicitly frees its off-tree building test node.

### Changed-file inventory
- `.gitignore`
- `README.md`
- `data/buildings/logging_camp.tres`
- `data/buildings/small_cottage.tres`
- `data/buildings/town_hall.tres`
- `data/layouts/default_layout.tres`
- `data/tutorials/first_steps.tres`
- `scenes/Main.tscn`
- `scripts/autoload/audio_manager.gd`
- `scripts/autoload/economy_manager.gd`
- `scripts/autoload/inventory_manager.gd`
- `scripts/autoload/save_manager.gd`
- `scripts/autoload/social_manager.gd`
- `scripts/autoload/tutorial_manager.gd`
- `scripts/main.gd`
- `scripts/ui/building_popup.gd`
- `scripts/ui/resource_hud.gd`
- `scripts/villager_walker.gd`
- `tests/test_foundation.gd`
- New: PROJECT_AUDIT.md, RESTORATION_ROADMAP.md, SETUP_WINDOWS.md,
  FEATURE_MATRIX.md, ASSET_LICENSE_AUDIT.md.
- New: tests/RestorationTests.tscn, tests/test_restoration.gd and its generated UID,
  tools/validate_windows.ps1; generated UIDs for SocialManager, VillagerWalker and
  XML import script (Godot editor bookkeeping).

Engine and diagnostic logs are local workspace artifacts, excluded from commits.
Original archive/art/audio bytes were not changed; importer-generated changes to
tracked .import metadata were restored after validation.
