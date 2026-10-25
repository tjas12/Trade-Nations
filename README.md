# Trade Nations — first playable offline town

**Play on iPhone:** [Open the live Web/PWA game](https://tjas12.github.io/Trade-Nations/) in Safari, rotate to landscape, wait for **Offline: ready**, then Share → Add to Home Screen. The [first automated build and deployment](https://github.com/tjas12/Trade-Nations/actions/runs/40210170164) succeeded; desktop browser saving/offline reopening were verified against the live site. Physical iPhone testing remains outstanding.

The latest milestone adds touch controls, landscape phone drawers, safe-area layouts, autosaving across interruptions, and prepared Web/PWA and iOS export presets. Start with [the phone-testing guide](MOBILE_TESTING.md). The completed visual/layout work includes calibrated building scale, safe facing previews, compact building tabs, and saved path/decoration brushes. See [VISUAL_LAYOUT_MILESTONE.md](VISUAL_LAYOUT_MILESTONE.md) and the developer [building audit](docs/BUILDING_VISUAL_AUDIT.csv).

This Godot restoration now has a playable local economy: housing and villagers, construction, wood and wheat production, cookie processing, local sales, eight rewarded goals, and one land expansion. It uses the recovered isometric artwork. No accounts, network service, paid dependency, or database is required.

## Open and play

Use **Godot 4.7.2**, the installed version used for validation. Open this checkout’s `project.godot` in Godot and press **F5**. In this workspace the correct project is:

`C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\Faithful_reboot\project.godot`

Stop a running session with **F8** before relaunching. Avoid the older downloaded `trade-nations-codex-offline-restoration-audit-(2)` copy. Desktop mouse/keyboard controls remain available. Touch devices use a responsive landscape layout with 48-unit buttons, scrollable panels, and display safe-area insets. Desktop simulations cover 852×393, 1152×648, and 1440×660; physical iPhone testing remains outstanding.

Your existing main town loads automatically. For the new opening experience, choose **New town…** and confirm: your current town is first archived in an unused local slot. **Load** lets you restore the main or an archived town. Saving a restored town writes it as the main town; its archive remains available.

## First economy walkthrough

1. Open **Build → HOUSE** and place a Small Cottage on green preview tiles. After its short construction, two new villagers appear. The starting pair already has Town Hall quarters.
2. Select the existing Logging Camp and assign **one worker and one hauler**. They travel around building footprints; production starts when the worker arrives. Wood is delivered by its hauler.
3. Follow the compact **Town goals** panel. Goals advance and award Gold/XP automatically from actual state. Build a **Farm** from Resources, assign a worker, and use **Collect** to bring harvested Wheat into town storage. A second cottage gives you enough people to add more haulers later.
4. Build the **Baker Shop** from shop and assign the remaining worker. Every 18 seconds of active work it consumes 3 Wheat and makes 2 Cookies. Cookies go straight to town storage. Check the building panel for progress, inputs, output, remaining time, or why it is paused.
5. Open **Market**, choose a quantity, and sell Cookies for Gold. Wood and Wheat can also be sold. Keep Wheat for food and processing; Market offers emergency Wheat purchases. Farmers keep gathering when hungry so food shortages remain recoverable.
6. Save up **180 Gold and 40 Wood**, then choose **Expand**. A new town grows from 16×16 to 24×24 tiles; older towns keep their existing size and gain eight tiles per side. One expansion is available.

The opening is designed to progress within 10–15 minutes without developer grants. The automated scenario completes the chain with normal starting resources and simulated game seconds; this is not a measured human play session.

## Controls

| Action | Control |
| --- | --- |
| Pan | Drag empty ground, middle-drag, WASD, or arrow keys |
| Zoom / recover view | Mouse wheel / Home or Center town |
| Select | Click a building’s artwork or diamond footprint |
| Place / rotate / cancel | Left-click or Confirm / R clockwise, Shift+R counterclockwise / Cancel, right-click, or Escape |
| Edit existing facing | Select building → Layout → Preview turn, or press R; position stays pinned until Move position is chosen |
| Landscape | Landscape → Dirt path, Flower bed, Decorative fence, or Erase; drag and release to apply |
| Grid | Grid toggle; shown automatically during placement |
| Local save / quick load main slot | Save or F5 / F9 |
| Choose saved town | Load |
| Staffing | Selected building: assign worker/hauler, unassign a selected citizen, or release all staff |
| Move | Selected building → Move; free, preserves construction and production state; Escape cancels |
| Demolish | Selected building → Demolish… → confirmation |
| Developer clock | F3 reveals a separate time-speed button; hidden by default |

Demolition refunds 50% of current configured building costs, rounded down. Reserved recipe inputs and stored harvests return up to available inventory capacity; excess does not transfer. Staff become available, residents remain and may lose housing. Town Hall is protected. Move/demolish never silently resolve old placement conflicts. Trees and flowers are cosmetic, outside the usable plot, and never block input or occupy cells.

## Local saves

Main save: `%APPDATA%/Godot/app_userdata/Trade Nations Reboot/saves/slot_1.tres`. Numbered archive slots share that directory. Changes autosave after a short debounce (at most 15 seconds during continuous activity), with a 30-second progress checkpoint and an immediate save on focus loss/backgrounding. Save/F5 still writes immediately; do not rely on closing the app. New town archives the current in-memory state before resetting it.

Version 3 adds saved ground decorations and compatibility entrances, retaining earlier production and progression state. Versions 1 and 2 migrate safely. Version 2 introduced persistent buildings, construction, individual villagers, positions, home/job links, production progress and reserved inputs, resources, XP/unlocks, objective claims, recorded production/sales, and expansion. Older saves migrate in memory and are updated on the next manual save or autosave. Housing reconciliation repairs missing arrivals without duplication. Existing plot sizes, buildings, stock, and valid jobs remain; conflicting duplicate jobs are normalized to one job per person.

Writes use a validated pending file and retain a valid previous generation as `.backup.tres`. Loading falls back to that backup if the primary is invalid. If neither copy is readable, files remain unchanged and main-slot saving is blocked. Copy the save directory before manual recovery. Unknown future save versions are rejected. **Production pauses while unfocused, backgrounded, or closed**: there is no offline catch-up. Repeated focus/resume events do not restart a cycle or grant rewards. Native app suspension and browser visibility events are handled separately from focus. Browser storage has additional limits described in the phone guide; a successful filesystem write cannot guarantee Safari will retain data indefinitely.

## Content and limits

`data/first_playable.json` contains the playable catalog and economy costs; `data/progression.json` is authoritative for unlock levels and the 1–50 curve. The economy file also defines cycle durations, yields, staffing, sale/food prices, expansion, and objective rewards. DataManager applies these explicit balance overrides to existing definitions. The existing Baker Shop and Cookies recipe are connected; Cookies is a new inventory resource, rather than the imported recipe’s immediate Gold reward. Original recovered assets and source data remain available.

Character bodies/directional animations have not been reconstructed: villagers currently use an existing portrait sprite with simple movement and activity labels. Haulers travel to work and then transfer harvests automatically; individual carried loads and delivery trips are not simulated. The regular catalog offers cottage/camp/farm/bakery, the functional Quarry/Rock chain, and nine cosmetic decorations; advanced recovered production chains remain unfinished. One expansion and eight opening goals are implemented. Known ObjectDB/resource warnings at automated shutdown remain; they are not claimed fixed.

## Verification

From this repository in PowerShell:

```powershell
./tools/validate_windows.ps1 -Godot '../.tools/godot/Godot_v4.7.2-stable_win64_console.exe' -Graphical
```

The runner gives every suite a fresh isolated profile under `.validation/runs/`, imports/parses the project, runs foundation, restoration, real mouse/keyboard interaction, first-playable economic tests, scale/layout tests, and injected touch/lifecycle tests, then checks headless startup, Compatibility rendering, and Forward Plus gameplay. It rejects script/runtime errors, with documented exclusions for this machine’s root-certificate diagnostic and existing resource-in-use shutdown diagnostic. Logs remain in `.validation/`.

Tests cover the whole cottage → villagers → jobs → wheat → cookies → sale → goals → expansion → save/reload path; reserved-input conservation; missing inputs/staff; worker limits and duplicate jobs; legacy migration; repeated-load reward/population safety; corrupt-primary backup recovery; move/demolish occupancy and assignments; UI input isolation; and pan/zoom/selection/placement. Native RAW artwork comparison remains in the rendering test.

Historical restoration research and qualifications: [PROJECT_AUDIT.md](PROJECT_AUDIT.md), [FEATURE_MATRIX.md](FEATURE_MATRIX.md), [ASSET_LICENSE_AUDIT.md](ASSET_LICENSE_AUDIT.md), and [FIRST_PLAYABLE.md](FIRST_PLAYABLE.md).


## Scale, orientation and layout editing

The shared renderer measures visible alpha bounds and applies centralized native scale/ground anchors from `data/building_visuals.json`. Town Hall reads as a civic building; cottage, camp and bakery art no longer stretches to fill the entire plot. Gameplay footprints are unchanged, including the playable Cottage and Farm’s 2×2 tiles. Catalog thumbnails, construction, placement ghosts and placed buildings use the same rules. The selected panel’s Overview / Workers / Layout tabs keep important actions reachable.

The model represents four quarter-turn grid orientations. Current cottage, logging camp and farm assets expose **two front views: original and mirrored**. These are not front/rear views. Town Hall and sign-bearing shops (including Baker Shop) retain **one verified view**, avoiding reversed lettering/clock details. Numbered cottage sprites are color variants; seasonal prefixes are skins. No verified four-direction structure set was recovered. Legacy facings remain represented in older saves and are labelled explicitly when no matching supported view exists.

During placement use **R / Shift+R**, or the visible turn buttons. For an existing building, use **Layout → Preview turn** or R while selected. A green/red ghost and short reason show whether the new geometry and entrance can be reached. Confirm applies; Escape/Cancel preserves the original. Rotation-only editing keeps the position pinned; **Move position / Pin position** switches editing modes explicitly. Move and rotate preserve identity, staffing, stored output and partial recipes, with fresh path calculations on confirmation. Town Hall remains protected from moving/demolition.

New edits must fit inside town bounds, leave their entrance accessible, and preserve previously reachable building entrances. Older saves with blocked default entrances may retain a valid perimeter entrance for compatibility. Editing such a building validates a new orientation-aware entrance. Existing impossible/overlapping layouts are never silently relocated or deleted.

## Optional landscape brushes

Dirt paths cost **1 Gold per tile**; flower beds cost **2 Gold + 1 Wood**; decorative fences cost **1 Wood**. All three are cosmetic and **block neither movement nor building placement**. Fences are garden trim, not barriers. Workers do not require paths. Painting starts on empty land, skips occupied/previously decorated tiles, and shows the full stroke’s cost before release. Revisiting a tile within a stroke or repainting existing tiles does not charge again. An unaffordable stroke applies nothing. Erase first to replace a decoration; erasing gives no refund. Escape discards an unfinished stroke and exits the brush.

Connected dirt diamonds are drawn procedurally because the recovered road sprites depict stone/brick, not dirt. Flowers and fences reuse recovered sprites. The separate ground layer remains beneath buildings/villagers, saves tile positions, and permits new painting on expanded land. A later building may cover existing cosmetic tiles; those remain saved underneath it.

## Developer building preview

Open `tests/BuildingPreview.tscn` and press **F6**. Previous/Next visits **all 274 definitions**, including content outside the regular catalog. Change facing cycles only supported views. Every page uses the same 64×32 grid, villager reference and 0.7 display zoom. Missing mappings are explicitly marked. The tool is developer-only and does not save or overwrite your town.

The automated scale audit currently finds **108 mapped definitions and 166 unmapped definitions**. Unmapped does not necessarily mean the source game lacked art: some still need animation/asset reconstruction. Those definitions remain footprint placeholders and are not added to the playable catalog. [BUILDING_VISUAL_AUDIT.csv](docs/BUILDING_VISUAL_AUDIT.csv) lists every definition, bounds and supported views. True rear/directional art is still needed for the active buildings; the bakery and civic clock also need genuine alternate artwork before exposing additional views.

## Touch controls and phone preparation

- Drag one finger anywhere on the map to pan; pinch two fingers to zoom around their moving midpoint. Drags/pinches never place or select a building. Mouse wheel, ground/middle drag, and keyboard shortcuts still work.
- Tap **Build**, select a catalog card, tap a clear site, use **Rotate**, and press **Confirm**. **Cancel** discards the preview. Select a building and open **Layout** for Move, Rotate, and Demolish; demolition has a separate confirmation.
- Tap **Landscape**, choose a tool, tap tiles to preview a stroke, then **Confirm**. Dragging still pans. **Cancel** discards the pending stroke. Desktop brush dragging retains release-to-apply behavior.
- The toolbar scrolls horizontally. **Goals** opens/closes the objective panel; **Close** collapses drawers. Building details scroll vertically. Market quantity has visible minus/plus buttons, so selling never requires typing. Touches that begin on controls cannot become map gestures; emulated mouse input remains available to GUI controls and is excluded from gameplay.
- Debug builds expose **Perf** in the touch toolbar (F3 on desktop), showing frame time, FPS, draw calls, and static memory. Release builds omit this display.

The existing Compatibility renderer is now the default for both routes. Runtime audio uses bundled JSON instead of reading the source archive, and resource loading recognizes exported `.tres.remap` entries. Export presets exclude research, tools, tests, and the extracted original archive, while including runtime JSON. No plugin, backend, game account, or paid service was added.

A paired desktop Compatibility probe on a 48×48 town at 1152×648 measured median process time **22.177 → 3.855 ms**, p95 **25.678 → 5.693 ms**, and draw calls **2807 → 175**. Grass tiles/blades now share cached mesh geometry; land-size polling was replaced by change signals. These are local desktop measurements, not phone benchmarks.

The complete desktop regression runner passed import, foundation, restoration, interaction, economy, scale, layout, touch, startup, and graphical checks. Focused touch tests also activate actual GUI controls via injected touch-to-mouse events, including catalog selection, staffing, sale, Confirm, and Cancel. Production/travel use explicit simulation ticks for deterministic assertions. Existing shutdown resource diagnostics remain documented. A production Web build now completes with verified official templates. Desktop browser tests verify startup, actual IndexedDB saving, service-worker caching, and offline reopening. No native iOS export, Safari test, or physical iPhone test has been performed.

**Next:** see [WEB_DEPLOYMENT.md](WEB_DEPLOYMENT.md) for automated builds and Pages deployment, then follow [MOBILE_TESTING.md](MOBILE_TESTING.md) to add the confirmed live game to your iPhone Home Screen and run the airplane-mode/save checklist. Native iOS is the final route for app-local storage; it requires macOS/Xcode and signing setup.

## Automated Web/PWA deployment

[The iPhone Web workflow](.github/workflows/iphone-web.yml) uses Linux, verified official Godot 4.7.2 downloads, regression tests, production export validation, real browser saving/offline checks, and the official Pages deployment actions. Development branches and pull requests build without publishing. Approved merges to `main` deploy automatically; explicitly authorized `phone-test-*` tags support first-device tests without overwriting `main`. Generated exports are artifacts, not source commits.

See [WEB_DEPLOYMENT.md](WEB_DEPLOYMENT.md) for build status links, repository settings, installation, update behavior, and limitations. The game displays **Offline: ready** only after service-worker installation. Updates retain local saves; browser eviction remains possible. Browser controls scale in CSS pixels so Safari toolbar resizing does not shrink touch targets.

## Compact phone HUD

Mobile landscape uses a 28 px resource row (14 px type; wraps for narrow screens or large values) and a 44 px horizontally scrollable toolbar. Gold, Wood, Wheat, Lvl, XP, Pop/capacity, Jobs, Free and Cookies remain visible. Center and New town use shorter labels. The full-width permanent instructions are replaced by a **?** help dialog; gameplay notices appear for four seconds. Dialogs block map input.

Goals start as a small 44 px tall objective card. Tap it or **Goals** to expand/collapse full objective and reward details. Build is a floating 96×44 px button; contextual Confirm/Cancel and drawer controls retain their larger targets. Safe-area and CSS-pixel sizing remain active. Desktop HUD formatting is unchanged.

Validation includes injected touch gameplay and lifecycle checks, goal expansion/collapse, Help, resource visibility and reachable drawers at 740×360, 852×393, 1152×648 and 1440×660, plus desktop browser IndexedDB saving and offline reopening. These are desktop simulations, not physical iPhone/Safari tests. The user has reported the earlier live build working on their iPhone; this revised layout still needs device feedback. Further shrinking below 44 px touch targets is not recommended before that feedback.

## Classic art and levels 1–50

The classic phase keeps the working medieval building sprites and compact phone HUD, adds warmer detailed meadow rendering, contact shadows, smaller farm/decorative proportions, and original connected dirt/cobblestone/slab mesh artwork. All three path materials connect at corners/junctions; repainting a different material charges its new cost. Touch Landscape offers Dirt, Flowers, Fence, Erase, Cobbles, Slabs and explicit Confirm/Cancel, with the preview cost shown before committing.

**Levels** opens the scrolling 1–50 roadmap, XP bar, requirements and thumbnails. Level-ups aggregate into a dismissible celebration while simulation continues. Existing cottages/camps remain available at bootstrap; Farm/Bakery at 1. Quarry/Rock unlock at 2, then decorative Barrel (3), Bench (5), Crates (8), Birdbath (12), Buttercups (16), Daisies (20), Birch (25), Campfire (30), and Cart (35). Levels 2–50 each add 10 storage per supported finite material. The curve and later rewards are reconstruction balance, not a claimed original historical table. Advanced wool/cloth/workshop/landmark chains remain planned and are not listed as playable.

Save version 4 preserves previous progress, structures, rotation, assignments, timers, paths and resources; it grandfathers previously owned content and prevents repeat construction XP. Migration never replays old level-up notices. Do not roll back to older game code after saving with this version. Normal offline/browser save policies remain unchanged.

See [CLASSIC_PHASE.md](docs/CLASSIC_PHASE.md) for the architecture audit, reference research, complete scope, costs, migration and test coverage. Run `tools/validate_godot.py --godot <path> --graphical` for 13 phases including ClassicTests; `tests/ClassicVisualProbe.tscn` captures a disposable sample town and roadmap to `.validation/`. No iPhone performance or Safari test is implied by desktop rendering or browser simulation.
