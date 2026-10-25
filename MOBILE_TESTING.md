# iPhone landscape testing

## Current state

This checkout uses Godot **4.7.2**, GDScript, and the Compatibility renderer. There are no enabled editor plugins, GDExtensions, external backend requirements, or game logins. The prepared presets are **Web - iPhone landscape** and **iOS - iPhone landscape** in `export_presets.cfg`.

Touch input, explicit placement confirmation, scrollable landscape drawers, safe-area positioning, offline autosaves, and interruption guards are implemented. Existing desktop controls remain available. The logical mobile reference is 960×440 with aspect expansion, rather than a fixed physical pixel resolution. Native display insets and Safari CSS safe-area insets are mapped into the game viewport. Buttons have a 48-unit minimum; device testing must still check their physical comfort and readability.

**Not completed on a phone:** Safari rendering, IndexedDB persistence, PWA installation/cache, native export/signing, notch/home-indicator placement, actual multitouch hardware, thermal behavior, battery use, or iPhone performance. Desktop event injection is not a device test.

The production Web export now builds locally with verified official templates. Automated Linux build/test/export and GitHub Pages deployment are implemented; see [WEB_DEPLOYMENT.md](WEB_DEPLOYMENT.md) for the workflow, approval gates, artifacts, and repository settings. Native iOS still requires macOS/Xcode and your signing Team ID.

## First route: Safari Home Screen app

The game is [confirmed live](https://tjas12.github.io/Trade-Nations/) as of 2026-10-25. Ordinary development pushes build/test only; reviewed merges to `main` deploy automatically. The authorized first `phone-test-*` tag deployed successfully while preserving `main`; see [the successful build/deployment run](https://github.com/tjas12/Trade-Nations/actions/runs/40210170164).

1. Open the live address in Safari, disable portrait lock, and rotate to landscape.
2. Wait for loading to finish and **Offline: ready** to appear. This indicates that service-worker installation cached the game files, including WASM and PCK.
3. Choose **Share → Add to Home Screen**, then open the new icon once online. A tap may be needed to enable sound.
4. Complete the checklist below, save, wait a few seconds, background and reopen, then enable airplane mode and launch again. Confirm the game and saved town return.
5. After future deployments, close all old game tabs/Home Screen windows and reopen online. Wait for offline readiness again. Updates do not intentionally clear saves.

Browser caches and IndexedDB can be evicted, private browsing is unsuitable for persistence, and separate Safari/Home Screen installations may have separate storage. Keep the same address and installation. The game reports unavailable browser storage and blocks writes; automated desktop tests also verify actual IndexedDB saving and offline recovery. No browser persistence check guarantees indefinite retention. [Official Godot Web guidance](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).

For a manual local export, install matching Godot 4.7.2 templates, then run `python tools/export_web.py --godot <path-to-godot>`. Serve the resulting complete folder over HTTPS for phone testing. The CI route performs these steps automatically and does not require local export templates. Do not switch Pages back to branch deployment or commit generated exports into the source branch.

## Final route: native iOS

Native iOS exports require **macOS, Xcode, and matching Godot templates**. On a Mac, open this project, select the iOS preset, enter your 10-character Team ID and unique bundle identifier, then export an Xcode project. Open it in Xcode, select your signing team and connected iPhone, enable Developer Mode when required, and build/run. Keep the same app identity and update in place to retain its sandbox saves; deleting the app deletes that local data. No cloud save or game login is added. [Official Godot iOS requirements](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).

Apple requires an Apple Account in Xcode for personal-device signing. A free Personal Team supports local testing, with provisioning expiring after seven days and requiring rebuild/reinstallation. Paid membership is not a prerequisite for this first personal-device test. This milestone creates no Apple account and configures no paid distribution service. [Apple’s Personal Team limitations](https://developer.apple.com/help/account/basics/about-your-developer-account/).

Native saves use the app’s `user://saves` directory. The same version-5 resource format (with version 1–4 migration), validated pending write, recoverable previous generation, migrations, and no-offline-production policy apply. App-local storage avoids browser eviction, but removal of the app still removes its data.

## Device checklist — use no keyboard

1. Build → HOUSE → Small Cottage; tap a clear site. Drag/pinch before confirming: nothing should be placed. Confirm; after construction, population rises by two.
2. Tap Logging Camp → assign a worker and hauler. Wait for travel and Wood production/delivery. Use Collect if needed. Market → minus/plus quantity → Sell. Retain Wheat for food.
3. Select a structure → Layout → Move. Tap a site, rotate, then Cancel: its original position, facing, staff, and stock remain. Repeat and Confirm. Demolish must show its separate confirmation; Cancel must leave it intact.
4. Landscape → Dirt path → tap several empty tiles. Drag/pinch: only the camera should move. Cancel once, then preview again and Confirm; cost is charged only on confirmation.
5. Open/close catalog, details, Goals, and Market; scroll panels and toolbar. Touch their controls over buildings and verify no map action leaks through. Try both landscape directions and check the notch/home indicator.
6. Save → background → reopen. Load the main slot. Confirm buildings, villagers, jobs, goods, paths, progress, and claimed goals. Repeat lock/unlock and background/resume several times; no extra production or repeated rewards should appear.
7. In the PWA, repeat in airplane mode after a successful cached launch. In a debug build, scroll to Perf and record FPS/frame time/draws/memory during panning, pinch, and a busy town. Play for at least ten minutes to assess sustained performance.

## Checks already run

The Windows regression runner passed import, foundation, restoration, interaction, playable economy, scale, layout, touch, startup, Compatibility rendering/art comparison, and Forward Plus regression scenes. Touch simulations cover three landscape sizes, gestures, UI isolation, real emulated GUI button activation, preview cancellation, the cottage/jobs/goods/sale/layout/path chain, saves, and injected focus/pause/resume notifications. Production/travel ticks in that scenario are deterministic, not measured human play time. Known root-certificate and shutdown resource diagnostics remain filtered and reported by the runner.

A local 48×48-town performance probe measured median process time 22.177 → 3.855 ms, p95 25.678 → 5.693 ms, and draws 2807 → 175 after cached grass mesh batching. The camera, tile colors/blades, scenery, building scale, and gameplay are preserved. There is no iPhone benchmark yet.

## Classic phase device follow-up

After updating online, verify your existing town, staff, rotation, inventory, production and dirt paths before making changes. Open Levels, scroll to 50, inspect requirements and close; production must continue. At level 2, build a Quarry, assign a worker and hauler, and sell Rock in Market. Landscape now offers Dirt, Cobbles and Slabs; preview costs appear before Confirm. Test corners, mixed-material junctions, replacing a path, Cancel, Erase and save/reload. Retain the current/newer build after its version-5 save migration. Do not clear website data. Test both landscape directions, Safari bars, Home Screen reopening and airplane mode on the physical iPhone; desktop checks do not substitute for these.

## Phase 2 device checks

Check your existing town before building: level/XP, housing, all staff, resources, rotations, paths and pending production should remain. In Levels inspect restored housing/shop allowances and recipe unlocks. Select a home, open Overview → Upgrade, cancel once and verify no charge, then confirm an eligible upgrade and verify resident/job preservation. Collect a ready tax once; taxes use active simulation time and do not accrue while backgrounded. At the required levels/civic tiers test Pen, Lumber Yard, Stone Cutter, Loom, Stockpile upgrades and Carpenter/Pub jobs. Change a recipe during work: the paid job must finish first. Save/reopen/background mid-upgrade and mid-job. Test the expanded resource HUD and scrolling drawers in both landscape orientations; never clear website data to update. Keep this or newer code after v5 migration.
