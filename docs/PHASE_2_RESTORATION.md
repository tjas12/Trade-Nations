# Phase 2 — historical gameplay restoration

## Scope and baseline

Work starts at `04c8dc4` on `codex/classic-graphics-progression`; `codex/historical-gameplay-restoration` preserves that ancestry, root AGENTS instructions, permanent references, graphics, paths, touch controls and 50-level architecture. All 13 baseline phases passed before gameplay edits. This is an incremental implementation, with the brief's priority given to complete housing and foundational production rather than unfinished late-game breadth.

The reproducible [original building catalog](ORIGINAL_BUILDING_CATALOG.md) audits all 274 imported definitions: 271 unique recovered originals plus three synthetic compatibility IDs. `tools/build_historical_catalog.py --implemented` reads the manifest, XML fragments and active nodes, retaining original costs, times, footprints, workers, taxes, recipes, upgrades, store flags and expiry evidence. It never rewrites extracted originals. The permanent [research library](ORIGINAL_GAME_REFERENCES.md) remains the starting point.

## Housing and civic upgrades implemented

| Original ID | Residence | Historical level and civic prerequisite | Base residents | Tax per active interval |
|---|---|---|---|---|
| 12 | Small Cottage | 1 | 1 | 5 Gold + 2 XP / 4 hours |
| 37 | Large Cottage | 4, Tower (2) | 2 | 8 Gold + 4 XP / 6 hours |
| 142 | Brown House | 8, Keep (3) | 3 | 12 Gold + 6 XP / 8 hours |
| 14 | Stone House | 14, Fort (4) | 4 | 20 Gold + 10 XP / 12 hours |

These are literal bundle-4.0.1 fields in `Vanilla_BuildingsTo10.xml` and `Vanilla_Buildings10Plus.xml`, high confidence for that version. Earlier guides differ (for example the Large Cottage tax interval); they do not override the extracted version.

Small → Large → Brown → Stone upgrades mutate the existing instance only when construction finishes. Positions, orientation, IDs, residents/home links, worker assignments and unclaimed taxes remain. Original housing stays usable during a paid upgrade. Repeated taps cannot double-charge. The Overview shows upgrade choices and a priced confirmation; Cancel before confirmation charges nothing. Full target construction cost is used; original upgrade-payment semantics beyond the Cost tag remain unverified. Pending upgrades cannot be demolished.

The existing synthetic starter ID 10012 remains a one-per-town compatibility exception: two residents at bootstrap with prior costs. It maps to original 12 for upgrading; the extra resident becomes a persistent bonus through later tiers. Additional classic cottages use ID 12 with one default resident. Existing excess starter cottages and all villagers remain on migration; further purchases obey limits. Optional/adoptable original rooms are recorded but adoption/premium mechanics are not implemented.

Housing/shop limits use active `Settings.xml` MaxBuilding entries by player level, counting actual structures including construction, not residents. Existing over-limit towns are preserved; upgrades do not consume another housing slot. The two bootstrap residents retain Town Hall housing. No player is forced to replace old buildings.

Town Hall (compatibility 10001 / original 1) → Tower 2 at 4 → Keep 3 at 6 → Fort 4 at 10 are playable in-place upgrades with original costs/prerequisites, protected civic identity and existing storage/housing floors. Original Castle 5 at 20 → Citadel 221 at 30 is documented, but not enabled: CASTLE_1/CITADEL art has no verified complete runtime mapping and late-game support is unfinished. Do not substitute BLUECASTLE icons or placeholders and claim restoration complete.

Tax accrues only through the existing active simulation. Overview Collect and the existing top Collect control can claim it. One ready batch is retained until claimed; that cap is a reconstruction policy because XML does not establish server accumulation behavior. Claim fields are cleared before rewards, persist through saves/upgrades, and cannot replay on resume. No offline catch-up was added.

## Original resource processing implemented

| Building / ID | Required level / civic parent | Input → unit output | Units per worker-hour | Worker / hauler slots |
|---|---|---|---|---|
| Pen 36 | 10 / Keep 3 | none → Wool 50 | 30 | 1 / 1 |
| Lumber Yard 15 | 6 / Tower 2 | 2 Wood 10 → Lumber 11 | 30 | 2 / 2 |
| Stone Cutter 17 | 12 / Keep 3 | 2 Rock 20 → Cut Stone 21 | 15 | 2 / 1 |
| Loom 23 | 14 / Fort 4 | 2 Wool 50 → Cloth 51 | 20 | 2 / 2 |

Original Produce/Input/Output/Rate/Workers fields are retained in the catalog and runtime evidence JSON. Continuous rates become one-unit discrete cycles of 3600/rate seconds, scaled by ready workers. Inputs reserve atomically once; output stays in local stock until collected or hauled. Construction is capped at 30 seconds for new adapters; original durations remain in the catalog. Mayor energy actions and original batch Item alternatives are not exposed. Existing Camp/Quarry/Farm cycles and the Cookies compatibility chain retain their previous accelerated balance and pending inputs/timers.

Stockpile 25 (level 1, 1,000 of each original material) and Large Stockpile 26 (level 6 plus Tower, 3,500 each) are functional, purchasable/upgradable storage. They make original material costs attainable. Additive capacity and inherited Town Hall floors are reconstruction aggregation; historical raw capacities remain documented. Premium warehouses are not advertised. Material IDs and old inventory quantities are unchanged. New material counters appear when relevant or held; the existing HUD wraps compactly when needed.

Lumber/Cut Stone/Wool/Cloth can be sold at fixed offline prices 8/12/5/14 Gold. These prices are explicit reconstruction estimates in `historical_gameplay.json`, not recovered market prices. The existing expansion remains unchanged; original Items.xml land sizes/costs are researched separately.

## Commercial work implemented

Carpenter Shop 32 unlocks at level 6 with Tower; Pub 38 at 16 with Fort. Their selected recipes use literal Items.xml ingredient quantities, durations, Gold payouts, XP and recipe levels. Carpenter Table (item 10) consumes 6 Wood, takes 300 seconds and pays 40 Gold + 20 XP. Each shop uses one active worker/no hauler as an offline adapter where Workers metadata is absent; that count is not presented as verified historical staffing.

Baker Shop 35 retains its existing Cookies-to-inventory job (item 40) for save/tutorial compatibility, and gains its other original paid jobs. New Baker eligibility is the recovered level 2; earlier earned access is grandfathered. New recipe selection never discards reserved inputs: a change queues behind the paid current job and activates at completion. Current recipe, queue, elapsed time, staff and reservations persist on reload. Shop output pays the original rewards directly; it is not a fake decorative business.

Theater 167 (bundle level 26, Castle prerequisite), Jeweler 237 (41, Castle), and further shops remain cataloged/planned. The January 2011 Theater timings/levels differ from bundle 4.0.1 and are not mixed into a fabricated schedule. No unavailable shop is listed as playable.

## Levels 1–50

`data/progression.json` now takes literal XP thresholds and house/shop allowances from bundle-4.0.1 Settings rows, retaining the project cap of 50 even though the recovered bundle declares 70. Every row cites its source and records unresolved extra rewards. Registered original IDs use recovered prerequisites/levels; starter aliases are explicit bootstrap exceptions. Original shop recipe levels enrich roadmap and celebration entries. Only implemented content appears as playable; absent late-game rewards are unresolved, not invented.

Previously earned levels and within-level XP are never recalculated or reduced. Prior unlocked IDs are grandfathered using the saved array and old registry map. Prototype +10 storage-per-level benefits are retained per legacy save; new levels advertise actual historical allowances and implemented unlocks rather than repetitive invented storage rewards. The progression screen remains dismissible and does not pause simulation. Multi-level catalog refresh is coalesced into one rebuild.

## Graphics and performance

No general graphics overhaul or new raster dependency was introduced. Previously recovered cottage, house, processor, Pen, shop, civic and storage sprites are activated through the existing corrected renderer and bounded scale/rotation fallback. New normalized footprints are 2×2 for houses and 3×3 for new workshops/storage/civic adapters, keeping upgrades in place. These are compact-grid reconstruction dimensions; exact original sizes remain in the catalog. Stockpile floors receive a small signal-driven cosmetic resource-bin overlay (`storage_piles.gd`), not per-frame resource sprites or new simulation.

A 48×48 desktop Compatibility idle probe measured 177 draws and about 65.97 MB static memory (previous phase: 177 draws/about 61.27 MB). Median process was 3.114 ms in this run; sample timing is noisy. A 50-villager/25-producer/1,024-path-tile fixture exposed the old per-villager whole-town hover scan. Centralized 100 ms desktop hover selection and save-aware citizen references changed measured median/p95 from 29.628/81.076 to 5.746/5.746 ms, at 195 draws/about 70.50 MB. These are local desktop observations, not iPhone benchmarks or guaranteed FPS. Touch names remain available in Workers details; no hover dependency is introduced.

## Save migration and validation

Version 5 adds pending upgrade/elapsed fields, housing compatibility bonus, tax progress/claim fields, queued recipe and grandfathered storage bonus. Versions 1–4 keep all structures, locations, rotations, villagers, assignments, currencies/resources, paths, old unlocks, tutorial state and production fields. New fields default safely; migration emits no backlog level celebrations/taxes. Existing validated pending-write/backup autosaves and focus/resume policy remain. Do not roll back to pre-v5 builds after updating a save.

Baseline 13 phases passed before edits. The expanded local runner passed 16 phases: import; foundation, restoration, interaction, economy/playable, scale, layout, mobile, classic, historical and historical-touch suites; startup; four graphical scenes. New tests exercise all residential tiers, civic/storage upgrades, caps, tax claims, primary XP thresholds, four processing inputs/rates/haulers, original Carpenter/Pub payouts, queue transitions and real touch confirmation/cancel/tax/dropdown interaction. All 17 newly advertised paid recipes were executed against their recovered Gold/XP/level values. Added serialization tests verify a paid job/queue and pending housing upgrade together, plus pause/resume and exactly-once persisted tax collection. Full Linux/export/browser checks and the final live deployment record are reported in WEB_DEPLOYMENT.md once completed. Existing Windows root-certificate and shutdown resource diagnostics are not claimed fixed.

Screenshots are generated in `.validation/` by HistoricalVisualProbe; HistoricalPerformanceProbe is a disposable, unsaved stress fixture. Browser checks use disposable profiles. No physical iPhone/Safari test is claimed.

## Remaining work

Restore/verify complete Castle/Citadel/Jeweler art and dependencies; implement later shops only after prerequisites are playable; research adoption, timed/event store eligibility, original server shop orders, resource-site placement/depletion, directional animations and exact upgrade payments. Validate long-session balance and the new UI on the physical iPhone, then expand the historical catalog incrementally. Recovered original cap 70 is outside the current 50-level playable target.
