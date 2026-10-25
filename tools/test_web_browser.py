"""Desktop Chromium smoke test, including real IndexedDB and offline reopening.

This is not Safari or physical iPhone validation. Use a disposable browser profile.
"""
import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import tempfile
import threading
from urllib.parse import unquote, urlsplit

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]


class BuildHandler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        route = unquote(urlsplit(path).path)
        if not route.startswith("/Trade-Nations/"):
            return str(Path(self.directory) / "missing-route")
        relative = route.removeprefix("/Trade-Nations/")
        target = (Path(self.directory) / relative).resolve()
        if not target.is_relative_to(Path(self.directory).resolve()):
            return str(Path(self.directory) / "missing-route")
        return str(target)

    def log_message(self, *_args):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", type=Path, default=ROOT / "export/web")
    parser.add_argument("--url", help="Validate a deployed HTTPS build instead of the local build")
    args = parser.parse_args()
    diagnostics = ROOT / ".validation"
    diagnostics.mkdir(exist_ok=True)
    server = None
    if args.url:
        url = args.url
    else:
        server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(BuildHandler, directory=str(args.build.resolve())))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = f"http://127.0.0.1:{server.server_port}/Trade-Nations/"
    messages, failures = [], []
    try:
        with tempfile.TemporaryDirectory(prefix="trade-nations-browser-") as profile, sync_playwright() as runtime:
            def launch(offline=False):
                context = runtime.chromium.launch_persistent_context(profile, headless=True, viewport={"width": 960, "height": 440}, has_touch=True, is_mobile=True, device_scale_factor=1, service_workers="allow", args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--disable-dev-shm-usage"])
                context.set_offline(offline)
                page = context.pages[0] if context.pages else context.new_page()
                page.on("console", lambda message: messages.append(message.text))
                page.on("pageerror", lambda error: failures.append(str(error)))
                page.on("requestfailed", lambda request: failures.append(f"Request failed: {request.url}: {request.failure}"))
                page.on("response", lambda response: failures.append(f"HTTP {response.status}: {response.url}") if response.status >= 400 else None)
                page.on("console", lambda message: failures.append(f"{message.text} {message.location}") if message.type == "error" and ("SCRIPT ERROR" in message.text or "ERROR:" in message.text or "failed" in message.text.lower()) else None)
                return context, page

            def ready(page, start):
                page.wait_for_function("document.querySelector('canvas')?.width > 0", timeout=120000)
                for _ in range(1200):
                    if any("[Main] Scene ready" in message for message in messages[start:]):
                        return
                    page.wait_for_timeout(100)
                raise RuntimeError("Godot did not reach the playable main scene")

            context, page = launch()
            page.goto(url, wait_until="domcontentloaded", timeout=120000)
            ready(page, 0)
            page.wait_for_function("async()=>Boolean((await navigator.serviceWorker.getRegistration())?.active)", timeout=60000)
            # A real browser save must reach IndexedDB, not only the WASM virtual FS.
            storage_script = """async () => {
              const databases = await indexedDB.databases();
              for (const entry of databases) {
                if (!entry.name.includes('userfs')) continue;
                const db = await new Promise((ok, fail) => {const r=indexedDB.open(entry.name); r.onsuccess=()=>ok(r.result); r.onerror=()=>fail(r.error);});
                try {
                  if (!db.objectStoreNames.contains('FILE_DATA')) continue;
                  const keys = await new Promise((ok, fail)=>{const r=db.transaction('FILE_DATA').objectStore('FILE_DATA').getAllKeys();r.onsuccess=()=>ok(r.result);r.onerror=()=>fail(r.error);});
                  if(keys.some(key=>String(key).endsWith('/saves/slot_1.tres'))) return true;
                } finally {db.close();}
              }
              return false;
            }"""
            saved = False
            for _ in range(100):
                saved = page.evaluate(storage_script)
                if saved:
                    break
                page.wait_for_timeout(200)
            if not saved:
                raise RuntimeError("Town autosave did not reach browser IndexedDB")
            print("PASS: browser startup and actual IndexedDB save", flush=True)
            # Installation itself must cache heavy resources, before a second visit.
            cache = page.evaluate("async()=>{let result=[];for(const name of await caches.keys()){for(const request of await(await caches.open(name)).keys())result.push(request.url)}return result}")
            for suffix in ["index.html", "index.js", "index.wasm", "index.pck", "index.png", "index.manifest.json"]:
                if not any(urlsplit(item).path.endswith("/" + suffix) for item in cache):
                    raise RuntimeError(f"Required game file was not cached: {suffix}")
            page.screenshot(path=str(diagnostics / "web-landscape.png"))
            context.close()
            # Reopen the persisted profile with networking disabled before navigation.
            start = len(messages)
            context, page = launch(offline=True)
            page.goto(url, wait_until="domcontentloaded", timeout=120000)
            ready(page, start)
            if not any("[SaveManager] Loaded slot 1" in message for message in messages[start:]):
                raise RuntimeError("Offline relaunch did not load the previous town")
            page.screenshot(path=str(diagnostics / "web-offline.png"))
            context.close()
            if failures:
                raise RuntimeError("Browser failures:\n" + "\n".join(failures))
            print("PASS: service-worker cache, offline browser relaunch and existing-town recovery", flush=True)
            print("Desktop Chromium touch viewport only; no physical iPhone/Safari test.", flush=True)
    finally:
        (diagnostics / "web-browser.log").write_text(json.dumps({"url": url, "messages": messages, "failures": failures}, indent=2), encoding="utf-8")
        if server:
            server.shutdown()


if __name__ == "__main__":
    main()
