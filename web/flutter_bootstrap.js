{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's own worker is deprecated and unregisters itself, which
// would take sw.js (same scope) down with it. index.html registers sw.js instead.
_flutter.loader.load();
