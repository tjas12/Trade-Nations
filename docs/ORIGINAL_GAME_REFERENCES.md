# Original Trade Nations research library

Project objective: faithfully recreate the original **2010–2013 Trade Nations**, while protecting working gameplay, existing towns, mobile performance and offline play. Consult this library and recovered original data before adding buildings, level unlocks, resources, shops or graphics.

Last source review: **2026-10-25**. This is a permanent source index and original research summary, not a mirror of full copyrighted articles/artwork. A link being listed does not mean its contents were verified. Preserve source URLs and update access notes when revisiting them.

## Evidence labels and research rules

- **Recovered primary evidence:** directly inspected original bundle data; identify file, object/recipe ID, attributes, bundle version and any relevant comments.
- **Source-confirmed historical report:** a statement verified in the cited article; scoped to its date/version, not proof that all releases behaved identically.
- **Interpretation:** an inference or translation, explicitly labeled and awaiting corroboration where necessary.
- **Unverified:** inaccessible source, incomplete table, unsupported exact number or unresolved conflict.
- **Reconstruction decision:** our implementation/balance choice. It must never be presented as an original unlock requirement.

Inspect the recovered bundle first, then corroborate with contemporary guides, screenshots and versioned community records. Do not treat commented XML as active rules, tutorial text as a complete prerequisite table, or an object's presence as proof it was purchasable. Resolve file includes, land variants, upgrade chains and store flags. Record contradictions rather than silently blending releases.

## Source catalog

| ID | Source | Provenance / scope | Access and appropriate use |
|---|---|---|---|
| S1 | [Trade Nations Walkthrough — Gamezebo][s1] | Historical third-party walkthrough; exact article publication date/version not established in this review. | Text accessible. Housing, placement, workers/haulers, materials, shops and early progression. The page's current news/sidebar dates are not the walkthrough's original date. |
| S2 | [iPad Trade Nations review/guide, part 1 — Shadowcraze][s2] | Player blog; URL indicates May 2011, but publication metadata/body were not verified. | Retrieval failed (cache miss). Keep as a lead; no mechanics/numbers are confirmed from this source yet. |
| S3 | [Beginners' guide — Pocket Gamer][s3] | Will Wilson, 25 November 2010; explicitly scoped to game version 2.2.0. | Text accessible. Housing, labour allocation, production and market behavior. |
| S4 | [Trade Nations category — 日々の出来事 / e38][s4] | Japanese player notes dated 15 January 2011 in the article body. Category contains “Trade Nations - アイテム経験値一覧” (item experience list). | Text/table accessible through the category page; linked article retrieval failed. Useful dated numeric observations, not an official full unlock table. Translation cautions below. |
| S5 | [Trade Nations Wiki — Fandom][s5] | Community-maintained wiki; individual revision dates/authors not verified. | Retrieval returned a tool-level 402 error. No wiki claims verified. Find stable revision links before using exact values. |
| S6 | [Trade Nations — Bronwyn Burns / Behance][s6] | Original contributing artist's portfolio, published 16 January 2013. | Project text accessible. Primary art provenance and visual direction; not a numeric economy/unlock source. |

## Recovered original data: start here

The repository's [original bundle](../original/TradeNations.app/bundle/) is primary evidence, distinct from our imported/overridden runtime data. Parsing the local `original/TradeNations.app/Info.plist` reports **CFBundleVersion 4.0.1**. Do not infer an exact release date from that field alone, or publish unrelated service credentials/configuration from the plist.

| Artifact | What to inspect | Confirmed observations / caveats |
|---|---|---|
| [Settings.xml](../original/TradeNations.app/bundle/Settings.xml#L177) | `User`, `XP`, `MaxBuilding`, rewards, villager settings | `User maxlevel="70"`; 71 XP entries for levels 0–70. `toNext` begins 0→1, 1→550, 2→750, 3→1100, 4→1400, 5→2000. These are this bundle's literal attributes, not our curve; final-row semantics need runtime corroboration. |
| [Objects.xml](../original/TradeNations.app/bundle/Objects.xml) | Included object files | This file indexes other XML files. Searching it alone will miss buildings. Follow every `File` reference, including `401_Update.xml` and Frontier files. |
| [Vanilla_BuildingsTo10.xml](../original/TradeNations.app/bundle/Vanilla_BuildingsTo10.xml#L148) | IDs, store availability, footprints, prerequisites, upgrades, costs, production | Quarry ID 9 has a level-4 prerequisite and `availableFromStore="0"`; this is not evidence of a freely purchasable level-4 quarry. Small Cottage ID 12 describes one villager and has a level-1 prerequisite. Do not conflate this with land-variant ID 10012. |
| [Vanilla_Buildings10Plus.xml](../original/TradeNations.app/bundle/Vanilla_Buildings10Plus.xml), [401_Update.xml](../original/TradeNations.app/bundle/401_Update.xml) | Later content and overrides | Inspect complete definitions and references before asserting late-game availability; file names alone establish no release chronology or complete unlock sequence. |
| [Resources.xml](../original/TradeNations.app/bundle/Resources.xml) | Stable resource IDs, names and starting amounts | Gold ID 1, Wood ID 10, Rock ID 20; retain identifiers. Distinguish Rock from processed stone and premium currency from stored resources. |
| [Items.xml](../original/TradeNations.app/bundle/Items.xml), [BuildMenu.xml](../original/TradeNations.app/bundle/BuildMenu.xml), [Tutorials.xml](../original/TradeNations.app/bundle/Tutorials.xml) | Shop outputs, menu eligibility, tutorial prerequisites | Cross-reference object/recipe IDs; a displayed item or tutorial instruction is not a universal numeric level requirement. |
| [LandExpands.xml](../original/TradeNations.app/bundle/LandExpands.xml), [Skins.xml](../original/TradeNations.app/bundle/Skins.xml) | Land upgrades, seasonal/land variants and asset mappings | Keep land/skin/version context when comparing footprints, appearance or prerequisites. |

The current `data/buildings/`, `data/recipes/` and `data/resources/` are imported representations. `data/first_playable.json`, `data/progression.json` and `DataManager` apply reconstruction overrides; they are **not independent historical evidence**. [CLASSIC_PHASE.md](CLASSIC_PHASE.md) documents current implementation decisions.

## Housing

**Source-confirmed:** cottages supply villagers. S1 reports one resident for Small Cottage and two for Large Cottage, with housing caps by level and upgrades retaining the existing resident. It lists Small Cottage tax as 5 coins/4 hours and Large Cottage as 8 coins/9 hours. [S1, Building/Upgrading Cottages][s1]

**Corroboration:** housing controls labour supply, and upgraded houses add workers in the version-2.2.0 guide. [S3, Home is where the heart is][s3] Recovered Vanilla Small Cottage ID 12 independently describes one villager; variant 10012 must be inspected separately.

**Unresolved:** full house-cap table, variant capacities, upgrade prerequisites/taxes by release, and preservation of residents through each original upgrade. Our currently implemented two arrivals per playable cottage are reconstruction behavior; do not silently “correct” existing towns during research.

## Levels and unlocks

**Source-confirmed:** S1 describes an early 20-level state and fleece access at level 10. [S1, Currency / Resource Buildings][s1] The e38 author reports being level 30 in the January 2011 note. [S4][s4] The recovered 4.0.1 settings contain entries through 70. These are different snapshots, not a single interchangeable level table.

**Recovered numeric evidence:** see `Settings.xml` above. Read active `MaxBuilding` limits and exact object prerequisites alongside the curve. Level text contains both active and commented wording; comments are not active unlock rules.

**Unresolved:** dates of cap increases, full land-specific unlock/prerequisite graph, server-side overrides, and how bundle 4.0.1 corresponds to each guide. Never invent missing original requirements from a thematic roadmap or interpolate them as fact.

## Buildings and construction

**Source-confirmed:** placement uses a confirmation check, rotation and cancel; logging/resource structures can depend on natural resource sites. [S1, Building Cottages / Resource Buildings][s1] This does not prove genuine four-direction artwork existed for every structure.

**Research procedure:** reconcile stable object IDs, `availableFromStore`, upgrade chains, tutorial/building prerequisites and recovered art references. Confirm costs/footprints against the relevant land and release. Use all 274 imported definitions as an index, not a claim that all are playable. [Current scale audit](BUILDING_VISUAL_AUDIT.csv)

**Unresolved:** original tile-to-pixel scale, mountain/forest depletion and placement behavior, true rear-facing sprites, and complete store inventory by patch. Our reduced footprints and unrestricted clear-ground Quarry are reconstruction choices.

## Production and shops

**Source-confirmed:** workers and haulers have separate roles and can be reassigned. [S1, Hiring Workers][s1] The contemporary Pocket Gamer guide describes bakery orders for visiting players and recommends multiple production buildings. [S3, Make friends / Double or nothing][s3]

**Dated player evidence:** e38's Theater table reports One Act at required level 28, 45 seconds, 5 Gold and 15 XP; Fiddler on the Woof at 29, 5 minutes, 15 Gold and 50 XP; Twelfth Evening at 30, 15 minutes, 25 Gold and 90 XP. These are reported **production-item** requirements, not proof of the Theater building's unlock level. Later rows are incomplete. [S4, Theater table][s4]

**Unresolved:** corroboration of these timings/rewards against recipe IDs; recipe input/output units, shop ordering rules and patch changes. Do not label absent table values as zero. Current short cycles, direct bakery output and simplified hauling are offline reconstruction decisions.

## Resources and economy

**Source-confirmed:** S1 distinguishes raw logs/rocks from processed lumber/stone and describes fleece→cloth. [S1, Resource Buildings][s1] Pocket Gamer describes daily market-price changes in its version-specific account. [S3, Be a canny trader][s3]

**Translation caution:** e38 abbreviates materials in Japanese and distinguishes Gold from MB (Magic Beans). Its table includes an ambiguous fibre heading; do not infer a new cotton resource without checking `Resources.xml`. Spelling errors in item names should be recorded and mapped to stable IDs rather than propagated as new items. [S4][s4]

**Unresolved:** exact rates, carrying/storage limits, hunger units, market algorithms and balances across versions. Current fixed prices, +10 storage per later level and Gold/Rock paving costs are reconstruction balance, not recovered original rules.

## Graphics and visual references

**Primary provenance:** Burns identifies her contributions as isometric buildings, characters, icons and backgrounds; the portfolio describes castle upgrades, environmental work, ambient animation and winter art. [S6][s6]

The user's four-panel original-game composite is the primary visual target for proportions, architecture/colors, grass, dirt edges/intersections, farms, trees and decoration density. It currently exists as a conversation attachment, not a committed repository asset; do not assume future sessions can access its temporary Windows path. Seek an appropriately licensed/authorized durable visual reference before claiming it has been archived.

Compare warm thatch/tile roofs, timber/stone detailing, readable isometric footprints and subordinate decorations. These are visual observations/art direction, not numeric mechanics. The new procedural meadow/path meshes and contact shadows are reconstruction artwork. A portfolio reference does not grant permission to copy its artwork; retain provenance and rights notes for any future imported assets.

## Historical updates and version conflicts

| Snapshot | Evidence | Interpretation limits |
|---|---|---|
| 25 Nov 2010, version 2.2.0 | S3's explicit date/version | Applies to that guide's scope, not every later economy. |
| Early guide with 20 levels | S1 body | Exact original publication/version remains unresolved; modern page furniture is not release evidence. |
| 15 Jan 2011 player note | S4 article body; author reports level 30 | Evidence of the player's reported level, not the exact cap or patch date. Category advertising/calendar dates are unrelated. |
| Recovered bundle 4.0.1 | Local plist allowlisted version field and Settings XML | Settings declare max level 70; exact release date and live-server behavior not verified. |
| 16 Jan 2013 portfolio | S6 publication metadata | Art-project publication date, not a game patch date or a complete content chronology. |

S2 and S5 remain unresolved source leads. Their access failures do not establish that the pages were permanently deleted or that all mirrors are unavailable.

## Reconstruction decisions and implementation history: do not cite as original mechanics

- The initial prototype used cottage/camp bootstrap, Farm/Bakery at 1 and Quarry/Rock at 2 with an estimated decorative schedule. Phase 2 restores verified requirements for registered original IDs, including Bakery 2 and Quarry 4, while grandfathering older earned access. Bootstrap aliases remain exceptions.
- The first recreation curve used 100 at level 1; this was a prototype choice. Phase 2 now uses the recovered 4.0.1 value 550 and its other XP thresholds through the project cap of 50, preserving saved levels/XP. The original bundle cap is 70, not 50. See [Phase 2](PHASE_2_RESTORATION.md).
- The prototype +10 storage-per-level bonus is now grandfathered per legacy save rather than advertised as a new historical reward. Fixed local sale prices, compact dimensions and accelerated construction/early production remain reconstruction choices.
- The two-resident synthetic starter is a compatibility exception. Phase 2 implements original-ID default capacities of 1/2/3/4, cottage limits and in-place upgrades; adoption remains unimplemented. Simplified hauling, reduced footprints and fallback mirrored views remain reconstruction choices.
- Connected procedural dirt/cobble/slab paths and their prices; decorative roads do not impose movement requirements.
- Fully offline play, no catch-up production, no accounts or paid services, modern touch UI and version-5 save migration.

The initial documentation task made no gameplay changes. Phase 2 applies the separately tested restoration described below; remaining deviations stay explicit. Future historical corrections must preserve working towns, existing earned unlocks, production and save compatibility.

## Maintaining this library

For each new finding, record: topic; exact claim; source URL or repository file and stable ID; article date/game version; section or revision/permalink; access date; evidence label; conflicting evidence; and implications for our implementation. Prefer short original summaries and relevant metadata over copying full articles or artwork. For unavailable sources record the failed attempt and a follow-up question; do not fill gaps with guesses.

Priority questions: reconcile the recovered XP/cap data and complete unlock graph; recover house capacities/caps for each land; validate shop recipes and wool/cloth chains; identify directional graphics and original path materials; establish dated patch history. Consult this document before implementation and update it when a question is resolved.

[s1]: https://www.gamezebo.com/walkthroughs/trade-nations-walkthrough/
[s2]: https://shadowcraze.blogspot.com/2011/05/ipad-trade-nations-review-guide-part-1.html
[s3]: https://www.pocketgamer.com/trade-nations/beginners-guide-to-trade-nations-for-iphone-and-ipad/
[s4]: https://e38.blog.shinobi.jp/trade%20nations/
[s5]: https://tradenations.fandom.com/wiki/Trade_Nations_Wiki
[s6]: https://www.behance.net/gallery/1827721/Trade-Nations

## Phase 2 recovered findings and implementation cross-reference

[ORIGINAL_BUILDING_CATALOG.md](ORIGINAL_BUILDING_CATALOG.md) records all 274 definitions and distinguishes 271 originals from three compatibility IDs. Active bundle fields confirm Large Cottage 37 at level 4/Tower with two default residents and 6-hour tax (not the earlier guide’s 9-hour interval); Brown House 142 at 8/Keep with three; Stone House 14 at 14/Fort with four. Citadel 221 requires level 30 and Castle 5. Castle/Theater/Jeweler remain researched, not playable claims.

Pen/Lumber Yard/Stone Cutter/Loom inputs and per-worker rates, Stockpile capacities, original shop jobs, all 0–70 XP rows and house/shop allowances are available in the catalog and runtime evidence JSON. Source confidence is high for these literal 4.0.1 XML values; original server behavior remains unresolved. [PHASE_2_RESTORATION.md](PHASE_2_RESTORATION.md) distinguishes each implemented historical value from its offline/compatibility adapter and records tests. The old CLASSIC_PHASE.md is an implementation-history snapshot, not current historical truth.
