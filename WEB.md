# LRM Trainer on the web

The same Flutter code builds as a web app you add to the iPhone Home Screen. It opens
full-screen, has its own icon, and works offline once it has been opened once. The iOS
and Android builds are unchanged.

## Hosting

Every push to `main` that touches the app runs `.github/workflows/pages.yml`. It runs
the tests, builds with `tool/build_web.sh`, and publishes to
`https://atwellcarl.github.io/project_boomslang/`. You can also run it by hand from the
Actions tab. Settings → Pages → Source must be **GitHub Actions**, not a branch.

To try a build locally:

```bash
tool/build_web.sh
```

**Own domain later:** set Settings → Pages → Custom domain, then change the
workflow's build step to `BASE_HREF=/ tool/build_web.sh`.

Each deploy changes `sw.js`, so phones download the new version in the background and
switch to it the next time the app is opened.

## Install on iPhone

Open the link in Safari → Share → Add to Home Screen. Open it once with signal so it
can save itself for offline use.

## What changed for the web

| Area | Change |
| --- | --- |
| Offline | `web/sw.js` precaches the app (~12 MB). The build script stamps it with the build's file list. Flutter's own deprecated worker is turned off in `web/flutter_bootstrap.js`, since it unregisters itself and would take `sw.js` with it. |
| Engine | Built with `--no-web-resources-cdn`, so the rendering engine ships with the app instead of loading from Google's CDN. |
| Fonts | Roboto Mono is bundled in `assets/google_fonts/` and runtime fetching is off. |
| Sounds | `lib/services/sound_fx.dart` keeps hit and miss on separate preloaded players. iOS Safari only plays audio right after a tap, and swapping one player's file rebuilt the audio element first. Also lower latency on native. |
| Silent switch | `navigator.audioSession.type = "playback"` so sounds play on silent, like the native app. |
| Pinch-zoom | Page zoom, bounce and the long-press callout are off so gestures belong to the scope. |
| Portrait | Browsers can't lock orientation. A phone held sideways sees a "turn upright" screen. |
| Status bar | Flutter web doesn't apply iOS safe-area insets, so the page stays below the status bar. |
| Mouse | The mil wheel also scrolls with a mouse drag, for desktop browsers. |

## Checked so far

- In a 375×812 browser: all three trainers, wind dial, scroll wheel, reticle drag, zoom
  buttons, milling input, hit/miss banners, and both sounds playing.
- In headless Chrome: the service worker installs and precaches. With the web server
  stopped, the app still loads with fonts.

## Still to check on a real iPhone

- Two-finger pinch-zoom on the range and milling scopes.
- First hit/miss sound after opening, and with the ringer on silent.
- Add to Home Screen, then open in airplane mode.
- The bottom home indicator not covering the FIRE button.
