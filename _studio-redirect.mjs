// _studio-redirect.mjs — M4 replacement for the studio.wikitata.com Vercel project.
//
// studio.wikitata.com is a catch-all redirect: EVERY path 307s to start's /services
// with the full original URL (path AND query) url-encoded into ?return=. Measured from
// the live Vercel surface on 2026-09-21 before the cutover:
//   /            -> ...?return=https%3A%2F%2Fstudio.wikitata.com%2F
//   /services    -> ...?return=https%3A%2F%2Fstudio.wikitata.com%2Fservices
//   /x?a=1&b=2   -> ...?return=https%3A%2F%2Fstudio.wikitata.com%2Fx%3Fa%3D1%26b%3D2
// req.url carries path+query, so encodeURIComponent(ORIGIN + req.url) reproduces all three.
//
// Lives in this repo on purpose: the slim relic (wikitata-slim-5102) was an untracked
// directory on the M4 and became unattributable. A service with no repo is a future relic.
import http from 'node:http';

const PORT = Number(process.env.STUDIO_REDIRECT_PORT || 5106);
const ORIGIN = 'https://studio.wikitata.com';
const TARGET = 'https://start.wikitata.com/services';

http.createServer((req, res) => {
  res.writeHead(307, {
    location: `${TARGET}?return=${encodeURIComponent(ORIGIN + req.url)}`,
    'cache-control': 'no-store',
  });
  res.end();
}).listen(PORT, '127.0.0.1', () => {
  console.log(`[studio-redirect] listening on 127.0.0.1:${PORT} -> ${TARGET}`);
});
