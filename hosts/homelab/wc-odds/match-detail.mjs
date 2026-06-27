// Per-match detail for the sweepstake popup: scorers, player ratings, key stats.
//
// FotMob carries all of this in the match page's __NEXT_DATA__ (the same blob the
// highlights/fixtures scrapers already read). We extract a compact, stable shape so
// the webpage never has to understand FotMob's sprawling (and reshaped-without-notice)
// schema. Brittle by nature: if a section empties, FotMob moved it and the paths below
// (content.matchFacts / content.lineup / content.stats) need a refresh.

// ---- helpers -------------------------------------------------------------
const num = v => (v == null || v === '' ? null : Number(v));
const ratingOf = p => {
    const r = p?.performance?.rating ?? p?.rating;
    if (r == null) return null;
    const n = Number(typeof r === 'object' ? r.num : r);
    return Number.isFinite(n) ? n : null;
};

// FotMob top-stat values come as 60, "1.46", or "467 (90%)" depending on format.
function statValue(v) {
    if (typeof v === 'number') return v;
    if (typeof v === 'string') return v.trim();
    return null;
}

// ---- main extractor ------------------------------------------------------
// Takes the parsed __NEXT_DATA__ of a FotMob match page and returns the compact shape.
export function extractMatchDetail(nd, idHint) {
    const pp = nd?.props?.pageProps || {};
    const content = pp.content || {};
    const mf = content.matchFacts || {};
    const status = pp.header?.status || {};
    const teamsHdr = pp.header?.teams || [];

    const id = String(mf.matchId ?? pp.general?.matchId ?? idHint ?? '');
    const [hs, as] = (() => {
        const m = /(\d+)\s*-\s*(\d+)/.exec(status.scoreStr || '');
        return m ? [Number(m[1]), Number(m[2])] : [null, null];
    })();

    let state = 'upcoming';
    if (status.cancelled) state = 'cancelled';
    else if (status.finished) state = 'finished';
    else if (status.started) state = 'live';

    // ---- events: goals / cards / subs, in match order ----
    const rawEvents = mf.events?.events || [];
    const events = [];
    for (const e of rawEvents) {
        const base = { time: e.time ?? null, addedTime: e.overloadTime || null, isHome: !!e.isHome, type: e.type };
        if (e.type === 'Goal') {
            const desc = `${e.goalDescription || ''} ${e.goalDescriptionKey || ''}`.toLowerCase();
            events.push({ ...base, player: e.nameStr || e.player?.name || null,
                assist: e.assistInput || null, ownGoal: !!e.ownGoal,
                penalty: /pen/.test(desc), newScore: e.newScore || null,
                playerId: e.playerId ?? e.player?.id ?? null });
        } else if (e.type === 'Card') {
            events.push({ ...base, player: e.nameStr || e.player?.name || null,
                card: e.card || null, playerId: e.playerId ?? e.player?.id ?? null });
        } else if (e.type === 'Substitution') {
            const sw = e.swap || [];
            events.push({ ...base, on: sw[0]?.name || null, off: sw[1]?.name || null });
        }
    }

    // per-player goal/card tallies, keyed by FotMob playerId, for annotating the lineup
    const goalsBy = {}, cardsBy = {};
    for (const e of events) {
        if (e.type === 'Goal' && e.playerId != null && !e.ownGoal) goalsBy[e.playerId] = (goalsBy[e.playerId] || 0) + 1;
        if (e.type === 'Card' && e.playerId != null) cardsBy[e.playerId] = e.card; // last card wins (yellow->red)
    }

    // ---- lineups with ratings ----
    const lu = content.lineup || {};
    const mapPlayer = p => {
        const subEv = p?.performance?.substitutionEvents || [];
        const subIn = subEv.find(s => s.type === 'subIn');
        const subOut = subEv.find(s => s.type === 'subOut');
        const v = p.verticalLayout || null;
        return {
            id: p.id ?? null,
            name: p.name || [p.firstName, p.lastName].filter(Boolean).join(' ') || null,
            shirt: p.shirtNumber ?? null,
            rating: ratingOf(p),
            captain: !!p.isCaptain,
            goals: goalsBy[p.id] || 0,
            card: cardsBy[p.id] || null,
            subIn: subIn ? subIn.time : null,
            subOut: subOut ? subOut.time : null,
            // normalised pitch position (0..1): x across, y down (GK ~0.1, forwards ~0.9)
            x: v && typeof v.x === 'number' ? v.x : null,
            y: v && typeof v.y === 'number' ? v.y : null,
        };
    };
    const mapSide = side => side ? {
        name: side.name || null,
        formation: side.formation || null,
        teamRating: ratingOf(side),
        coach: side.coach?.name || null,
        starters: (side.starters || []).map(mapPlayer),
        subs: (side.subs || []).map(mapPlayer),
    } : null;
    const lineups = (lu.homeTeam || lu.awayTeam)
        ? { home: mapSide(lu.homeTeam), away: mapSide(lu.awayTeam) } : null;

    // ---- player of the match ----
    const pom = mf.playerOfTheMatch;
    const motm = pom ? {
        name: pom.name?.fullName || [pom.name?.firstName, pom.name?.lastName].filter(Boolean).join(' ') || null,
        team: pom.teamName || null,
        rating: ratingOf(pom),
        isHome: lineups && pom.teamId != null
            ? (pom.teamId === lu.homeTeam?.id) : null,
    } : null;

    // ---- top stats ----
    const groups = content.stats?.Periods?.All?.stats || [];
    const top = groups.find(g => g.key === 'top_stats') || groups[0];
    const topStats = (top?.stats || []).map(s => ({
        title: s.title, format: s.format || null, highlighted: s.highlighted || null,
        home: statValue(s.stats?.[0]), away: statValue(s.stats?.[1]),
    })).filter(s => s.home != null || s.away != null);

    // ---- info box ----
    const ib = mf.infoBox || {};
    const info = {
        stadium: ib.Stadium ? [ib.Stadium.name, ib.Stadium.city].filter(Boolean).join(', ') : null,
        referee: ib.Referee?.text || null,
        attendance: ib.Attendance ?? null,
        tournament: ib.Tournament?.leagueName || null,
    };

    const teamSide = (i, side) => ({
        name: teamsHdr[i]?.name || side?.name || null,
        score: i === 0 ? hs : as,
        formation: side?.formation || null,
        teamRating: side?.teamRating ?? null,
        coach: side?.coach || null,
        redCards: i === 0 ? (status.numberOfHomeRedCards || 0) : (status.numberOfAwayRedCards || 0),
    });

    return {
        id,
        state,
        statusLabel: status.reason?.short || status.liveTime?.short || null,
        kickoff: status.utcTime || null,
        home: teamSide(0, lineups?.home),
        away: teamSide(1, lineups?.away),
        events,
        motm,
        lineups,
        topStats,
        info,
    };
}
