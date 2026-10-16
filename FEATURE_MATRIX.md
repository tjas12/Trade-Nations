# Feature matrix — 2026-10-15

"Verified" means exercised by the engine in this pass. "Source" means inspected
implementation only; data presence is not treated as a finished feature.

| Feature | Status | Evidence / limitation |
|---|---|---|
| Godot import and main scene | Verified | 4.7.2 headless and graphical Compatibility launch |
| Offline runtime | Source + local execution | No network client calls found in runtime GD; original endpoints remain in archival data only |
| Grid placement and cost deduction | Verified basic path | Cottage placed through real scene methods; duplicate affordability recheck |
| Bounds/overlap preview | Partial | Square-grid checks exist; rotation geometry and picking remain risky |
| Isometric terrain | Missing | Flat background, square positions |
| Rotation | Partial | Whole node rotates; grid math can disagree |
| Camera pan/zoom | Missing | No Camera2D/controller |
| Touch controls | Missing | Mouse/key flow only |
| Housing capacity | Verified numeric model | Existing foundation tests; no citizen arrival system |
| Individual citizens | Partial | Persistent Villager Resources and cosmetic walkers |
| Worker/hauler assignment | Verified | Two seeded villagers, production building roles |
| Unassign/adopt/new arrivals | Missing | Stubs / no house-driven arrivals |
| Actual walking logistics/pathfinding | Missing | Icons move cosmetically; no path/cargo simulation |
| Gathering | Verified prototype | Continuous rate, local storage, full-storage pause |
| Hauling | Verified numeric transfer | Instant per frame; not transport simulation |
| Storage capacity | Verified | Completed storage buildings aggregate capacities |
| Refiner input consumption | Missing | Production loop ignores recipe input requirements |
| Recipe catalogue | Partial | 122 files, not 122 working jobs |
| Shop crafting | Missing | No recipe selection/timed crafting/reward loop |
| Construction | Missing simulation | Fields and times exist; new placements default complete |
| Coins | Partial | Inventory ledger, placement costs and market API |
| XP/levels | Broken initial progression | Level 0 lacks a threshold; later partial hardcoded table |
| Unlocks/prerequisites/limits | Missing enforcement | Schema/imported values only |
| Building upgrades | Missing | Relationships exist as data |
| Market | Partial | Local API tested; no main scene market UI |
| Social/friends/mail | Partial substitute | Local APIs; no social menu, gift/reset risks |
| Magic Beans | Partial substitute | Local exchanges exist; CurrencyManager still stubbed |
| Tutorial | Partial | Three readable objectives; only build/assign handlers, no persisted completion |
| Quests | Missing | No complete original objective/reward system |
| Static building art | Partial | Converted PNGs, including mismatched seasonal sprites; rights unverified |
| Citizen animation | Missing | Wood icon and scale pulse |
| Audio | Partial | 53 sound definitions mapped, WAV playback code; no listening QA |
| Save/load | Verified basic state | Manual slot 1 controls/startup load; nested state and assignments round-trip |
| Backup recovery | Verified structural case | Valid previous generation restored after invalid primary |
| Offline timer catch-up | Missing | Clock helpers exist; no catch-up simulation |
| Save migration/full corruption validation | Missing | Structural checks only; old prototype IDs need mapping |
| Windows export | Unverified | No presets/export/templates run |
| iOS | Deferred | No export or device validation |

The full economic/progression loop is **not complete**. See PROJECT_AUDIT.md and
RESTORATION_ROADMAP.md before treating upstream completion claims as evidence.
