# Playability update — 2026-10-15

This update follows the initial repository audit and supersedes the affected status
entries in PROJECT_AUDIT.md and FEATURE_MATRIX.md. It responds to the upside-down,
incorrectly colored artwork and the lack of useful interactions in the prototype.

## Artwork diagnosis and repair

The existing convert_raw.py interprets native RGBA pixels as BGRA and vertically
flips them. Directly decoding LITTLECOTTAGE.RAW's nine-byte header and RGBA pixels
produces an upright, yellow-roofed cottage. The committed PNG has the opposite
orientation and incorrect color channels. There are 737 RAW sources and 737
converted PNGs in this checkout.

A shared CanvasItem shader undoes those two legacy transformations for building
sprites, build-menu icons, building popup previews and walker icons. No original
file or converted PNG byte was changed. The existing converter is retained for
historical reproducibility: do not regenerate the PNGs with a different pixel
convention without also removing/versioning this display correction. z2raw atlas
animation decoding remains a separate unfinished problem.

The graphical regression renders a cottage, reads a pixel from the actual viewport,
and compares it to a direct native RAW decode. This checks the displayed colors
and orientation, rather than just checking that a texture exists.

## New interactions

- Mouse wheel zooms around the pointed town location; middle-drag pans.
- A subtle square grid shows placement cells; normal buildings no longer retain
  colored placeholder rectangles. The placement preview retains its footprint.
- Build categories scroll, show resource costs, and have a close button. Farm is
  now exposed with its existing imported cost and recipe. Other imported buildings
  still need catalogue/prerequisite work.
- Collect resources transfers local building stock within inventory capacity;
  automatic haulers remain supported. This manual collection is a prototype aid.
- Sell 1 Wood and Buy 1 Wheat expose existing offline market transactions. Prices
  are the existing invented single-player substitute, not recovered original prices.
- Time toggles 1x, 60x and 360x production speed for testing. It does not change
  recipe constants, persist the speed, accelerate construction, or implement offline
  catch-up. Hunger continues using real time, as before this update.
- A producer popup shows idle citizens and housing. Release staff removes worker
  and hauler assignments and lets those citizens take other jobs.
- Placing completed housing fills available housing capacity with persistent
  individual Villager resources. Immediate arrival is a prototype substitute;
  original construction/arrival timing and animated idle citizens remain unfinished.
- The level-zero threshold is now 1 XP, directly from Settings.xml User/XP level=0.
  Later hardcoded thresholds still require source reconciliation.
- Prototype Town Hall Wheat capacity is 500, alongside its existing 500 Wood:
  explicitly temporary storage to keep food purchasing/collection usable. This
  is not a claim about the original Town Hall's storage capacity.

## Try it

1. Stop the running game, allow Godot to reload the changed scripts, then run F5.
2. Build a Small Cottage and select the existing Logging Camp.
3. Assign a worker and hauler, close the popup, and select Time: 360x to see
   production promptly. A housed prototype worker gathers about one Wood/second
   at this setting; this is accelerated test time, not a canonical rate.
4. Collect if needed, sell Wood for Gold, and buy Wheat to feed workers. Existing
   hunger is still a provisional mechanic and consumes Wheat every real minute.
5. Build more housing for additional staff or release existing staff and assign
   them to a Farm. Save using the in-game Save/F5 control before closing.

The current saved layout is preserved. The art fix also applies to existing saves.
Use the existing codex/offline-restoration-audit branch. If using a separate clone,
stop Godot before pulling and let it reimport after the update.

## Validation and limits

Windows validation: import, 60 foundation assertions, 27 restoration assertions,
headless Main launch, and graphical Compatibility integration with one extra
native-pixel artwork assertion (28 assertions in that run). Known root-certificate
and headless audio-resource shutdown diagnostics remain explicitly reported by
validate_windows.ps1. Scene-method/button-signal checks are not a full manual
playthrough or an audio-listening assessment.

Still unfinished: isometric terrain, real villager pathfinding/cargo transport,
shop crafting, construction timing, full prerequisites/upgrades and faithful
progression/economy. The background grid is square and is not presented as a
finished recreation of the original game's world renderer.
