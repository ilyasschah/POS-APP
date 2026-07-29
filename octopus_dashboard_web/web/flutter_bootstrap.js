// Custom Flutter bootstrap.
//
// The `{{...}}` tokens are substituted by `flutter build web`.
//
// This exists to omit `serviceWorkerSettings`. As of Flutter 3.35+ the
// generated `flutter_service_worker.js` is deprecated: it caches nothing and
// merely unregisters itself. Letting Flutter register it would race with, and
// clobber, the app-shell service worker registered from index.html (a scope
// can only hold one registration).
//
// See web/sw.js for the caching strategy.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
