"""Reproducible, read-only audit of 274 imported definitions and original XML.

Only writes documentation and the explicit runtime evidence table. Does not
rewrite extracted originals or .tres definitions. XML comments are ignored.
"""
from pathlib import Path
import argparse
import collections
import json
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "original/TradeNations.app/bundle"
IMPLEMENT = [12, 37, 142, 14, 15, 17, 23, 36, 32, 38, 25, 26, 2, 3, 4]


def tree(path):
    # Items.xml consists of adjacent roots, not one well-formed document.
    text = re.sub(r"<\?xml[^>]*\?>", "", path.read_text(encoding="utf-8-sig"))
    return ET.fromstring("<Document>" + text + "</Document>")


def resources(node):
    if node is None:
        return {}
    result = {n.get("id"): float(n.text) for n in node.findall("Resource") if (n.text or "").strip()}
    if node.find("MagicBeans") is not None:
        result["MagicBeans"] = float(node.findtext("MagicBeans"))
    return result


def run(implemented=False):
    files = ["Vanilla_BuildingsTo10.xml"] + [n.get("name") for n in tree(BUNDLE / "Objects.xml").iter("File")]
    records = {}
    duplicates = []
    for filename in dict.fromkeys(files):
        for obj in tree(BUNDLE / filename).iter("Object"):
            id = int(obj.get("id"))
            if id in records:
                duplicates.append(id)
            prerequisites = [{"type": p.get("type"), "value": (p.text or "").strip()} for p in obj.findall("Prerequisite")]
            villagers, tax, produce = obj.find("Villagers"), obj.find("Tax"), obj.find("Produce")
            workers = obj.find("Workers")
            flags = []
            if filename == "Halloween.xml": flags.append("Halloween pack; event context")
            if filename == "Frontier_Launch.xml": flags.append("Frontier variant")
            if filename.startswith("Crossover"): flags.append("cross-land pack, not necessarily event-only")
            if obj.get("availableFromStore") == "0": flags.append("not a normal store purchase; eligibility unresolved")
            records[id] = {
                "id": id, "name": obj.get("name"), "source": filename,
                "type": obj.get("type"), "category": obj.get("category", ""),
                "level": max([int(p["value"]) for p in prerequisites if p["type"] == "level"] or [0]),
                "prerequisites": prerequisites, "cost": resources(obj.find("Cost")),
                "build_seconds": float(obj.findtext("BuildTime", "0")),
                "footprint": [int(obj.get("width", "1")), int(obj.get("height", "1"))],
                "workers": dict(workers.attrib) if workers is not None else {},
                "residents": int(villagers.get("default", "0")) if villagers is not None else 0,
                "adoptable": int(villagers.get("purchasable", "0")) if villagers is not None else 0,
                "tax": {"seconds": float(tax.get("interval")), "reward": resources(tax.find("Resources")), "xp": float(tax.find("Resources").get("xp", "0"))} if tax is not None else {},
                "storage": {n.get("id"): (-1 if n.get("qty") == "unlimited" else float(n.get("qty"))) for n in obj.findall("Resources/Resource")},
                "produce": ET.tostring(produce, encoding="unicode").strip() if produce is not None else "",
                "items": [int(i.text) for i in obj.findall("Item")],
                "upgrades_from": [int(i.text) for i in obj.findall("UpgradeOf")],
                "upgrade_only": any(i.get("upgradeOnly") == "true" for i in obj.findall("UpgradeOf")),
                "store": obj.get("availableFromStore", "unknown"),
                "finish_time_unix": obj.findtext("FinishTime", "not supplied"),
                "lands": [i.text for i in obj.findall("CompatibleLand")],
                "idle_art": obj.find("IdleAnim").get("name", "") if obj.find("IdleAnim") is not None else "",
                "flags": flags,
            }
            if produce is not None:
                record = records[id]
                record["production"] = {"input": {p.get("resource_id"): float(p.get("amount")) for p in produce.findall("Input")}, "output": int(produce.find("Output").get("resource_id")), "stack": float(produce.find("Output").get("maxOutputStackSize", "150")), "per_worker_hour": float(produce.find("Rate").get("villagerResourcesPerHour", "0"))}
    imported = {}
    for path in sorted((ROOT / "data/buildings").glob("*.tres")):
        text = path.read_text(encoding="utf-8-sig")
        id = int(re.search(r"^id = (\d+)$", text, re.M)[1])
        imported[id] = path
    assert len(imported) == 274 and len(records) == 271 and not duplicates
    original_items = {int(i.get("id")): i for i in tree(BUNDLE / "Items.xml").iter("Item") if i.get("type") == "shopItem"}
    recipes = {}
    for id, item in original_items.items():
        recipes[str(id)] = {"name": item.get("name"), "seconds": float(item.get("time")), "inputs": resources(item.find("Cost")), "rewards": resources(item.find("Reward")), "xp": float(item.find("Reward").get("xp", "0")), "level": max([int(p.text) for p in item.findall("Prerequisite") if p.get("type") == "level"] or [0]), "prerequisites": [{"type": p.get("type"), "value": p.text} for p in item.findall("Prerequisite")]}
    settings = tree(BUNDLE / "Settings.xml")
    levels = {}
    for xp in settings.iter("XP"):
        levels[str(xp.get("level"))] = {"xp_to_next": int(xp.get("toNext")), "limits": {p.get("category"): int(p.text) for p in xp.findall("MaxBuilding")}, "text": xp.findtext("LevelText", "")}
    runtime = {"version": "4.0.1", "evidence": "Recovered XML, active nodes only; full details in docs/ORIGINAL_BUILDING_CATALOG.md", "aliases": {"10001": 1, "10008": 8, "10012": 12}, "object_requirements": {str(id): {k: r[k] for k in ["level", "prerequisites", "source", "upgrades_from", "store"]} for id, r in records.items()}, "offline_prices": {"11": 8, "21": 12, "50": 5, "51": 14}, "profiles": {str(id): records[id] for id in IMPLEMENT}, "levels": levels, "shop_recipes": recipes}
    (ROOT / "data/historical_gameplay.json").write_text(json.dumps(runtime, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    old = json.loads((ROOT / "data/first_playable.json").read_text())
    names = collections.Counter(r["name"] for r in records.values())
    lines = ["# Original building catalog", "", "Generated by `tools/build_historical_catalog.py` from recovered bundle 4.0.1. All 274 imported definitions audited: 271 unique original objects and three synthetic compatibility definitions (10001, 10008, 10012). No duplicate original IDs found after manifest-file de-duplication. Same-name entries and land/color variants are not interchangeable IDs.", "", "Evidence confidence: **high for literal recovered fields**, not a claim that every object was available in the live store. Missing fields are unknown/not supplied, not invented. `availableFromStore=0`, tutorial gates, upgrades, seasonal packs and server eligibility must be considered together. Unmapped art does not prove an object is unfinished in the original game.", "", "Historical values below are unmodified: runtime uses compact footprints, accelerated construction and grandfathered early-game adapters. IDs 2/3/4 are civic upgrades; 12/37/142/14 are residential progression; 15/17/23/36 are processing/Pen; 32/38 are commercial adapters. Castle 5 → Citadel 221 (level 30) remains researched/planned until suitable complete art and implementation exist. Theater 167 is level 26 in this bundle, unlike the January 2011 level-28 recipe note; it is not currently playable. Jeweler 237 is level 41 and remains planned. These are version conflicts, not reasons to invent a combined table.", "", "## Primary source map", "", "Original [Objects manifest](../original/TradeNations.app/bundle/Objects.xml), [Settings](../original/TradeNations.app/bundle/Settings.xml), [Items](../original/TradeNations.app/bundle/Items.xml), [Resources](../original/TradeNations.app/bundle/Resources.xml). See [permanent references](ORIGINAL_GAME_REFERENCES.md) for version-scoped external evidence. Active `UpgradeOf` lists are retained in full; the older importer sometimes retained only their first entry.", "", "## Complete definitions", ""]
    def fmt(value):
        return json.dumps(value, ensure_ascii=False).replace("|", " / ").replace("\n", " ") if value else "Not supplied / not applicable"
    for id, path in sorted(imported.items()):
        r = records.get(id)
        if not r:
            lines += [f"### {id} — compatibility definition", "", f"Synthetic prototype ID; not an original bundle ID. Runtime definition: [{path.name}](../data/buildings/{path.name}). Mapped historical counterpart: {runtime['aliases'][str(id)]}. Preserve existing saves; do not renumber.", ""]
            continue
        status = "Implemented adapter" if implemented and id in IMPLEMENT else ("Existing playable reconstruction" if str(id) in old["buildings"] else "Research/planned; not advertised playable")
        text = path.read_text(encoding="utf-8-sig")
        art_match = re.search(r'^icon_path = "([^"]*)"', text, re.M)
        art = art_match[1] if art_match else json.loads((ROOT / "data/building_visuals.json").read_text())["asset_overrides"].get(str(id), "Unmapped")
        flags = r["flags"] + (["same-name variant; inspect ID/land"] if names[r["name"]] > 1 else [])
        fields = {"Source / confidence": f"[{r['source']}](../original/TradeNations.app/bundle/{r['source']}); high, literal XML", "Category / type / land": [r['category'], r['type'], r['lands']], "Historical minimum level / prerequisites": [r['level'], r['prerequisites']], "Construction cost (resource IDs; MagicBeans separately)": r['cost'], "Construction seconds / footprint": [r['build_seconds'], r['footprint']], "Workers / haulers": r['workers'], "Population default / adoptable": [r['residents'], r['adoptable']], "Tax interval, rewards and XP": r['tax'], "Storage capacities": r['storage'], "Gather / processing": r.get('production', {}), "Shop recipes (Items.xml)": {str(i): recipes.get(str(i), 'not a shop recipe') for i in r['items']}, "Art metadata / current mapping": [r['idle_art'], art], "Upgrade parents / upgrade-only / store flag": [r['upgrades_from'], r['upgrade_only'], r['store']], "Version/event/duplicate notes": flags, "Event finish timestamp (UTC epoch; missing is not proof permanent)": r["finish_time_unix"], "Current implementation": status}
        lines += [f"### {id} — {r['name']}", "", "| Field | Historical evidence / implementation |", "|---|---|"]
        lines += [f"| {k} | {fmt(v)} |" for k,v in fields.items()]
        lines.append("")
    lines += ["## Research gaps and safety", "", "Source rates are per worker per hour, not per-frame yields. Recipe prerequisites and currency units require explicit checks. The original MaxBuilding house/shop limits and 0–70 XP rows are preserved in the runtime evidence table; the playable cap remains 50. Historical land upgrades in Items.xml are not the same dimensions/prices as our existing compact-plot expansion. Adoption, expiry/event eligibility, buffs, original server orders and unconverted animation frames remain unresolved/unimplemented. Do not infer a feature is playable from this catalog. See PHASE_2_RESTORATION.md for tested scope and deviations.", ""]
    (ROOT / "docs/ORIGINAL_BUILDING_CATALOG.md").write_text("\n".join(lines), encoding="utf-8")
    print("PASS: 274 imported definitions, 271 original IDs, all manifest files, active prerequisites/taxes/recipes and versioned evidence cataloged")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--implemented", action="store_true")
    run(parser.parse_args().implemented)
