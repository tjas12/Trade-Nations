# Automated iPhone Web testing

Source: `codex/offline-restoration-audit`. Production target: `https://tjas12.github.io/Trade-Nations/`.

**Verified live on 2026-10-25:** [Play Trade Nations](https://tjas12.github.io/Trade-Nations/). The [first deployment run](https://github.com/tjas12/Trade-Nations/actions/runs/40210170164) passed both build and deployment jobs, publishing source commit `3144961ccf81eba7e233ff14e7b5ff0b5ef6cd8e` from annotated tag `phone-test-2026-10-25-1`. Public HTML, build metadata, WASM (`application/wasm`), and PCK returned HTTP 200. A separate desktop Chromium test against the actual HTTPS site passed startup, real IndexedDB autosave, first-install caching, and offline browser reopening with the existing town. It reported no fatal script/resource errors. No physical iPhone or Safari test has occurred.

[Pull request #1](https://github.com/tjas12/Trade-Nations/pull/1) is ready for review. It has not been merged; `main` remains unchanged. The first tagged test is already live, so merging is not required merely to try it. Review/merge establishes the normal automatic update process below.

Workflow: [iPhone Web build and Pages](https://github.com/tjas12/Trade-Nations/actions/workflows/iphone-web.yml), implemented in `.github/workflows/iphone-web.yml`.

## Normal update process

1. Develop on a feature branch and push it. The workflow builds and tests; it **does not deploy** ordinary development branches or pull requests.
2. Review the pull request and merge approved work to `main`.
3. The `main` push automatically imports/tests the game, exports the release Web/PWA build, performs browser storage/offline checks, uploads artifacts, and deploys through the official Pages actions.
4. Wait for the deployment job to succeed. Close all old game tabs/Home Screen windows and reopen the game online. When **Offline: ready** appears, offline installation is complete. Existing IndexedDB saves are retained; no save-clearing step is performed.

Do not switch the Pages source to a branch or upload generated exports into the source branch. The Pages source must remain **GitHub Actions**.

## Authorized first test / manual deployment

For this task, the user authorized preparing and deploying the first iPhone test without overwriting `main`. A maintainer can intentionally create a fresh annotated `phone-test-*` tag at a reviewed development commit and push that tag. It runs the same checks before deploying. This explicit tag action is the manual-deployment exception; normal branch pushes never publish. Never move or force-push an existing tag.

The Pages environment permits `main` and `phone-test-*` tags only. This retains the main-only policy for normal development. Once the workflow is merged to the default branch, **Actions → iPhone Web build and Pages → Run workflow** also supports an explicit deploy checkbox; select `main` or an approved phone-test tag. Leaving the checkbox off builds only.

## Repository settings

The repository is public and Actions is enabled. Pages was configured using its API with `build_type: workflow` and HTTPS enforcement. The environment retains its `main` branch policy and adds only the explicit `phone-test-*` tag policy. No default branch was overwritten or force-pushed.

If account configuration later blocks deployment:

- [Settings → Pages](https://github.com/tjas12/Trade-Nations/settings/pages): **Build and deployment → Source → GitHub Actions**.
- [Settings → Actions → General](https://github.com/tjas12/Trade-Nations/settings/actions): allow GitHub Actions and the official `actions/*` actions used by this workflow.
- [Settings → Environments](https://github.com/tjas12/Trade-Nations/settings/environments): `github-pages` must permit branch `main`; explicit first-test deployment additionally needs tag pattern `phone-test-*`. Approve a pending environment review if one is configured. Do not remove protection rules to bypass required human review.
- `pages: write` and `id-token: write` are restricted to the deployment job. Build/test jobs have only `contents: read`. Deployments share one concurrency group and cannot overlap.

## Build verification

The Linux runner downloads official **Godot 4.7.2** and its matching export-template archive from `godotengine/godot-builds`. SHA256 values are pinned in `tools/install_godot_web.py` from the official release API; both complete downloads are verified before extraction. Only the single-threaded Web templates are installed. GitHub actions are pinned to verified commit SHAs.

`tools/validate_godot.py` imports the project, runs foundation, restoration, real mouse input, playable economy, scale, layout, and touch tests with isolated save profiles, then checks startup and graphical Compatibility scenes under Xvfb. The runner uses Dummy audio because hosted runners have no sound device; audible output is not verified by CI. Existing root-certificate/shutdown diagnostics remain explicitly filtered, while script errors and failed assertions fail the build.

`tools/export_web.py` runs the existing **Web - iPhone landscape** preset in release mode. It validates HTML/JS/WASM/PCK, manifest, icons, and worker resources; reads the real PCK directory to exclude source archives, research, tests, and tools; and checks required runtime JSON. It precaches the complete playable bundle, including WASM/PCK, during service-worker installation. The default worker's update lifecycle remains intact: only game caches are replaced, never IndexedDB saves. All asset URLs are relative so `/Trade-Nations/` works without a custom domain.

`tools/test_web_browser.py` uses a disposable persistent Chromium profile and a touch viewport. It checks exported-game startup, fatal console/resource failures, a real autosave stored in IndexedDB, required CacheStorage entries after initial installation, and a fresh browser launch with networking disabled that loads the previous town. It can also run against the deployed HTTPS URL using `--url`. This is desktop Chromium automation, **not an iPhone or Safari test**.

New service-worker installations request fresh resources instead of filling their new versioned cache from potentially stale browser HTTP-cache entries. This supports future updates without asking players to clear website data. The worker still waits for old clients to close before activating; saved town data remains in IndexedDB.

Build artifacts are named `iphone-web-<commit>` and retained for 14 days. Diagnostics include logs and landscape/offline screenshots. Exported binaries stay in ignored `export/web`, never in the source branch. `build-info.json` records the deployed source commit, file sizes, and SHA256 digests.

## Phone installation

Open the confirmed live address in Safari, disable portrait lock, and rotate to landscape. Let the game finish loading and wait for **Offline: ready**. Choose **Share → Add to Home Screen**, open the icon once online, then test in airplane mode. Use that same installation/address for subsequent play. A first tap may be needed to enable sound.

Safari may evict caches or website data; private browsing is unsuitable for persistent play. Native iOS remains the eventual route for app-local storage. If the game reports unavailable browser storage, it blocks saves and explains the temporary session instead of overwriting an existing town. A persistence flag alone cannot prove permanent retention; the automated test also verifies actual IndexedDB contents and reload behavior. Do not clear website data to update the game.

Physical iPhone testing still must verify Dynamic Island/Home indicator clearance in both landscape directions, Safari/PWA gesture behavior, actual sound, comfortable target sizes, sustained frame time/memory/temperature, interruptions, and long-term save persistence. Use the full checklist in [MOBILE_TESTING.md](MOBILE_TESTING.md).

Official references: [Godot Web export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html), [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
