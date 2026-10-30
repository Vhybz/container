const CACHE_NAME = 'container-pwa-v1';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './manifest.json',
  './favicon.png',
  './app_logo.png',
  './_redirects',
  './assets/AssetManifest.json',
  './assets/FontManifest.json',
  './assets/.env'
];

// Install Event: Precache Core App Shell
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Precaching App Shell');
      return cache.addAll(ASSETS_TO_CACHE).catch((err) => {
        console.warn('[Service Worker] App shell precache warning (ignored):', err);
      });
    })
  );
});

// Activate Event: Clean up stale caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            console.log('[Service Worker] Removing old cache:', cache);
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch Event: Cache-First / Stale-While-Revalidate with Fail-Safe Fallbacks
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // 1. Bypass Service Worker for external live API calls (Supabase, Arkesel, Paystack, AI)
  if (
    url.hostname.includes('supabase.co') ||
    url.hostname.includes('arkesel.com') ||
    url.hostname.includes('paystack.co') ||
    url.hostname.includes('openai.com')
  ) {
    return;
  }

  // 2. Handle HTML Navigation requests offline
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).catch(async () => {
        const cache = await caches.open(CACHE_NAME);
        const cachedIndex = await cache.match('./index.html') || await cache.match('/index.html') || await cache.match('./');
        if (cachedIndex) return cachedIndex;
        return new Response('<!DOCTYPE html><html><body>App Offline</body></html>', {
          headers: { 'Content-Type': 'text/html' }
        });
      })
    );
    return;
  }

  // 3. Cache-First with Network Revalidate for static assets
  event.respondWith(
    caches.match(req).then((cachedResponse) => {
      if (cachedResponse) {
        // Fetch background update for stale-while-revalidate
        fetch(req).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200 && req.method === 'GET') {
            caches.open(CACHE_NAME).then((cache) => cache.put(req, networkResponse));
          }
        }).catch(() => {});
        return cachedResponse;
      }

      return fetch(req).then((networkResponse) => {
        if (!networkResponse || networkResponse.status !== 200 || req.method !== 'GET') {
          return networkResponse;
        }
        const responseToCache = networkResponse.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(req, responseToCache);
        });
        return networkResponse;
      }).catch(async () => {
        const cached = await caches.match(req);
        if (cached) return cached;
        return new Response('', { status: 503, statusText: 'Offline' });
      });
    })
  );
});
