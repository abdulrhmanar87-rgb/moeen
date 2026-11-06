// عامل خدمة مُعين: يجعل التطبيق يفتح بدون إنترنت بعد أول فتح.
// - ملفات التطبيق: من الشبكة أولاً (لتصل التحديثات فوراً)، ومن المخزن عند انقطاع الإنترنت.
// - مكتبة قراءة الصور وملفات اللغة: من المخزن أولاً (لا تتغير).
const APP_CACHE = 'moeen-app-v2';
const CDN_CACHE = 'moeen-cdn-v1';
// محرك عرض Flutter وخطوطه الاحتياطية من gstatic، ومكتبة قراءة الصور وملفات لغتها.
const CDN_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com', 'unpkg.com', 'cdn.jsdelivr.net', 'tessdata.projectnaptha.com'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(APP_CACHE).then((c) => c.addAll(['./', 'index.html', 'manifest.json'])).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keep = [APP_CACHE, CDN_CACHE];
    for (const key of await caches.keys()) {
      if (!keep.includes(key)) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.protocol === 'blob:' || url.protocol === 'data:') return;

  if (CDN_HOSTS.includes(url.hostname)) {
    event.respondWith((async () => {
      const cache = await caches.open(CDN_CACHE);
      const hit = await cache.match(req);
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok || res.type === 'opaque') cache.put(req, res.clone());
      return res;
    })());
    return;
  }

  if (url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(APP_CACHE);
    try {
      // no-cache: يتحقق من الخادم في كل مرة فيصل التحديث فور نشره.
      const res = await fetch(req, { cache: 'no-cache' });
      if (res.ok) cache.put(req, res.clone());
      return res;
    } catch (e) {
      const hit = await cache.match(req, { ignoreSearch: true });
      if (hit) return hit;
      if (req.mode === 'navigate') {
        const page = await cache.match('index.html');
        if (page) return page;
      }
      throw e;
    }
  })());
});
