'use strict';
// Listen Together / Room: ruang dengar bersama ala Discord.
// Host mengirim state (lagu, play/pause, posisi), anggota HANYA mengikuti. Real time lewat Server-Sent Events (SSE)
// + POST biasa: tanpa dependensi baru, aman lewat Cloudflare Tunnel. Ruang disimpan di memori
// (hilang saat server restart / setelah 6 jam tanpa aktivitas) -> jalankan satu instance server.
//
// Identitas: tiap orang yang masuk jadi "anggota" dengan pid (publik) dan ticket (rahasia, dipakai untuk SSE & aksi).
// Kalau login, nama + foto profil diambil dari akun; kalau tidak, dapat nama "Tamu xxx".
// Host = anggota dengan pid === room.hostPid. Aksi host: kick, blokir, pindah host, ubah nama/jenis ruang, akhiri ruang.
//
// Jenis ruang:
//   - private : tidak tampil di daftar; hanya bisa dimasuki lewat kode / link.
//   - public  : tampil di daftar "Room aktif" selama host online; siapa pun boleh masuk.
const express = require('express');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const DB = require('../db');
const { verifyToken } = require('../auth');

const router = express.Router();
const rooms = new Map();
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const MAX_ROOMS = 500;
const MAX_MEMBERS = 31;               // host + 30 tamu
const MAX_CONNS_PER_MEMBER = 4;
const IDLE_MS = 6 * 3600 * 1000;
const HOST_GRACE_MS = 60 * 1000;      // host boleh terputus sebentar (pindah jaringan / refresh) sebelum ruang ditutup
const MEMBER_GRACE_MS = 25 * 1000;    // anggota yang koneksinya putus dihapus dari daftar setelah ini
const PUBLIC_LIST_MAX = 50;

const clientIp = (req) => String(req.headers['cf-connecting-ip'] || req.ip || '');
const createLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: clientIp,
  message: { success: false, message: 'Terlalu sering membuat ruang, coba lagi nanti.' },
});

const str = (v, n) => String(v == null ? '' : v).slice(0, n);
// Nama untuk ditampilkan: buang karakter kontrol & tanda < > supaya aman dipakai di UI.
const label = (v, n) => str(v, n * 2).replace(/[\u0000-\u001f\u007f<>]/g, '').replace(/\s+/g, ' ').trim().slice(0, n);
const fail = (res, code, message) => res.status(code).json({ success: false, message });

function cleanTrack(t) {
  if (!t || typeof t !== 'object') return null;
  const videoId = str(t.videoId || t.id, 32).replace(/[^A-Za-z0-9_-]/g, '');
  if (!videoId) return null;
  const cover = str(t.cover || t.thumbnail, 500);
  return {
    id: videoId, videoId, title: str(t.title, 200), artist: str(t.artist, 200), artistId: str(t.artistId, 64),
    cover: /^(https?:\/\/|\/)/i.test(cover) ? cover : '', ytUrl: 'https://youtube.com/watch?v=' + videoId,
  };
}
const newCode = () => {
  for (let k = 0; k < 20; k++) {
    let c = ''; const b = crypto.randomBytes(6);
    for (let i = 0; i < 6; i++) c += ALPHABET[b[i] % ALPHABET.length];
    if (!rooms.has(c)) return c;
  }
  return null;
};
const rand = (n) => crypto.randomBytes(n).toString('hex');
const send = (res, event, data) => { try { res.write('event: ' + event + '\ndata: ' + JSON.stringify(data) + '\n\n'); } catch (_) {} };
const sendTo = (m, event, data) => m.conns.forEach((r) => send(r, event, data));
const broadcast = (room, event, data) => room.members.forEach((m) => sendTo(m, event, data));
const getRoom = (code) => rooms.get(String(code || '').toUpperCase());

// ── Identitas dari token login (opsional) ──
async function identify(req) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Bearer ')) return null;
  try {
    const p = verifyToken(h.slice(7).trim());
    const { rows } = await DB.query('SELECT id, username, token_version, created_at, avatar_v FROM ap_users WHERE id = $1', [p.uid]);
    const u = rows[0];
    if (!u || u.token_version !== p.tv) return null;
    return {
      userId: String(u.id), name: u.username,
      avatar: Number(u.avatar_v) > 0 ? '/api/auth/avatar/' + u.id + '?v=' + u.avatar_v : null,
      since: u.created_at ? new Date(u.created_at).getTime() : null,
    };
  } catch (_) { return null; }
}

// ── Model ──
const hostMember = (room) => room.members.get(room.hostPid);
const hostOnline = (room) => { const h = hostMember(room); return !!(h && h.conns.size > 0); };
const memberByTicket = (room, t) => {
  const pid = room.tickets.get(String(t || ''));
  return pid ? room.members.get(pid) : null;
};
const memberView = (room, m) => ({
  pid: m.pid, name: m.name, avatar: m.avatar, host: m.pid === room.hostPid, uid: m.userId ? Number(m.userId) : null, // [PATCH Tahap 5] uid untuk lapor/blokir
  online: m.conns.size > 0, joinedAt: m.joinedAt, since: m.since, guest: !m.userId,
});
const membersEvent = (room) => ({ hostPid: room.hostPid, members: [...room.members.values()].map((m) => memberView(room, m)) });

// Ringkasan aman untuk semua orang (tanpa ticket / ip).
function summary(code, room) {
  const st = room.state, h = hostMember(room);
  return {
    code, visibility: room.visibility, name: room.name,
    hostName: h ? h.name : 'Host', hostAvatar: h ? h.avatar : null,
    listeners: room.members.size, hostOnline: hostOnline(room),
    playing: !!(st && st.playing),
    track: st && st.track ? { id: st.track.id, title: st.track.title, artist: st.track.artist, cover: st.track.cover } : null,
    preview: [...room.members.values()].slice(0, 5).map((m) => ({ name: m.name, avatar: m.avatar })),
  };
}

function newMember(room, ident, ip) {
  const pid = rand(6), ticket = rand(16);
  const m = {
    pid, ticket, ip,
    userId: ident ? ident.userId : null,
    name: ident ? ident.name : 'Tamu ' + rand(2).toUpperCase(),
    avatar: ident ? ident.avatar : null,
    since: ident ? ident.since : null,
    joinedAt: Date.now(), lastSeen: Date.now(), conns: new Set(),
  };
  room.members.set(pid, m);
  room.tickets.set(ticket, pid);
  return m;
}
// Lepas anggota dari ruang (kick / blokir / diganti sesi baru / keluar).
function dropMember(room, m, reason) {
  if (reason) sendTo(m, 'kicked', { reason });
  m.conns.forEach((r) => { try { r.end(); } catch (_) {} });
  m.conns.clear();
  room.members.delete(m.pid);
  room.tickets.delete(m.ticket);
}
function endRoom(code, room, reason) {
  broadcast(room, 'end', { reason: reason || '' });
  room.members.forEach((m) => m.conns.forEach((r) => { try { r.end(); } catch (_) {} }));
  room.members.clear(); room.tickets.clear();
  if (rooms.get(code) === room) rooms.delete(code);
}

setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms) {
    const h = hostMember(room);
    if (now - room.touched > IDLE_MS) { endRoom(code, room); continue; }
    if (!h || (h.conns.size === 0 && now - h.lastSeen > HOST_GRACE_MS)) { endRoom(code, room); continue; }
    let changed = false;
    for (const m of [...room.members.values()]) {
      if (m.pid !== room.hostPid && m.conns.size === 0 && now - m.lastSeen > MEMBER_GRACE_MS) { dropMember(room, m); changed = true; }
    }
    if (changed) broadcast(room, 'members', membersEvent(room));
  }
}, 15 * 1000).unref();

const joinPayload = (code, room, m) => ({ success: true, code, pid: m.pid, ticket: m.ticket, host: m.pid === room.hostPid, room: summary(code, room) });

// Cek ticket pada aksi POST. Mengembalikan { room, member } atau mengirim error dan mengembalikan null.
function authz(req, res, needHost) {
  const room = getRoom(req.params.code);
  if (!room) { fail(res, 404, 'Ruang tidak ditemukan.'); return null; }
  const member = memberByTicket(room, req.body && req.body.ticket);
  if (!member) { fail(res, 403, 'Sesi ruang tidak valid.'); return null; }
  if (needHost && member.pid !== room.hostPid) { fail(res, 403, 'Hanya host yang bisa melakukan ini.'); return null; }
  room.touched = Date.now();
  return { room, member };
}

// ── Routes ──
router.post('/create', createLimiter, async (req, res) => {
  if (rooms.size >= MAX_ROOMS) return fail(res, 503, 'Server penuh, coba lagi nanti.');
  const ident = await identify(req);
  const code = newCode();
  if (!code) return fail(res, 503, 'Gagal membuat ruang.');
  const b = req.body || {};
  const now = Date.now();
  const room = {
    visibility: b.visibility === 'public' ? 'public' : 'private',
    name: '', hostPid: '', members: new Map(), tickets: new Map(), banned: new Map(),
    state: null, touched: now, createdAt: now,
  };
  const host = newMember(room, ident, clientIp(req));
  if (!ident) host.name = 'Host';
  room.hostPid = host.pid;
  room.name = label(b.name, 40) || ('Room ' + host.name);
  rooms.set(code, room);
  res.json(joinPayload(code, room, host));
});

// Daftar room publik yang host-nya sedang online.
router.get('/public', (req, res) => {
  res.set('Cache-Control', 'no-store');
  const list = [];
  for (const [code, room] of rooms) {
    if (room.visibility !== 'public' || !hostOnline(room)) continue;
    list.push({ s: summary(code, room), createdAt: room.createdAt });
  }
  list.sort((a, b) => (b.s.listeners - a.s.listeners) || (b.createdAt - a.createdAt));
  res.json({ success: true, rooms: list.slice(0, PUBLIC_LIST_MAX).map((x) => x.s) });
});

router.get('/:code/info', (req, res) => {
  res.set('Cache-Control', 'no-store');
  const code = String(req.params.code).toUpperCase();
  const room = rooms.get(code);
  if (!room) return fail(res, 404, 'Ruang tidak ditemukan.');
  res.json(Object.assign({ success: true }, summary(code, room)));
});

// Masuk ke ruang -> jadi anggota (dapat pid + ticket).
router.post('/:code/join', async (req, res) => {
  const code = String(req.params.code).toUpperCase();
  const room = rooms.get(code);
  if (!room) return fail(res, 404, 'Ruang tidak ditemukan.');
  const ident = await identify(req);
  const ip = clientIp(req);
  if (rooms.get(code) !== room) return fail(res, 404, 'Ruang tidak ditemukan.');
  for (const b of room.banned.values()) {
    if ((b.userId && ident && b.userId === ident.userId) || (b.ip && b.ip === ip)) return fail(res, 403, 'Kamu diblokir dari ruang ini.');
  }
  if (room.members.size >= MAX_MEMBERS) return fail(res, 429, 'Ruang penuh.');
  // Akun yang sama hanya tampil sekali: sesi lama diganti sesi baru (kalau dulu host, hak host ikut pindah).
  let inheritHost = false;
  if (ident) {
    for (const m of [...room.members.values()]) {
      if (m.userId === ident.userId) { inheritHost = inheritHost || m.pid === room.hostPid; dropMember(room, m, 'replaced'); }
    }
  }
  const m = newMember(room, ident, ip);
  if (inheritHost) room.hostPid = m.pid;
  room.touched = Date.now();
  broadcast(room, 'members', membersEvent(room));
  res.json(joinPayload(code, room, m));
});

router.get('/:code/events', (req, res) => {
  const code = String(req.params.code).toUpperCase();
  const room = rooms.get(code);
  if (!room) return fail(res, 404, 'Ruang tidak ditemukan.');
  const m = memberByTicket(room, req.query.t);
  if (!m) return fail(res, 403, 'Sesi ruang tidak valid.');
  res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
  res.flushHeaders();
  res.write('retry: 3000\n\n');
  while (m.conns.size >= MAX_CONNS_PER_MEMBER) { const old = m.conns.values().next().value; m.conns.delete(old); try { old.end(); } catch (_) {} }
  const wasOffline = m.conns.size === 0;
  m.conns.add(res);
  m.lastSeen = Date.now();
  room.touched = Date.now();
  const isHost = m.pid === room.hostPid;
  send(res, 'hello', Object.assign({
    code, name: room.name, visibility: room.visibility, you: { pid: m.pid, host: isHost },
    state: room.state, serverNow: Date.now(), hostOnline: hostOnline(room),
  }, membersEvent(room)));
  if (isHost && wasOffline) broadcast(room, 'host', { online: true });
  if (wasOffline) broadcast(room, 'members', membersEvent(room));
  const ping = setInterval(() => { try { res.write(': ping\n\n'); } catch (_) {} }, 20000);
  req.on('close', () => {
    clearInterval(ping);
    m.conns.delete(res);
    if (rooms.get(code) !== room || room.members.get(m.pid) !== m || m.conns.size > 0) return;
    m.lastSeen = Date.now();
    // Host terputus -> semua anggota berhenti (menunggu host kembali).
    if (m.pid === room.hostPid) {
      if (room.state) room.state = Object.assign({}, room.state, { playing: false, at: Date.now(), ev: 'away' });
      broadcast(room, 'host', { online: false, graceMs: HOST_GRACE_MS });
    }
    broadcast(room, 'members', membersEvent(room));
  });
});

router.post('/:code/state', (req, res) => {
  const a = authz(req, res, true); if (!a) return;
  const s = (req.body && req.body.state) || {};
  const track = cleanTrack(s.track);
  if (!track) return fail(res, 400, 'Lagu tidak valid.');
  const pos = Math.max(0, Math.min(86400, Number(s.pos) || 0));
  a.room.state = { track, playing: !!s.playing, pos, at: Date.now(), ev: str(s.ev, 12) };
  broadcast(a.room, 'state', a.room.state);
  res.json({ success: true });
});

// Host mengeluarkan anggota (ban = true -> juga diblokir dari ruang ini).
router.post('/:code/kick', (req, res) => {
  const a = authz(req, res, true); if (!a) return;
  const { room } = a, b = req.body || {};
  const target = room.members.get(String(b.pid || ''));
  if (!target) return fail(res, 404, 'Anggota tidak ditemukan.');
  if (target.pid === room.hostPid) return fail(res, 400, 'Host tidak bisa dikeluarkan.');
  const ban = !!b.ban;
  if (ban) room.banned.set(rand(4), { name: target.name, userId: target.userId, ip: target.ip });
  dropMember(room, target, ban ? 'ban' : 'kick');
  broadcast(room, 'members', membersEvent(room));
  res.json({ success: true });
});

// Pindahkan hak host ke anggota lain (musik berhenti sampai host baru memutar).
router.post('/:code/transfer', (req, res) => {
  const a = authz(req, res, true); if (!a) return;
  const { room } = a;
  const target = room.members.get(String((req.body || {}).pid || ''));
  if (!target || target.pid === room.hostPid) return fail(res, 404, 'Anggota tidak ditemukan.');
  if (target.conns.size === 0) return fail(res, 409, 'Anggota itu sedang terputus.');
  room.hostPid = target.pid;
  if (room.state) { room.state = Object.assign({}, room.state, { playing: false, at: Date.now(), ev: 'xfer' }); broadcast(room, 'state', room.state); }
  broadcast(room, 'members', membersEvent(room));
  broadcast(room, 'host', { online: true });
  res.json({ success: true });
});

router.post('/:code/settings', (req, res) => {
  const a = authz(req, res, true); if (!a) return;
  const { room } = a, b = req.body || {};
  if (b.name != null) { const n = label(b.name, 40); if (n) room.name = n; }
  if (b.visibility === 'public' || b.visibility === 'private') room.visibility = b.visibility;
  broadcast(room, 'room', { name: room.name, visibility: room.visibility });
  res.json({ success: true, name: room.name, visibility: room.visibility });
});

router.post('/:code/bans', (req, res) => {
  const a = authz(req, res, true); if (!a) return;
  res.json({ success: true, bans: [...a.room.banned.entries()].map(([id, x]) => ({ id, name: x.name })) });
});
router.post('/:code/unban', (req, res) => {
  const a = authz(req, res, true); if (!a) return;
  a.room.banned.delete(String((req.body || {}).id || ''));
  res.json({ success: true });
});

router.post('/:code/leave', (req, res) => {
  const room = getRoom(req.params.code);
  if (!room) return res.json({ success: true });
  const m = memberByTicket(room, req.body && req.body.ticket);
  if (!m) return res.json({ success: true });
  if (m.pid === room.hostPid) { endRoom(String(req.params.code).toUpperCase(), room); return res.json({ success: true }); }
  dropMember(room, m);
  broadcast(room, 'members', membersEvent(room));
  res.json({ success: true });
});

router.post('/:code/end', (req, res) => {
  const room = getRoom(req.params.code);
  if (!room) return res.json({ success: true });
  const a = authz(req, res, true); if (!a) return;
  endRoom(String(req.params.code).toUpperCase(), room);
  res.json({ success: true });
});

module.exports = router;
