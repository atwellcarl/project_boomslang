#!/usr/bin/env bash
# Build the web (PWA) version into build/web, ready for GitHub Pages.
# .github/workflows/pages.yml runs this on every push to main and publishes the result.
#
#   tool/build_web.sh                                  # served at atwellcarl.github.io/project_boomslang/
#   BASE_HREF=/ CNAME=lrm.example.com tool/build_web.sh  # own domain, served at the root
set -euo pipefail

BASE_HREF="${BASE_HREF:-/project_boomslang/}"
FLUTTER="${FLUTTER:-$(command -v flutter || echo "$HOME/development/flutter/bin/flutter")}"

cd "$(dirname "$0")/.."

# --no-web-resources-cdn bundles the rendering engine instead of loading it from Google's CDN,
# so the app works offline at the range.
"$FLUTTER" build web --release --base-href "$BASE_HREF" --no-web-resources-cdn --no-source-maps

# Pages runs Jekyll by default, which drops files starting with "_" or ".".
touch build/web/.nojekyll
# Single-page app: serve the app for unknown paths instead of a 404 page.
cp build/web/index.html build/web/404.html
if [[ -n "${CNAME:-}" ]]; then echo "$CNAME" > build/web/CNAME; fi

# Stamp sw.js with this build's files and a content hash, so phones precache everything
# (including the hit/miss sounds) and pick up each new deploy.
python3 - build/web <<'EOF'
import hashlib, json, os, sys
root = sys.argv[1]
skip = {"sw.js", "404.html", "CNAME", ".nojekyll", ".last_build_id", "flutter_service_worker.js"}
# Precache only what Safari's JS build loads: canvaskit/canvaskit.*. The other engine
# variants (Chrome, Wasm) are ~25 MB more; sw.js still caches them on first use.
def precache(rel):
    if rel.startswith("canvaskit/"):
        return rel in ("canvaskit/canvaskit.js", "canvaskit/canvaskit.wasm")
    return not rel.endswith((".map", ".symbols"))
files, h = [], hashlib.sha256()
for d, _, names in sorted(os.walk(root)):
    for n in sorted(names):
        rel = os.path.relpath(os.path.join(d, n), root)
        if n in skip:
            continue
        h.update(rel.encode()); h.update(open(os.path.join(root, rel), "rb").read())
        if precache(rel):
            files.append(rel)
sw = os.path.join(root, "sw.js")
s = open(sw).read()
s = s.replace('const VERSION = "dev";', f'const VERSION = "{h.hexdigest()[:12]}";', 1)
s = s.replace("const FILES = [];", f"const FILES = {json.dumps(files)};", 1)
open(sw, "w").write(s)
print(f"sw.js: {len(files)} files, version {h.hexdigest()[:12]}")
EOF

echo "Built build/web with base href $BASE_HREF."
