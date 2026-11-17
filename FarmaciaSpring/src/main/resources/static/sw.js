/*
 * SERVICE WORKER de la PWA.
 * Estrategia "red primero": los datos de la farmacia SIEMPRE se piden al servidor (deben ser actuales).
 * Solo se guardan en caché los archivos estáticos (CSS, JS, íconos) para que la app abra rápido,
 * y una página "sin conexión" para cuando no hay internet.
 */
const CACHE = 'farmacia-v1';
const ESTATICOS = ['/css/estilos.css', '/js/app.js', '/offline.html', '/icons/icon-192.png', '/icons/icon-512.png'];

self.addEventListener('install', (e) => {
    e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ESTATICOS)));
    self.skipWaiting();
});

self.addEventListener('activate', (e) => {
    e.waitUntil(caches.keys().then((claves) =>
        Promise.all(claves.filter((k) => k !== CACHE).map((k) => caches.delete(k)))));
    self.clients.claim();
});

self.addEventListener('fetch', (e) => {
    const req = e.request;
    if (req.method !== 'GET') return;                       // formularios (POST) van directo al servidor
    const url = new URL(req.url);
    const esEstatico = ESTATICOS.includes(url.pathname);

    if (esEstatico) {                                        // caché primero para estáticos
        e.respondWith(caches.match(req).then((r) => r || fetch(req)));
        return;
    }
    if (req.mode === 'navigate') {                           // páginas: red primero
        e.respondWith(fetch(req).catch(() => caches.match('/offline.html')));
    }
});
