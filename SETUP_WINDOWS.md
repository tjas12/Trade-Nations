# Run on Windows

## Existing local checkout and engine

The project is already cloned here:

`C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\Faithful_reboot`

The portable official Godot 4.7.2 executable is already here:

`C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\.tools\godot\Godot_v4.7.2-stable_win64.exe`

No installer, Python, Godot .NET edition, backend, login or export templates are
needed to play in the editor. The console executable beside it is used for tests.
Keep the whole checkout together, including original/ for the current sound mapping.
For another computer use official Godot 4.7.x Windows standard builds from
https://godotengine.org/download/windows/ ; do not migrate the project unnecessarily.

## Open and play

1. Double-click the portable Godot executable above.
2. In Project Manager select Import and choose the checkout's `project.godot`.
3. Open the project and allow the first asset import to finish.
4. Press F5 (Godot editor Run Project). Main.tscn is already configured.
5. In the running game dismiss the tutorial, use Build -> HOUSE -> Small Cottage,
   move the preview to open space, and left-click to confirm. Right-click or Esc
   cancels; R rotates (rotation geometry is still a known limitation).
6. Click the existing camp to assign a worker and a hauler. Two villagers exist
   initially. Gather/transport is slow and simplified; see FEATURE_MATRIX.md.
7. In the game use Save or F5 to save slot 1, Load or F9 to reload it. The next
   project launch automatically tries slot 1. Save before closing: no autosave.

F5 in the editor starts the project; F5 while the game window is focused saves.
This is a prototype. Crafting, real citizen logistics, working initial level-ups,
isometric terrain and a complete expansion economy are not yet implemented.

For the same renderer used in graphical validation, paste into PowerShell:

```powershell
Set-Location 'C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\Faithful_reboot'
& '..\.tools\godot\Godot_v4.7.2-stable_win64.exe' --path . --rendering-method gl_compatibility
```

The project still declares Forward Plus. Compatibility was tested explicitly;
Forward Plus was not graphically verified in this pass. If the editor renderer
fails, use the command above rather than changing Godot versions.

## Saves and recovery

Normal saves are in:

`%APPDATA%\Godot\app_userdata\Trade Nations Reboot\saves\`

Primary: `slot_1.tres`. Previous valid generation: `slot_1.backup.tres` (created
on the second successful save). A pending TRES is written/validated first, then
promoted. The loader tries primary, then backup. Recovery loses progress since
the backup generation. If both are invalid, the game starts a temporary fresh town
and blocks in-game saving to avoid overwriting the damaged files. Copy all save
files elsewhere, then move the damaged slot files aside before starting a new town.
Do not edit or import untrusted TRES files. Older upstream prototype saves need
an explicit ID migration; this pass reserves 10001/10012/10008 for prototype
Town Hall/Cottage/Camp rather than colliding with original IDs 1/101/201.

## Repeat validation without touching player saves

```powershell
Set-Location 'C:\Users\tjas1\OneDrive\Documents\ChatGPT\Trade Nations\Faithful_reboot'
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate_windows.ps1 -Godot '..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
```

This sets process-local AppData directories inside ignored `.validation/`, runs
an editor import, 60 existing checks, 27 restoration checks, and a bounded headless
Main launch. Exit code and script-error logs are checked. Logs remain there.
For optional graphical verification add `-Graphical`; it runs the integration
scene through Compatibility and writes a screenshot to its isolated user data.
These tests exercise scene methods; they do not replace a manual gameplay session.

The restricted agent environment can emit a root-certificate-store error; the
validation script allows that specific engine diagnostic. The script also reports known resource-in-use shutdown diagnostics separately. All other ERROR or SCRIPT ERROR lines fail validation. A backup-recovery warning is expected.

No standalone EXE export was built. Export templates/presets are only needed for
a future packaged build. Review ASSET_LICENSE_AUDIT.md before sharing any export.
iOS work is deferred until the Windows gameplay loop is complete.

For the newest controls (pan/zoom, production speed, collection, local market and staff release), see [PLAYABILITY_UPDATE.md](PLAYABILITY_UPDATE.md).
