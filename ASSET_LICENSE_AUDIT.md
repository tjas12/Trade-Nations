# Asset and license audit — 2026-10-15

## Findings

No root LICENSE, COPYING, NOTICE, per-asset license manifest, or permission grant
was found in the tracked repository. GitHub visibility is not a reuse license.
Neither the original assets nor the reboot code can be described as cleared for
redistribution from the evidence supplied. This records evidence, not a legal
opinion. No new distribution or public upload was made during this pass.

| Material | Available | Provenance / reuse status |
|---|---|---|
| original/TradeNations.ipa | 65,907,710 bytes | Original mobile package committed upstream; Z2Live game content, no grant found |
| original/TradeNations.app and extraction folders | Included, 1,318 total original files | XML rules, native app, Lua/Wax glue, UI, localization, images/audio, atlas timelines; reference only, unchanged |
| assets/art/converted/*.png | 737 PNGs | RAW/z2raw conversions of original art; conversion does not establish new reuse rights |
| assets/audio/*.wav | 55 WAVs | Original CAF/audio conversion outputs; no separate music/voice/SFX permissions found |
| Timeline formats | 35 BIN + 34 JSON files in app bundle | Metadata/atlas data survive; complete character animation renderer not implemented |
| tools/ conversion/sample output | Included | Reboot conversion scripts and example image; no explicit code license found; sample image may derive from original artwork |
| scripts/, resources/, scenes/, tests/, docs/ | Included | Reboot implementation/documentation; author permissions/license unresolved |
| Placeholder presentation | In code | Footprint rectangles, Wood-icon walkers and seasonal/static icons are temporary; not faithful citizen/terrain art |
| New changes in this pass | Local Git branch | Original code/docs, but no claim to license upstream or third-party material |

## Useful reference sources

- Resource IDs and starting quantities: original/TradeNations.app/bundle/Resources.xml.
- Building costs/footprints/production/storage: Vanilla_BuildingsTo10.xml,
  Vanilla_Buildings10Plus.xml, seasonal packs and Objects.xml manifest.
- Shop recipes: Items.xml. Levels/villager constants: Settings.xml.
- Sound mapping: Sounds.xml; actual converted audio resides separately in assets/audio.
- Animation references: *_Timeline.bin and *_TimelineFormatIndex.json with texture
  sheets. These need a verified decoder and animation semantics, not just PNG loading.
- research/TradeNations_strings.txt: extracted clues, not licensed implementation code.
- Video_analysis.md: repository notes describing videos, not independently verified
  footage or authoritative numeric tables. Resolve conflicts by version/source.

## Boundaries for future work

Keep original/ read-only and local/private. Do not include originals or converted
PNG/WAV derivatives in a public code export without permission. `.gdignore` skips
Godot scanning; it is not a Git privacy mechanism or export-rights clearance.
Original content already exists in inherited Git history, so deleting working-tree
files or adding .gitignore rules is insufficient for a redistributable repository.
Prepare a separate, reviewed code-only export with cleared placeholders and an
asset provenance manifest when redistribution is actually requested. Do not rewrite
or force-push the inherited history as part of this restoration.

At runtime AudioManager still reads original/bundle/Sounds.xml, so simply excluding
original/ also removes a runtime reference. A future cleared build must materialize
an independently permissible sound catalogue and package only permitted audio.
No archival executable was run, DRM bypassed, original files edited, or extra IPA
fetched from archive.org. The archive URL's availability was not tested because
the requested repository already contains the material needed for this audit.

Track replacements with: path, author/source URL, original source identifier,
license text, permission evidence, conversion command, and whether redistribution
is permitted. Unknown remains unknown until supported by evidence.
