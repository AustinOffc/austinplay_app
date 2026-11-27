'use strict';

require('dns').setDefaultResultOrder('ipv4first');

const path = require('path');
const express = require('express');
const rateLimit = require('express-rate-limit');

const settings = require('../config/settings');
const DB = require('./db');
const { streamProxy } = require('./proxy');
const ytdlp = require('./ytdlp');
const audiocache = require('./audiocache');
const pages = require('./pages');

const app = express();

app.disable('x-powered-by');
// Di belakang Cloudflare Tunnel (cloudflared berjalan di container yang sama).
app.set('trust proxy', 'loopback, linklocal, uniquelocal');

process.on('unhandledRejection', (err) => console.error('[unhandledRejection]', err && err.message ? err.message : err));
process.on('uncaughtException', (err) => console.error('[uncaughtException]', err && err.stack ? err.stack : err));

// Frontend dan API satu origin: tidak ada CORS / lintas-domain. Browser tidak akan mengizinkan
// situs lain membaca respons API ini karena tidak ada header Access-Control-Allow-Origin.

// Header keamanan dasar untuk semua respons.
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  next();
});

// ── Frontend statis (folder public/) ──
// JS/CSS/HTML selalu divalidasi ulang (ETag); versi baru lewat ?v= di index.html. Gambar di-cache 7 hari.
const IMAGE_EXT = new Set(['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.ico']);
app.use(express.static(settings.PUBLIC_DIR, {
  setHeaders(res, filePath) {
    const ext = path.extname(filePath).toLowerCase();
    if (IMAGE_EXT.has(ext)) res.setHeader('Cache-Control', 'public, max-age=604800, immutable');
    else res.setHeader('Cache-Control', 'no-cache'); // termasuk sw.js: wajib selalu dicek ke server
  },
}));

// ── API ──
app.use('/api', (req, res, next) => {
  res.setHeader('Referrer-Policy', 'no-referrer');
  next();
});
app.use('/api', express.json({ limit: '3mb' }));

const clientIp = (req) => String(req.headers['cf-connecting-ip'] || req.ip || '');

// Health check (tanpa limiter).
app.get('/api/health', async (req, res) => {
  try {
    await DB.query('SELECT 1');
    res.json({ success: true, status: 'ok', uptime: Math.round(process.uptime()) });
  } catch (e) {
    res.status(503).json({ success: false, status: 'db_error' });
  }
});

// Status provider audio (tanpa path/rahasia) untuk pemantauan.
app.get('/api/audio-status', (req, res) => {
  const y = ytdlp.status(), c = audiocache.stats();
  res.json({ success: true, ytdlp: { ready: y.ready, variant: y.variant, ageDays: y.ageDays, running: y.running, waiting: y.waiting }, cache: { enabled: c.enabled, songs: c.songs, mb: c.mb, maxMb: c.maxMb, downloading: c.downloading } });
});

// Streaming audio/gambar: tanpa limiter ketat (satu lagu bisa memicu banyak request Range).
app.get('/api/proxy-audio', (req, res) => streamProxy(req, res, { kind: 'audio' }));
app.get('/api/proxy-image', (req, res) => streamProxy(req, res, { kind: 'image' }));

// Limiter umum untuk endpoint lainnya.
app.use('/api', rateLimit({
  windowMs: 60 * 1000,
  max: 240,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: clientIp,
  message: { success: false, status: false, message: 'Terlalu banyak request, coba lagi sebentar.' },
}));

// ── API musik (handler dipakai apa adanya dari versi sebelumnya) ──
const H = (name) => require('./handlers/' + name + '.js');
app.all('/api/search', H('search'));
app.all('/api/lyrics', H('lyrics'));
app.all('/api/lyrics1', H('lyrics1'));
app.all('/api/lyrics2', H('lyrics2'));
app.all('/api/artist', H('artist'));
app.all('/api/album', H('album'));
app.all('/api/suggest', H('suggest'));
app.all('/api/ytplay', H('ytplay'));
app.all('/api/translate', H('translate'));
app.all('/api/transcribe', H('transcribe'));
app.all('/api/sponsorblock', H('sponsorblock'));
app.all('/api/romanize', H('romanize'));

// ── Akun & sinkronisasi antar device ──
// [PATCH Tahap 5] hapus akun: harus SEBELUM router /api/auth
app.use('/api/auth/account', require('./routes/account.routes'));
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/sync', require('./routes/sync.routes'));
app.use('/api/together', require('./routes/together.routes'));
// [PATCH Tahap 5] moderasi (lapor/blokir) harus SEBELUM router chat; halaman legal, assetlinks, config app
app.use('/api', require('./routes/moderation.routes'));
app.use('/api/chat', require('./routes/chat.routes'));
app.use('/', require('./routes/app.routes'));

// Endpoint /api/* yang tidak ada -> JSON 404 (jangan jatuh ke halaman SPA).
app.use('/api', (req, res) => {
  res.status(404).json({ success: false, status: false, message: 'Endpoint tidak ditemukan' });
});

// ── Halaman ──
// Link yang dibagikan: index.html dengan meta tag OG/Twitter sesuai lagu/artis/album.
app.get(['/play', '/play/*', '/artist', '/artist/*', '/album', '/album/*'], pages.preview);

// Semua halaman SPA lain (path tanpa titik) -> index.html. File yang tidak ada (ada titik) -> 404.
app.get(/^\/[^.]*$/, pages.index);

app.use((req, res) => {
  res.status(404).type('text/plain').send('Not found');
});

app.use((err, req, res, next) => {
  const code = err && (err.status || err.statusCode);
  const status = code >= 400 && code < 500 ? code : 500;
  console.error(`Server error [${status}] ${req.method} ${req.originalUrl}:`, err && err.message ? err.message : err);
  if (res.headersSent) return next(err);
  res.status(status).json({ success: false, status: false, message: status === 500 ? 'Terjadi kesalahan pada server.' : err.message });
});

(async () => {
  const ok = await DB.init();
  if (!ok) console.error('[DB] Database belum bisa dihubungi. Endpoint login/sync akan error sampai DB siap; endpoint musik tetap jalan.');
  const server = app.listen(settings.PORT, settings.HOST, () => {
    console.log(`🎵 Auzify (web + API) berjalan di ${settings.HOST}:${settings.PORT}`);
    console.log('   Frontend:', pages.hasIndex() ? settings.PUBLIC_DIR : `PERINGATAN: index.html tidak ditemukan di ${settings.PUBLIC_DIR}`);
    if (settings.PUBLIC_URL) console.log('   URL publik:', settings.PUBLIC_URL);
    audiocache.cleanup();
    ytdlp.startMaintenance(); // unduh/validasi yt-dlp sekarang & update berkala
    require('./prewarm').start(); // pra-unduh lagu populer ke cache disk
  });
  // Koneksi di belakang tunnel/reverse proxy: keep-alive server harus LEBIH LAMA dari milik proxy, dan stream audio
  // panjang tidak boleh dipotong timeout permintaan -> mencegah musik terputus di tengah saat layar mati.
  server.keepAliveTimeout = 65000;
  server.headersTimeout = 66000;
  server.requestTimeout = 0;
  server.timeout = 0;
})();

module.exports = app;
