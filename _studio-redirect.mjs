// _studio-redirect.mjs — M4 replacement for the studio.wikitata.com Vercel project.
//
// studio.wikitata.com now 307s straight to the Studio surface on the spine.
//
// It used to bounce through start's /services with the whole original URL encoded into
// ?return= (the Vercel behaviour this file first reproduced verbatim). Todd, 21 Sep:
// "I really want to get rid of the awkward redirect" — so the hop is gone and every path
// lands on /studio directly.
//
// Lives in this repo on purpose: the slim relic (wikitata-slim-5102) was an untracked
// directory on the M4 and became unattributable. A service with no repo is a future relic.
import http from 'node:http';

const PORT = Number(process.env.STUDIO_REDIRECT_PORT || 5106);
const TARGET = 'https://my.wikitata.com/studio';

http.createServer((req, res) => {
  res.writeHead(307, { location: TARGET, 'cache-control': 'no-store' });
  res.end();
}).listen(PORT, '127.0.0.1', () => {
  console.log(`[studio-redirect] listening on 127.0.0.1:${PORT} -> ${TARGET}`);
});
