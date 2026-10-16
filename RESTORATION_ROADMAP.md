# Restoration roadmap

This supersedes completion claims in the earlier report for the purposes of this
restoration pass. See PROJECT_AUDIT.md for actual execution evidence.

## Phase 1 — audited baseline (this pass)

Completed repository inventory, source/data/assets review, baseline import and
execution, focused repairs, regression tests, Windows graphical launch, and license
inventory. Keep upstream main and original/ untouched. Work locally on
codex/offline-restoration-audit; do not publish the inherited restricted tree.

## Phase 2 — dependable Windows prototype

1. Build a canonical content registry with provenance and explicit prototype status;
   eliminate legacy TRES expressions and add duplicate-ID/type/reference validation.
2. Restore level-zero XP thresholds from Settings.xml. Evaluate prerequisites,
   premium costs, limits, upgrade-only rules and menu categories at placement time.
3. Implement construction state, completion events and visible progress; make one
   Cottage, Camp, Farm and Stockpile available with an achievable initial economy.
4. Fix rotated footprint geometry and preview picking; add camera pan/zoom and
   proper isometric coordinate conversions shared by input, drawing and collision.
5. Extend save validation/migrations, tutorial restoration and clean shutdown save;
   test missing/corrupt primary and backup, cancelled writes and old versions.

Acceptance: a fresh game can build, assign, save, restart and continue through
normal Windows input without errors, stalled progression, free paid buildings or
unreachable required structures. Test both renderer choices and create a local
Windows export only after an explicit restricted-content packaging decision.

## Phase 3 — complete economic loop

1. Housing completion creates persistent individual citizens within capacity.
2. Support assigning/unassigning and persistent work/home/storage references.
3. Add grid navigation and authoritative IDLE, TRAVELLING, WORKING, PICKUP,
   CARRYING, DELIVERING and BLOCKED states. Hauler arrivals determine delivery.
4. Implement capacity reservations and cargo conservation; production stops on
   full local storage, missing workers or input shortages and resumes safely.
5. Implement Farm -> Wheat -> one bakery recipe -> Gold/XP -> unlock -> expansion.
6. Expose local selling/buying through the actual Market UI. Clearly label local
   prices as substitutes; remove real-payment flows, backend prompts and ads.

Acceptance: build housing -> citizens -> workers -> resources -> delivered inventory
-> sale/craft -> Gold/XP -> unlock -> expansion works without developer calls.
Test resource conservation, cost transactions, delivery blockage, reassignment,
construction/save/restart, and interrupted hauling. No content expansion first.

## Phase 4 — faithful restoration

- Track every recipe/time/cost/value against exact XML file/object/item IDs or
  timestamped video observations. Preserve conflicting versions as evidence.
- Recover original footprint/rotation semantics, building upgrades, refiners,
  additional shops, original progression tables, quests, decorations and buffs.
- Replace cosmetic walkers with cleared citizen animations and accurate cargo.
- Add original-style terrain, layered sprites, screen scaling, UI and audio when
  provenance permits. Label temporary artwork and substitute mechanics in-game.
- Replace fabricated hunger/economy values only after evidence review. Bound and
  document offline catch-up, clock changes and local market substitutes.

Acceptance: each restored feature has provenance, focused checks and a playable
review scenario. Personal-use archival references remain separate from any public
or redistributable code/assets package.

## Phase 5 — mobile assessment

After the Windows loop and saves are stable: touch pan/pinch, safe areas, legible
controls, input parity, profiling and mobile storage lifecycle. Assess Godot iOS
export on a Mac with Xcode/signing; Windows alone is not an iPhone export workflow.
Keep Windows behavior covered throughout. No backend or required account enters
the runtime design.
