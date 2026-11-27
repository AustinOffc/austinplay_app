'use strict';
// [PATCH Tahap 5] Moderasi konten buatan pengguna (syarat Google Play untuk Chat Global & Room):
//   POST   /api/chat/report   {messageId, reason}   lapor pesan chat
//   POST   /api/report-user   {userId, reason}      lapor pengguna (mis. dari Room)
//   GET    /api/block                               daftar pengguna yang diblokir
//   POST   /api/block         {userId}              blokir
//   DELETE /api/block/:userId                       buka blokir
//   GET    /api/chat/reports                        (khusus admin chat) 50 laporan terbaru
// Tabel baru berawalan ap_ dibuat otomatis (lazy) seperti tabel lain. Router dipasang di '/api'
// SEBELUM router chat, dan auth dipasang per-rute (bukan router.use) supaya endpoint lain tidak tersentuh.
const express = require('express');
const rateLimit = require('express-rate-limit');
const DB = require('../db');
const settings = require('../../config/settings');
const { requireAuth } = require('../auth');

const router = express.Router();
const clientIp = (req) => String(req.headers['cf-connecting-ip'] || req.ip || '');
const ADMINS = new Set(settings.CHAT_ADMINS || []);
const isAdmin = (u) => ADMINS.has(String(u.username || '').toLowerCase());

const REPORT_TTL_DAYS = 90;
const MAX_BLOCKS = 500;
const REASONS = new Set(['spam', 'pelecehan', 'sara', 'seksual', 'kekerasan', 'lainnya']);

const SCHEMA = `
CREATE TABLE IF NOT EXISTS ap_reports (
  id               BIGSERIAL PRIMARY KEY,
  reporter_id      BIGINT REFERENCES ap_users(id) ON DELETE SET NULL,
  reported_user_id BIGINT REFERENCES ap_users(id) ON DELETE SET NULL,
  reported_name    TEXT,
  message_id       BIGINT,
  snapshot         TEXT,
  reason           TEXT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ap_reports_once_idx ON ap_reports (reporter_id, message_id) WHERE message_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ap_reports_created_idx ON ap_reports (created_at);
CREATE TABLE IF NOT EXISTS ap_blocks (
  user_id    BIGINT NOT NULL REFERENCES ap_users(id) ON DELETE CASCADE,
  blocked_id BIGINT NOT NULL REFERENCES ap_users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, blocked_id)
);
`;
let schemaP = null;
const ensure = () => {
  if (!schemaP) schemaP = DB.query(SCHEMA).catch((e) => { schemaP = null; throw e; });
  return schemaP;
};

const reportLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: clientIp,
  message: { success: false, message: 'Terlalu banyak laporan, coba lagi nanti.' },
});

const cleanReason = (r) => {
  const s = String(r == null ? '' : r).trim().toLowerCase();
  return REASONS.has(s) ? s : 'lainnya';
};

// Laporan lama dibuang otomatis (privasi): tiap jam.
async function purge() {
  try { await ensure(); await DB.query(`DELETE FROM ap_reports WHERE created_at < now() - interval '${REPORT_TTL_DAYS} days'`); } catch (_) {}
}
setTimeout(purge, 30 * 1000).unref();
setInterval(purge, 60 * 60 * 1000).unref();

router.post('/chat/report', reportLimiter, requireAuth, async (req, res, next) => {
  try {
    await ensure();
    const messageId = parseInt(req.body && req.body.messageId, 10);
    if (!(messageId > 0)) return res.status(400).json({ success: false, message: 'ID pesan tidak valid.' });
    const { rows } = await DB.query(
      'SELECT m.id, m.user_id, m.body, u.username FROM ap_chat_messages m JOIN ap_users u ON u.id = m.user_id WHERE m.id = $1',
      [messageId]
    );
    const m = rows[0];
    if (!m) return res.status(404).json({ success: false, message: 'Pesan sudah tidak ada.' });
    if (Number(m.user_id) === Number(req.user.id)) return res.status(400).json({ success: false, message: 'Tidak bisa melaporkan pesanmu sendiri.' });
    await DB.query(
      `INSERT INTO ap_reports (reporter_id, reported_user_id, reported_name, message_id, snapshot, reason)
       VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT DO NOTHING`,
      [req.user.id, m.user_id, m.username, m.id, String(m.body).slice(0, 500), cleanReason(req.body && req.body.reason)]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

router.post('/report-user', reportLimiter, requireAuth, async (req, res, next) => {
  try {
    await ensure();
    const userId = parseInt(req.body && req.body.userId, 10);
    if (!(userId > 0)) return res.status(400).json({ success: false, message: 'ID pengguna tidak valid.' });
    if (userId === Number(req.user.id)) return res.status(400).json({ success: false, message: 'Tidak bisa melaporkan dirimu sendiri.' });
    const { rows } = await DB.query('SELECT id, username FROM ap_users WHERE id = $1', [userId]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Pengguna tidak ditemukan.' });
    await DB.query(
      'INSERT INTO ap_reports (reporter_id, reported_user_id, reported_name, reason) VALUES ($1, $2, $3, $4)',
      [req.user.id, rows[0].id, rows[0].username, cleanReason(req.body && req.body.reason)]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

router.get('/chat/reports', requireAuth, async (req, res, next) => {
  try {
    if (!isAdmin(req.user)) return res.status(403).json({ success: false, message: 'Khusus admin.' });
    await ensure();
    const { rows } = await DB.query(
      'SELECT id, reported_user_id, reported_name, message_id, snapshot, reason, created_at FROM ap_reports ORDER BY id DESC LIMIT 50'
    );
    res.json({ success: true, reports: rows });
  } catch (err) { next(err); }
});

router.get('/block', requireAuth, async (req, res, next) => {
  try {
    await ensure();
    const { rows } = await DB.query(
      'SELECT u.id, u.username FROM ap_blocks b JOIN ap_users u ON u.id = b.blocked_id WHERE b.user_id = $1 ORDER BY b.created_at DESC',
      [req.user.id]
    );
    res.json({ success: true, blocked: rows.map((r) => ({ id: Number(r.id), username: r.username })) });
  } catch (err) { next(err); }
});

router.post('/block', requireAuth, async (req, res, next) => {
  try {
    await ensure();
    const userId = parseInt(req.body && req.body.userId, 10);
    if (!(userId > 0)) return res.status(400).json({ success: false, message: 'ID pengguna tidak valid.' });
    if (userId === Number(req.user.id)) return res.status(400).json({ success: false, message: 'Tidak bisa memblokir dirimu sendiri.' });
    const cnt = await DB.query('SELECT count(*)::int AS n FROM ap_blocks WHERE user_id = $1', [req.user.id]);
    if (cnt.rows[0].n >= MAX_BLOCKS) return res.status(400).json({ success: false, message: 'Daftar blokir penuh.' });
    const u = await DB.query('SELECT id FROM ap_users WHERE id = $1', [userId]);
    if (!u.rows[0]) return res.status(404).json({ success: false, message: 'Pengguna tidak ditemukan.' });
    await DB.query('INSERT INTO ap_blocks (user_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [req.user.id, userId]);
    res.json({ success: true });
  } catch (err) { next(err); }
});

router.delete('/block/:userId', requireAuth, async (req, res, next) => {
  try {
    await ensure();
    const userId = parseInt(req.params.userId, 10);
    if (!(userId > 0)) return res.status(400).json({ success: false, message: 'ID pengguna tidak valid.' });
    await DB.query('DELETE FROM ap_blocks WHERE user_id = $1 AND blocked_id = $2', [req.user.id, userId]);
    res.json({ success: true });
  } catch (err) { next(err); }
});

module.exports = router;
