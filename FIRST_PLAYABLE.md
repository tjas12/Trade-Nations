# First playable implementation — 2026-10-24

The active Godot project is Faithful_reboot, branch codex/offline-restoration-audit. This completes a deliberately small offline economy on the existing Resource/DataManager, WorkerManager, EconomyManager, SocialManager, TutorialManager, SaveManager, and Main architecture.

## Balance and content

The recovered Small Cottage, Logging Camp, Farm, Baker Shop, and Cookies recipe are reused. `data/first_playable.json` applies explicit balance overrides without editing recovered source XML. New-town plot size is 16; existing saves keep their previous land size. Farm and bakery use 2×2 footprints. Recipe 50008 gathers 4 Wood/10s, 50011 gathers 4 Wheat/12s, and recipe 40 processes 3 Wheat into 2 Cookies/18s. The first four available citizens can staff camp worker+hauler, farmer, and baker; raw farm output can be collected manually. Later housing supports more haulers. Sales and automatic objective rewards fund one eight-tile expansion.

## Accounting and saved state

Discrete cycles validate all inputs before reserving them. Reservation and elapsed time are exported on BuildingInstance. Completion clears the reservation and grants one configured output exactly once. Input/staff/storage shortages pause progress. Large simulation steps complete at most one cycle per call, discarding surplus time; the game does not simulate closed-app time. Continuous imported gathering remains a compatibility fallback for unfinished recovered definitions.

Villager positions/activity are authoritative in WorkerManager, not independent visual loops. AStarGrid2D routes use non-diagonal free cells and building perimeter entrances. Placement, movement, demolition and construction completion invalidate routes; production waits for staff arrival. Existing portrait art provides a functional temporary villager visual. Hauling transfers from local to town storage while its assigned citizen is at work; there is no per-load cargo simulation.

Version 2 adds claims/statistics/expansion and cycle/construction state. Migrations retain buildings and land dimensions, reconcile real housing arrivals, and rebuild valid job links with unique staff membership. Duplicate jobs and stale assignments are repaired; player structures are never relocated/deleted. Future versions and invalid save structure are rejected. Pending writes are validated, valid prior files are backed up, and an unreadable sole primary cannot be overwritten through SaveManager. A malformed primary can recover from a valid backup. Existing conflicts remain represented by the union of occupied cells and can be resolved explicitly with Move.

## UI and verification

Normal UI offers resource/population/employment status, persistent non-modal goals, filtered categorized catalog with costs/locks, scrollable building detail, market, expansion, archives, and confirmation for demolition/new town. Close stays reachable above the building scroll area. Developer clock is separately hidden under F3. Minimum desktop size is 1152×648. Mouse events are routed through GUI before world selection/placement/panning.

The validation runner performs actual engine checks with isolated AppData. PlayableTests drives the entire economic chain using normal starting inventory and simulated time, then verifies mid-cycle reservation persistence, repeated loading, one-time rewards, migration, path obstacles, transactions, and building mutation cleanup. InteractionTests uses real injected mouse/key events, including catalog, staff, market, and camera. Compatibility rendering compares native RAW pixels. Screenshots are produced by Forward Plus runs for visual inspection. Known shutdown ObjectDB/resource leaks and the environment certificate-store diagnostic are retained in logs and explicitly excluded; no clean-shutdown claim is made.

Limitations: temporary portrait movement, instantaneous haul transfer at workplace, manual saving, no offline progress, a limited regular catalog, and one introductory expansion. Balance is an authored first-playable approximation and still benefits from human playtesting. There are no network-backed game systems or new dependencies.
