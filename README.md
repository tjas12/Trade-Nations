# Trade Nations — first playable offline town

This Godot restoration now has a playable local economy: housing and villagers, construction, wood and wheat production, cookie processing, local sales, eight rewarded goals, and one land expansion. It uses the recovered isometric artwork. No accounts, network service, paid dependency, or database is required.

## Open and play

Use **Godot 4.7.2**, the installed version used for validation. Open this checkout’s `project.godot` in Godot and press **F5**. In this workspace the correct project is:

`C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\Faithful_reboot\project.godot`

Stop a running session with **F8** before relaunching. Avoid the older downloaded `trade-nations-codex-offline-restoration-audit-(2)` copy. The interface supports 1152×648 and larger windows.

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
| Place / rotate / cancel | Left-click / R / right-click or Escape |
| Grid | Grid toggle; shown automatically during placement |
| Local save / quick load main slot | Save or F5 / F9 |
| Choose saved town | Load |
| Staffing | Selected building: assign worker/hauler, unassign a selected citizen, or release all staff |
| Move | Selected building → Move; free, preserves construction and production state; Escape cancels |
| Demolish | Selected building → Demolish… → confirmation |
| Developer clock | F3 reveals a separate time-speed button; hidden by default |

Demolition refunds 50% of current configured building costs, rounded down. Reserved recipe inputs and stored harvests return up to available inventory capacity; excess does not transfer. Staff become available, residents remain and may lose housing. Town Hall is protected. Move/demolish never silently resolve old placement conflicts. Trees and flowers are cosmetic, outside the usable plot, and never block input or occupy cells.

## Local saves

Main save: `%APPDATA%/Godot/app_userdata/Trade Nations Reboot/saves/slot_1.tres`. Numbered archive slots share that directory. Saves are manual; press Save/F5 before closing. New town archives the current in-memory state before resetting it.

Version 2 preserves buildings, construction, individual villagers, positions, home/job links, production progress and reserved inputs, resources, XP/unlocks, objective claims, recorded production/sales, and expansion. Version-1 saves migrate in memory and are only updated on an explicit save. Housing reconciliation repairs missing arrivals without duplication. Existing plot sizes, buildings, stock, and valid jobs remain; conflicting duplicate jobs are normalized to one job per person.

Writes use a validated pending file and retain a valid previous generation as `.backup.tres`. Loading falls back to that backup if the primary is invalid. If neither copy is readable, files remain unchanged and main-slot saving is blocked. Copy the save directory before manual recovery. Unknown future save versions are rejected. **Production pauses while the game is closed**: there is no offline catch-up or repeated offline reward calculation.

## Content and limits

`data/first_playable.json` contains the playable catalog, costs, unlock levels, cycle durations, yields, staffing, sale/food prices, expansion, and objective rewards. DataManager applies these explicit balance overrides to existing definitions. The existing Baker Shop and Cookies recipe are connected; Cookies is a new inventory resource, rather than the imported recipe’s immediate Gold reward. Original recovered assets and source data remain available.

Character bodies/directional animations have not been reconstructed: villagers currently use an existing portrait sprite with simple movement and activity labels. Haulers travel to work and then transfer harvests automatically; individual carried loads and delivery trips are not simulated. The regular catalog deliberately offers the completed cottage/camp/farm/bakery chain; other recovered content remains unfinished. One expansion and eight opening goals are implemented. Known ObjectDB/resource warnings at automated shutdown remain; they are not claimed fixed.

## Verification

From this repository in PowerShell:

```powershell
./tools/validate_windows.ps1 -Godot '../.tools/godot/Godot_v4.7.2-stable_win64_console.exe' -Graphical
```

The runner isolates saves under `.validation`, imports/parses the project, runs foundation, restoration, real mouse/keyboard interaction, and first-playable economic tests, then checks headless startup, Compatibility rendering, and Forward Plus gameplay. It rejects script/runtime errors, with documented exclusions for this machine’s root-certificate diagnostic and existing resource-in-use shutdown diagnostic. Logs remain in `.validation/`.

Tests cover the whole cottage → villagers → jobs → wheat → cookies → sale → goals → expansion → save/reload path; reserved-input conservation; missing inputs/staff; worker limits and duplicate jobs; legacy migration; repeated-load reward/population safety; corrupt-primary backup recovery; move/demolish occupancy and assignments; UI input isolation; and pan/zoom/selection/placement. Native RAW artwork comparison remains in the rendering test.

Historical restoration research and qualifications: [PROJECT_AUDIT.md](PROJECT_AUDIT.md), [FEATURE_MATRIX.md](FEATURE_MATRIX.md), [ASSET_LICENSE_AUDIT.md](ASSET_LICENSE_AUDIT.md), and [FIRST_PLAYABLE.md](FIRST_PLAYABLE.md).
