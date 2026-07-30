'use strict';

/**
 * App-shell service worker for the Octopus Owner Dashboard.
 *
 * Flutter used to generate a caching service worker; as of Flutter 3.35+ the
 * generated `flutter_service_worker.js` is deprecated and does nothing but
 * unregister itself, so the app-shell caching this PWA needs is implemented
 * here instead. It also satisfies Chrome's installability requirement for a
 * service worker with a fetch handler.
 *
 * Scope, deliberately narrow:
 *   - Caches the compiled app shell (JS, wasm, fonts, icons, assets) so repeat
 *     launches paint instantly.
 *   - NEVER caches API responses. Data must always be live — this app has no
 *     offline data model, and the API is frequently same-origin (hosted
 *     alongside the app on the OVH box), so `/api/` is explicitly excluded
 *     rather than relying on an origin check.
 *   - Not an offline experience. Without a network the shell will boot, but
 *     every screen will show its error state, which is the honest outcome.
 */

const CACHE_VERSION = 'v1';
const CACHE_NAME = `octopus-shell-${CACHE_VERSION}`;

/** Static file extensions that are safe to cache. */
const STATIC_EXTENSIONS = /\.(js|mjs|wasm|css|png|jpg|jpeg|gif|svg|ico|ttf|otf|woff2?|bin|json|symbols)$/i;

/** Directories emitted by `flutter build web`. */
const STATIC_PREFIXES = ['assets/', 'canvaskit/', 'icons/'];

self.addEventListener('install', (event) => {
  // Take over as soon as the new worker is ready rather than waiting for
  // every tab to close.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Drop caches from previous versions of this worker.
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith('octopus-shell-') && name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
      await self.clients.claim();
    })()
  );
});

/**
 * Decides whether a request may be served from / written to the cache.
 * Anything not explicitly allowed goes straight to the network.
 */
function isCacheableAsset(url) {
  // Hard exclusion: API traffic is never cached, same-origin or not.
  if (url.pathname.includes('/api/')) return false;

  const scopePath = new URL(self.registration.scope).pathname;
  const relative = url.pathname.startsWith(scopePath)
    ? url.pathname.slice(scopePath.length)
    : url.pathname.replace(/^\//, '');

  if (STATIC_PREFIXES.some((prefix) => relative.startsWith(prefix))) return true;
  return STATIC_EXTENSIONS.test(url.pathname);
}

/** Serve from cache immediately, refresh in the background for next time. */
async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  const network = fetch(request)
    .then((response) => {
      // Only store complete, successful, same-origin responses.
      if (response && response.status === 200 && response.type === 'basic') {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => undefined);

  return cached || network || fetch(request);
}

/** Prefer the network so a redeploy is picked up, fall back to cache offline. */
async function networkFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(request);
    if (response && response.status === 200 && response.type === 'basic') {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await cache.match(request);
    if (cached) return cached;
    throw error;
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Never interfere with writes, or with anything but HTTP(S) GETs.
  if (request.method !== 'GET') return;

  let url;
  try {
    url = new URL(request.url);
  } catch (e) {
    return;
  }

  if (url.origin !== self.location.origin) return;
  if (url.pathname.includes('/api/')) return;

  // The HTML document is fetched network-first so a redeployed build is
  // picked up on the next launch rather than being pinned by the cache.
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request));
    return;
  }

  if (isCacheableAsset(url)) {
    event.respondWith(staleWhileRevalidate(request));
  }
});
