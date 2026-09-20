const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;
const key = process.env.LOADER_KEY;
const scriptPath = path.join(__dirname, 'script.lua');

function denied(res) {
  res.status(403).type('text/plain').set('Cache-Control', 'no-store').send('Acceso denegado');
}

app.get(['/loader', '/'], (req, res) => {
  const supplied = req.get('x-loader-key') || req.query.key;
  if (!key || supplied !== key) return denied(res);

  try {
    res.status(200)
      .type('text/plain')
      .set('Cache-Control', 'no-store, no-cache, must-revalidate')
      .set('X-Content-Type-Options', 'nosniff')
      .send(fs.readFileSync(scriptPath, 'utf8'));
  } catch {
    res.status(500).type('text/plain').send('Loader error');
  }
});

app.listen(port, '0.0.0.0', () => console.log(`Loader running on ${port}`));
