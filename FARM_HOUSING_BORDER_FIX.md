# Farm, cottage population, and surrounding landscape — 2026-10-24

- Farm definition 11 now uses 2×2 tiles, matching the playable Small Cottage (10012). This is the requested prototype size override, not a claim about the original XML footprint. Existing farms use the new size on load.
- The prototype Town Hall provides quarters for the two starting citizens. Each completed Small Cottage adds two more citizens. Housing is reconciled when a save loads and when a cottage is placed: missing citizens arrive, existing citizens and jobs remain, and repeating the process does not duplicate residents. Immediate arrival remains a prototype substitute for original arrival timers.
- The HUD shows total and idle citizens; housing popups show residents. Assigned citizens walk from their assigned residence.
- Deterministic trees, flowers, and stumps now surround the playable land, with a margin to keep canopies outside the plot. The interior stays clear. Scenery is cosmetic and does not occupy cells, consume resources, or create saved buildings. Existing pan and zoom controls remain available.

Validation: Windows Godot 4.7.2 import, foundation, restoration, real-input interaction, headless startup, Compatibility rendering, and Forward Plus interaction checks. Regression coverage includes cottage arrivals, legacy-save population repair with preserved staff, repeated save/load without duplication, HUD updates, Farm footprint, and exterior-only scenery. Existing resource/ObjectDB shutdown diagnostics remain in retained validation logs.
