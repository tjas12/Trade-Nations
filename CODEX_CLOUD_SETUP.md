# Codex Cloud environment — Trade Nations

This file is a setup checklist for the **Codex Cloud UI**. Adding it to GitHub does **not** create or publish a Codex environment.

## Environment

- Name: `Trade Nations – Development`
- GitHub repository: `tjas12/Trade-Nations`
- Branch: `main` (start each task from the latest main)
- Project: Godot **4.7.2** (see `project.godot` and `.github/workflows/iphone-web.yml`)
- Target: iPhone-friendly, offline-capable Web PWA, published using GitHub Pages
- Internet access: use only if required for downloading developer tools; do not add runtime server dependencies.

## Preparation

For most Codex Cloud tasks, **no custom setup script is required** to edit GDScript, assets, docs, and tests. Use the repository's existing GitHub Actions workflow for definitive tests and production export. The workflow installs verified Godot 4.7.2 and web export templates through `tools/install_godot_web.py`.

If Codex Cloud offers environment setup commands and local test execution is needed, install Python 3.12 and the verified Godot engine using the instructions in `.github/workflows/iphone-web.yml` and `tools/install_godot_web.py`. Avoid silently changing the engine version or adding unpinned dependencies. The Python scripts under `tools/` are the reference validation paths:

```bash
python tools/check_resource_paths.py
python tools/validate_godot.py --godot godot
python tools/export_web.py --godot godot
```

Run the Godot commands only when the matching verified engine and export templates are actually installed. The GitHub Actions workflow additionally runs graphical validation and browser PWA/offline checks.

## Persistent developer instructions

Read `AGENTS.md` and `AI_INSTRUCTIONS.md` before making changes. When implementing historic content, consult `docs/ORIGINAL_GAME_REFERENCES.md` and the original data bundle indexed there. Do not guess old-game level requirements.

Protect these product requirements:

1. **Save compatibility**: no local save resets, destructive migrations, or silent changes to existing towns.
2. **Mobile first**: compact HUD, usable touch targets, sensible scales, and iPhone browser layout.
3. **Offline play**: no Supabase or backend requirements for core gameplay.
4. **Historical fidelity**: reproduce the original Trade Nations where verified by evidence; label reconstructions.
5. **Quality gate**: prefer small focused PRs, cite evidence, run available tests, and leave CI green.
6. **Deployment safety**: let the existing workflow deploy from approved refs; never push unreviewed gameplay changes directly to `main`.

## Workflow

1. In Codex Cloud, create an environment associated with this repository.
2. Select `main`; keep existing `AGENTS.md` instructions enabled.
3. Start a task in this environment; request a PR to review the work.
4. Check `iPhone Web build and Pages` GitHub Actions checks on the PR.
5. Merge only when validated. GitHub Pages deploys approved `main` builds.
6. On your iPhone, verify the deployed game and **existing local saved town** before concluding a progression or persistence task.

Existing playable URL: https://tjas12.github.io/Trade-Nations/
