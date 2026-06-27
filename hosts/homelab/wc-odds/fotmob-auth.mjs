// FotMob authed-API access — the "x-mas" signed-header scheme, reverse-engineered.
//
// FotMob's live data (real-time scores, ratings, etc.) comes from /api/data/* , which
// rejects any request without a valid `x-mas` header. The header is:
//
//   x-mas = base64( JSON.stringify({ body, signature }) )
//   body      = { url: <signed path>, code: <Date.now()>, foo: <build hash> }
//   signature = MD5( JSON.stringify(body) + SECRET ).toUpperCase()
//
// SECRET (currently the "Three Lions / It's coming home" lyrics) and `foo` are baked
// into FotMob's `_app-*.js` bundle and rotated on deploys, so we EXTRACT them at
// runtime and cache them — no brittle hardcoded constants. If they ever change the
// extraction shape, fotmobApi throws and callers fall back to HTML scraping.
//
// Why this is safe to read from plain Node fetch: the /api/data endpoints are gated by
// the header, not by Cloudflare (unlike some FotMob hosts), so no browser is needed.

import crypto from 'node:crypto';

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const SECRET_TTL = Number(process.env.FOTMOB_SECRET_TTL_SEC || 21600) * 1000; // re-extract every 6h

let secret = null; // { foo, lyrics, at }

async function loadSecret(force) {
    if (!force && secret && Date.now() - secret.at < SECRET_TTL) return secret;
    const home = await (await fetch('https://www.fotmob.com/', { headers: { 'User-Agent': UA, 'Accept': 'text/html' } })).text();
    const chunkPath = [...home.matchAll(/src="(\/_next\/static\/[^"]+\.js)"/g)].map(m => m[1]).find(u => /_app-/.test(u));
    if (!chunkPath) throw new Error('fotmob-auth: no _app chunk on homepage');
    const js = await (await fetch('https://www.fotmob.com' + chunkPath, { headers: { 'User-Agent': UA } })).text();

    const fooM = js.match(/foo:"(production:[0-9a-f]+)"/);
    const li = js.indexOf('o=(t="');
    if (!fooM || li < 0) throw new Error('fotmob-auth: signing secret not found in bundle');
    const ls = li + 'o=(t='.length;
    let qe = ls + 1;
    while (qe < js.length && !(js[qe] === '"' && js[qe - 1] !== '\\')) qe++;
    const lyrics = JSON.parse(js.slice(ls, qe + 1)); // surrounding quotes included → unescape

    secret = { foo: fooM[1], lyrics, at: Date.now() };
    console.log(`[fotmob-auth] signing secret refreshed (foo=${secret.foo.slice(0, 24)}…, ${lyrics.length} chars)`);
    return secret;
}

function buildXmas(signedPath, s) {
    const body = { url: signedPath, code: Date.now(), foo: s.foo };
    const signature = crypto.createHash('md5').update(JSON.stringify(body) + s.lyrics).digest('hex').toUpperCase();
    return Buffer.from(JSON.stringify({ body, signature })).toString('base64');
}

// GET https://www.fotmob.com/api/data<path> as JSON. `path` like '/matchDetails?matchId=123'.
// Retries once with a freshly-extracted secret if the first attempt is rejected (stale token).
export async function fotmobApi(path) {
    const signedPath = '/api/data' + path;
    let lastStatus = 0;
    for (let attempt = 0; attempt < 2; attempt++) {
        const s = await loadSecret(attempt === 1);
        const r = await fetch('https://www.fotmob.com' + signedPath, {
            headers: { 'User-Agent': UA, 'Accept': 'application/json', 'x-mas': buildXmas(signedPath, s) },
        });
        if (r.ok) return r.json();
        lastStatus = r.status;
        if (![401, 403, 404].includes(r.status)) break; // not an auth problem — don't bother retrying
    }
    throw new Error('fotmob-auth: api ' + lastStatus + ' for ' + path);
}
