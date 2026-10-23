#!/usr/bin/env bash
# Build the web (PWA) version and publish it to a public GitHub Pages repo.
#
# The source repo stays private: only the compiled build/web output is pushed.
#
#   tool/deploy_web.sh                 # build + push to PAGES_REPO's gh-pages branch
#   BASE_HREF=/ tool/deploy_web.sh     # for a custom domain served at the root
#   DRY_RUN=1 tool/deploy_web.sh       # build only, don't push
#
# One-time setup: create the public repo (e.g. atwellcarl/lrm-trainer), run this
# once, then in that repo's Settings → Pages pick "Deploy from a branch: gh-pages".
set -euo pipefail

PAGES_REPO="${PAGES_REPO:-git@github.com:atwellcarl/lrm-trainer.git}"
REPO_NAME="$(basename "$PAGES_REPO" .git)"
BASE_HREF="${BASE_HREF:-/$REPO_NAME/}"
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

if [[ -n "${DRY_RUN:-}" ]]; then
  echo "Built build/web with base href $BASE_HREF (dry run, not pushed)."
  exit 0
fi

rev="$(git rev-parse --short HEAD)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R build/web/. "$tmp/"
cd "$tmp"
git init -q -b gh-pages
git add -A
git commit -q -m "Deploy LRM Trainer web build from $rev"
git push -f "$PAGES_REPO" gh-pages
echo "Pushed to $PAGES_REPO (gh-pages), base href $BASE_HREF."
