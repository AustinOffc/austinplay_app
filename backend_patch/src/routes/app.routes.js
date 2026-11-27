'use strict';
// [PATCH Tahap 5] Halaman legal, config app, dan assetlinks.json untuk Android App Links.
//   GET /privacy · /terms · /hapus-akun      halaman statis (src/legal/*.html); {{CONTACT_EMAIL}} diisi dari env CONTACT_EMAIL
//   GET /.well-known/assetlinks.json          dari env ANDROID_SHA256_CERTS (pisah koma)
//   GET /api/app/config                       {minVersion, latestVersion, notice} dari env
// express.static mengabaikan folder berawalan titik, karena itu assetlinks dilayani lewat rute sendiri.
const fs = require('fs');
const path = require('path');
const express = require('express');

const router = express.Router();
const PACKAGE = process.env.ANDROID_PACKAGE || 'id.austin.auzify';

const legal = (file) => (req, res) => {
  fs.readFile(path.join(__dirname, '..', 'legal', file), 'utf8', (err, txt) => {
    if (err) return res.status(404).type('text/plain').send('Not found');
    const mail = String(process.env.CONTACT_EMAIL || 'kontak@example.com').replace(/[<>&"']/g, '');
    res.set({
      'Cache-Control': 'no-cache',
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'",
    });
    res.type('html').send(txt.split('{{CONTACT_EMAIL}}').join(mail));
  });
};
router.get('/privacy', legal('privacy.html'));
router.get('/terms', legal('terms.html'));
router.get('/hapus-akun', legal('hapus-akun.html'));

router.get('/.well-known/assetlinks.json', (req, res) => {
  const certs = String(process.env.ANDROID_SHA256_CERTS || '').split(',').map((s) => s.trim()).filter(Boolean);
  res.set('Cache-Control', 'public, max-age=3600');
  res.json([{
    relation: ['delegate_permission/common.handle_all_urls'],
    target: { namespace: 'android_app', package_name: PACKAGE, sha256_cert_fingerprints: certs },
  }]);
});

router.get('/api/app/config', (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({
    success: true,
    minVersion: process.env.APP_MIN_VERSION || '1.0.0',
    latestVersion: process.env.APP_LATEST_VERSION || '1.0.0',
    notice: process.env.APP_NOTICE || '',
  });
});

module.exports = router;
