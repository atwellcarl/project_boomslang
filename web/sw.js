// LRM Trainer offline: keep the whole app on the phone so it opens at the range with no signal.
// tool/deploy_web.sh fills in VERSION and FILES at build time. A new deploy changes this file, so the
// browser installs the new version in the background and it takes over on the next launch.
// Without a deploy (FILES empty), it still caches each file the first time it's fetched.
const VERSION = "dev";
const FILES = [];
const CACHE = "lrm-" + VERSION;

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(["./", ...FILES])).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k.startsWith("lrm-") && k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== self.location.origin) return;
  // Every app URL (deep links, the 404 fallback) is the same single page.
  const key = req.mode === "navigate" ? "./" : req;
  e.respondWith(caches.open(CACHE).then(c => c.match(key, { ignoreSearch: true }).then(hit => hit || fetch(req).then(res => {
    if (res.ok) c.put(key, res.clone());
    return res;
  }))));
});
