# iPhone landscape testing

## Current state

This checkout uses Godot **4.7.2**, GDScript, and the Compatibility renderer. There are no enabled editor plugins, GDExtensions, external backend requirements, or game logins. The prepared presets are **Web - iPhone landscape** and **iOS - iPhone landscape** in `export_presets.cfg`.

Touch input, explicit placement confirmation, scrollable landscape drawers, safe-area positioning, offline autosaves, and interruption guards are implemented. Existing desktop controls remain available. The logical mobile reference is 960×440 with aspect expansion, rather than a fixed physical pixel resolution. Native display insets and Safari CSS safe-area insets are mapped into the game viewport. Buttons have a 48-unit minimum; device testing must still check their physical comfort and readability.

**Not completed on a phone:** Safari rendering, IndexedDB persistence, PWA installation/cache, native export/signing, notch/home-indicator placement, actual multitouch hardware, thermal behavior, battery use, or iPhone performance. Desktop event injection is not a device test.

Both export commands were attempted. They stopped at missing matching templates (`web_nothreads_debug.zip`, `web_nothreads_release.zip`, and `ios.zip`). No runnable phone build was generated. The native Team ID is intentionally blank; enter your own on the Mac. The bundle identifier is an editable development suggestion, not a registered app identity.

## First route: Safari Home Screen app

Start here because the current development machine is Windows. Godot recommends single-threaded Web export for iOS; this preset uses WebGL 2 Compatibility, one thread, an adaptive canvas, PWA caching, and a landscape manifest. The shell includes safe-area CSS and a portrait rotation prompt. Browser support still needs testing. [Official Godot Web export guidance](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).

1. Stop the running game. Open **Faithful_reboot/project.godot** in Godot 4.7.2. Use **Editor → Manage Export Templates → Download and Install** for the matching version.
2. Open **Project → Export → Web - iPhone landscape**. Choose **Export Project**, keep debug enabled for the first test, and export to `Faithful_reboot/export/web/index.html`. Keep all generated filenames together. The `export` folder is intentionally excluded from the source branch.
3. Serve the entire `export/web` folder from an **HTTPS** address. A plain HTTP LAN address such as `http://192.168…` does not provide the secure context needed for offline PWA installation. One option using your existing GitHub fork is the separate Pages branch described below; no additional game account is involved. Hosting is not configured or published by this milestone.
4. On the iPhone, turn off portrait orientation lock, open that HTTPS address in **Safari**, and rotate to landscape. Wait for the game to finish loading. Tap once if audio is initially silent.
5. Use Safari’s **Share → Add to Home Screen**, then open the new icon. Use the same Home Screen installation consistently; browser tabs and installed apps may have separate storage.
6. Complete the checklist below, save, wait a few seconds, background and reopen, then enable airplane mode and launch again. Confirm both the game and your saved town return. Repeat after closing the Home Screen app.

PWA installation caches the game after an online visit, but browsers may evict cached files. Saves use origin-local IndexedDB and require permitted storage; private browsing prevents persistence. Clearing website data or changing the hosting origin can remove access to saves. `OS.is_userfs_persistent()` is not a durability guarantee. Filesystem writes sync asynchronously on Web, so even background saving cannot guarantee survival of an immediate OS kill. Use native iOS for the final app-local storage target. [Godot persistence and PWA limitations](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).

### Optional first GitHub Pages upload

After a successful Web export, these **first-publication** PowerShell commands copy only the exported build into a new temporary Git repository. They do not switch branches or remove files in your game checkout. They upload the recovered game assets to your existing fork; run them only when ready to publish that test build. Do not force-push if `phone-web` already exists; update that deployment branch normally instead.

```powershell
$webFolder = 'C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\Faithful_reboot\export\web'
if (-not (Test-Path -LiteralPath (Join-Path $webFolder 'index.html'))) { throw 'Export the Web build first.' }
$phonePublish = Join-Path $env:TEMP ('trade-nations-phone-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $phonePublish | Out-Null
Copy-Item -Path (Join-Path $webFolder '*') -Destination $phonePublish -Recurse
Set-Content -LiteralPath (Join-Path $phonePublish '.nojekyll') -Value ''
git -C $phonePublish init -b phone-web
git -C $phonePublish add .
git -C $phonePublish -c user.name=tjas12 -c user.email=tjas12@users.noreply.github.com commit -m 'Prepare first iPhone web test'
git -C $phonePublish remote add origin https://github.com/tjas12/Trade-Nations.git
git -C $phonePublish push -u origin phone-web
```

In GitHub, open your repository’s **Settings → Pages**, choose **Deploy from a branch → phone-web → /(root) → Save**, if Pages is available for that repository. Wait for deployment and use the HTTPS address GitHub displays (normally `https://tjas12.github.io/Trade-Nations/`). If deployment or push fails, resolve that error before testing; no live URL was verified here. Source updates and Web deployment updates are separate operations.

## Final route: native iOS

Native iOS exports require **macOS, Xcode, and matching Godot templates**. On a Mac, open this project, select the iOS preset, enter your 10-character Team ID and unique bundle identifier, then export an Xcode project. Open it in Xcode, select your signing team and connected iPhone, enable Developer Mode when required, and build/run. Keep the same app identity and update in place to retain its sandbox saves; deleting the app deletes that local data. No cloud save or game login is added. [Official Godot iOS requirements](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).

Apple requires an Apple Account in Xcode for personal-device signing. A free Personal Team supports local testing, with provisioning expiring after seven days and requiring rebuild/reinstallation. Paid membership is not a prerequisite for this first personal-device test. This milestone creates no Apple account and configures no paid distribution service. [Apple’s Personal Team limitations](https://developer.apple.com/help/account/basics/about-your-developer-account/).

Native saves use the app’s `user://saves` directory. The same version-3 resource format, validated pending write, recoverable previous generation, migrations, and no-offline-production policy apply. App-local storage avoids browser eviction, but removal of the app still removes its data.

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
