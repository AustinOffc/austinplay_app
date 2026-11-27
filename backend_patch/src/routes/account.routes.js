'use strict';
// [PATCH Tahap 5] Hapus akun (syarat Google Play: opsi hapus akun di dalam app + tautan web).
//   DELETE /api/auth/account  body {password}  -> hapus user + data sinkron + pesan chat (ON DELETE CASCADE).
// Dipasang SEBELUM auth.routes di server.js supaya tidak mengubah kontrak endpoint yang sudah ada.
const express = require('express');
const rateLimit = require('express-rate-limit');
const DB = require('../db');
const { verifyPassword, requireAuth, clearSessionCookie } = require('../auth');

const router = express.Router();
const clientIp = (req) => String(req.headers['cf-connecting-ip'] || req.ip || '');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: clientIp,
  message: { success: false, message: 'Terlalu banyak percobaan, coba lagi beberapa menit lagi.' },
});

router.delete('/', limiter, requireAuth, async (req, res, next) => {
  try {
    const password = String((req.body && req.body.password) || '');
    if (!password || password.length > 128) {
      return res.status(400).json({ success: false, message: 'Password wajib diisi.' });
    }
    const { rows } = await DB.query('SELECT id, password_hash FROM ap_users WHERE id = $1', [req.user.id]);
    const user = rows[0];
    if (!user || !verifyPassword(password, user.password_hash)) {
      return res.status(401).json({ success: false, message: 'Password salah.' });
    }
    // ap_user_data, ap_chat_messages, ap_blocks ikut terhapus (ON DELETE CASCADE).
    // ap_reports: pelapor/terlapor diset NULL, isi laporan dibuang otomatis setelah 90 hari (lihat moderation.routes.js).
    await DB.query('DELETE FROM ap_users WHERE id = $1', [user.id]);
    clearSessionCookie(req, res);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
