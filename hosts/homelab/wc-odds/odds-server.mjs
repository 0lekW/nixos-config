// World Cup 2026 sweepstake — odds + highlights micro-service for the homelab.
//
// Watches the (free, keyless) results feed and, a while AFTER a match finishes
// (so bookmakers have had time to re-price), pulls fresh consensus outright odds
// from The Odds API and serves them as JSON. nginx-proxy-manager adds HTTPS in
// front; the sweepstake webpage fetches https://odds.<yourdomain>/odds.json.
//
// The Odds API key stays on this box (ODDS_API_KEY). No dependencies — Node 18+.
//   ODDS_API_KEY=xxxx node odds-server.mjs
//
// Env knobs:
//   PORT                (8764)  port to serve on
//   FINISH_DELAY_HOURS  (2)     wait this long after a match ends before refetching
//   POLL_MINUTES        (20)    how often to check the results feed for new finishes
//   ALLOW_ORIGIN        (*)     CORS origin to allow

import http from 'node:http';

const KEY          = process.env.ODDS_API_KEY;
const PORT         = Number(process.env.PORT || 8764);
const DELAY_H      = Number(process.env.FINISH_DELAY_HOURS || 2);
const POLL_MIN     = Number(process.env.POLL_MINUTES || 20);
const ALLOW_ORIGIN = process.env.ALLOW_ORIGIN || '*';

const WC_LEAGUE = 4429;   // TheSportsDB FIFA World Cup
const SDB_PAST  = `https://www.thesportsdb.com/api/v1/json/3/eventspastleague.php?id=${WC_LEAGUE}`;

// Canonical roster names (must match those in sweepStake/index.html)
const TEAMS = [
    'France','Spain','Argentina','Brazil','Germany','England','Portugal','Netherlands',
    'Morocco','Belgium','Croatia','Colombia','Senegal','Japan','Switzerland','Norway',
    'Canada','USA','Mexico','Algeria','Australia','Austria','Bosnia','Cape Verde',
    'DR Congo','Ivory Coast','Curaçao','Czechia','Ecuador','Egypt','Haiti','Ghana',
    'Iran','Iraq','Jordan','South Korea','New Zealand','Panama','Paraguay','Qatar',
    'Saudi Arabia','Scotland','Uruguay','South Africa','Sweden','Tunisia','Turkey','Uzbekistan',
];
const ALIASES = {
    Colombia: ['columbia'],
    USA: ['united states', 'united states of america'],
    Bosnia: ['bosnia and herzegovina', 'bosnia herzegovina', 'bosnia-herzegovina'],
    'Cape Verde': ['cabo verde'],
    'DR Congo': ['congo dr', 'democratic republic of congo', 'congo democratic republic', 'dr congo'],
    'Ivory Coast': ['cote divoire', 'cote d ivoire', "côte d'ivoire"],
    'Curaçao': ['curacao'],
    Czechia: ['czech republic'],
    'South Korea': ['korea republic', 'korea', 'republic of korea'],
    Turkey: ['turkiye', 'türkiye'],
};

const norm = s => (s || '')
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

const lookup = {};
for (const t of TEAMS) {
    lookup[norm(t)] = t;
    for (const a of (ALIASES[t] || [])) lookup[norm(a)] = t;
}

// in-memory cache served to clients
let cache = { updated: null, source: 'The Odds API consensus (uk, eu)', live: true, teamsMatched: 0, teams: {} };

async function refreshOdds(reason) {
    if (!KEY) { console.error('[wc-odds] ODDS_API_KEY not set'); return; }
    try {
        const url = `https://api.the-odds-api.com/v4/sports/soccer_fifa_world_cup_winner/odds/`
                  + `?apiKey=${KEY}&regions=uk,eu&markets=outrights&oddsFormat=decimal`;
        const r = await fetch(url);
        if (!r.ok) { console.error('[wc-odds] API', r.status, await r.text()); return; }
        const events = await r.json();

        const prices = {};
        for (const ev of events)
            for (const bk of (ev.bookmakers || []))
                for (const mk of (bk.markets || [])) {
                    if (mk.key !== 'outrights') continue;
                    for (const oc of (mk.outcomes || [])) {
                        const canon = lookup[norm(oc.name)];
                        if (!canon || typeof oc.price !== 'number' || oc.price <= 1) continue;
                        (prices[canon] ||= []).push(oc.price);
                    }
                }

        const teams = {};
        for (const [canon, list] of Object.entries(prices)) {
            const avgImplied = list.reduce((s, p) => s + 1 / p, 0) / list.length;
            teams[canon] = Math.round((1 / avgImplied) * 100) / 100;
        }

        const matched = Object.keys(teams).length;
        if (matched < 10) { console.error(`[wc-odds] only ${matched} teams matched — keeping previous`); return; }

        cache = {
            updated: new Date().toISOString(),
            source: 'The Odds API consensus (uk, eu)',
            live: true,
            teamsMatched: matched,
            teams,
        };
        console.log(`[wc-odds] odds refreshed (${reason}) — ${matched}/${TEAMS.length} teams @ ${cache.updated}`);
    } catch (e) {
        console.error('[wc-odds] refresh failed:', e.message);
    }
}

// ---- match-finish detection (keyless, unlimited) ----
const seenFinished = new Set();
let pendingTimer = null;

async function fetchFinishedIds() {
    const r = await fetch(SDB_PAST);
    if (!r.ok) throw new Error('SDB ' + r.status);
    const j = await r.json();
    return (j.events || [])
        .filter(e => e.intHomeScore !== null && e.intHomeScore !== '' &&
                     e.intAwayScore !== null && e.intAwayScore !== '')
        .map(e => e.idEvent);
}

async function pollResults() {
    try {
        const ids = await fetchFinishedIds();
        const fresh = ids.filter(id => !seenFinished.has(id));
        ids.forEach(id => seenFinished.add(id));
        if (fresh.length && !pendingTimer) {
            console.log(`[wc-odds] ${fresh.length} new result(s) — scheduling odds refresh in ${DELAY_H}h`);
            pendingTimer = setTimeout(async () => {
                pendingTimer = null;
                await refreshOdds('after match finished');
            }, DELAY_H * 3600 * 1000);
        }
    } catch (e) {
        console.error('[wc-odds] poll failed:', e.message);
    }
}

// ============================================================
//  HIGHLIGHTS — official match-highlight links, scraped from FotMob.
//  FotMob's clean JSON endpoint now needs a signed header, so we parse the
//  __NEXT_DATA__ JSON embedded in their match pages. Served at /highlights.json.
//  We host NO video — these are links to the official source (fifa.com etc).
//  Brittle by nature: if the feed empties, FotMob reshaped their page data and
//  the selectors below (fixtures.allMatches / content.matchFacts.highlights) need a refresh.
// ============================================================
const HL_POLL_MIN = Number(process.env.HL_POLL_MINUTES || 30);
const HL_MAX      = Number(process.env.HL_MAX_CLIPS || 0); // 0 = no cap
const FOTMOB_WC_LEAGUE = 77; // FotMob FIFA World Cup league id
const FOTMOB_LEAGUE_URL = `https://www.fotmob.com/leagues/${FOTMOB_WC_LEAGUE}/overview/world-cup`;
const FOTMOB_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
};

let hlCache = { updated: null, source: 'FotMob → official match highlights', count: 0, clips: [] };
const hlResolved = new Map(); // matchId -> clip; once it has a url we don't refetch its page
const hlSleep = ms => new Promise(r => setTimeout(r, ms));

async function fotmobNextData(url) {
    const r = await fetch(url, { headers: FOTMOB_HEADERS });
    if (!r.ok) throw new Error(`${r.status} for ${url}`);
    const html = await r.text();
    const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
    if (!m) throw new Error(`no __NEXT_DATA__ at ${url}`);
    return JSON.parse(m[1]);
}
function hlParseScore(s) {
    const m = /(\d+)\s*-\s*(\d+)/.exec(s || '');
    return m ? [Number(m[1]), Number(m[2])] : [null, null];
}
function hlToISO(v) {
    if (v == null) return null;
    if (typeof v === 'number') return new Date(v).toISOString();
    const t = Date.parse(v);
    return Number.isNaN(t) ? null : new Date(t).toISOString();
}
async function refreshHighlights(reason) {
    try {
        const nd = await fotmobNextData(FOTMOB_LEAGUE_URL);
        const all = nd?.props?.pageProps?.fixtures?.allMatches || [];
        const finished = all.filter(m => m?.status?.finished);
        for (const m of finished) {
            const id = String(m.id);
            const have = hlResolved.get(id);
            if (have && have.url) continue; // already resolved with a clip
            try {
                const slug = String(m.pageUrl || '').split('#')[0];
                if (!slug) continue;
                const mnd = await fotmobNextData('https://www.fotmob.com' + slug);
                const facts = mnd?.props?.pageProps?.content?.matchFacts || {};
                const hl = facts.highlights || null;
                const [hs, as] = hlParseScore(m?.status?.scoreStr);
                hlResolved.set(id, {
                    id,
                    home: m.home?.name ?? null,
                    away: m.away?.name ?? null,
                    homeScore: hs, awayScore: as,
                    kickoff: hlToISO(m?.status?.utcTime ?? null),
                    round: m.roundName || (m.round != null ? `Round ${m.round}` : null),
                    url: hl?.url || null, source: hl?.source || null, thumb: hl?.image || null,
                });
                await hlSleep(400); // be polite between match-page fetches
            } catch (e) {
                console.error('[wc-odds] highlight match', id, e.message);
            }
        }
        let clips = [...hlResolved.values()].filter(c => c.url);
        clips.sort((a, b) => (Date.parse(b.kickoff) || 0) - (Date.parse(a.kickoff) || 0));
        if (HL_MAX > 0) clips = clips.slice(0, HL_MAX);
        hlCache = { updated: new Date().toISOString(), source: 'FotMob → official match highlights', count: clips.length, clips };
        console.log(`[wc-odds] highlights refreshed (${reason}) — ${clips.length} clip(s) from ${finished.length} finished`);
    } catch (e) {
        console.error('[wc-odds] highlights refresh failed:', e.message); // keep previous cache
    }
}

// ---- HTTP server ----
const corsHeaders = { 'Access-Control-Allow-Origin': ALLOW_ORIGIN, 'Cache-Control': 'public, max-age=300' };
http.createServer((req, res) => {
    if (req.method === 'OPTIONS') { res.writeHead(204, corsHeaders); return res.end(); }
    if (req.url.startsWith('/odds.json')) {
        res.writeHead(200, { 'Content-Type': 'application/json', ...corsHeaders });
        return res.end(JSON.stringify(cache));
    }
    if (req.url.startsWith('/highlights.json')) {
        res.writeHead(200, { 'Content-Type': 'application/json', ...corsHeaders });
        return res.end(JSON.stringify(hlCache));
    }
    res.writeHead(404, corsHeaders);
    res.end('not found');
}).listen(PORT, () => console.log(`[wc-odds] serving /odds.json + /highlights.json on :${PORT}`));

// ---- startup: one odds fetch, seed the seen-set so we don't fire for old games ----
(async () => {
    await refreshOdds('startup');
    try { (await fetchFinishedIds()).forEach(id => seenFinished.add(id)); } catch (e) {}
    console.log(`[wc-odds] watching results every ${POLL_MIN}m; will refetch ${DELAY_H}h after each finish`);
    setInterval(pollResults, POLL_MIN * 60 * 1000);

    // highlights: scrape on startup, then on its own slower cadence (fire-and-forget)
    refreshHighlights('startup');
    setInterval(() => refreshHighlights('poll'), HL_POLL_MIN * 60 * 1000);
})();
