// Knockout bracket for the sweepstake widget.
//
// FotMob's league page __NEXT_DATA__ carries the full playoff tree at
// props.pageProps.playoff — every round's matchups with draw order, team names
// (real or TBD slot codes like "3CEFHI" until groups finish), per-match ids,
// scores and winners, plus a separate bronzeFinal. We flatten it into a compact,
// stable shape the page renders as a vertical, round-by-round bracket.
//
// Scores in this SSR blob lag live play; odds-server overlays fresh live scores
// for in-progress knockout matches via the authed API before serving /bracket.json.

function roundName(r) {
    const map = { '1/16': 'Round of 32', '1/8': 'Round of 16', '1/4': 'Quarter-finals', '1/2': 'Semi-finals' };
    if (map[r?.stage]) return map[r.stage];
    if (/final/i.test(r?.stage || '') || r?.stage === '1/1' || r?.participantCount === 2) return 'Final';
    return r?.stage || '';
}

function statusBits(s) {
    let state = 'upcoming', label = 'NS';
    if (s?.cancelled) { state = 'cancelled'; label = 'Cancelled'; }
    else if (s?.finished) { state = 'finished'; label = s.reason?.short || 'FT'; }
    else if (s?.started) { state = 'live'; label = s.liveTime?.short || s.reason?.short || 'LIVE'; }
    return { state, label, kickoff: s?.utcTime || null };
}

// one matchup -> compact card data. Scores only surface once the game is under way.
function mapMatchup(mu) {
    if (!mu) return null;
    const m = (mu.matches || [])[0] || {};
    const { state, label, kickoff } = statusBits(m.status);
    const live = state === 'live' || state === 'finished';
    const side = (t, fallbackName, fallbackShort) => ({
        name: t?.name ?? fallbackName ?? null,
        short: t?.shortName ?? fallbackShort ?? null,
        id: t?.id != null ? String(t.id) : null,
        score: live && typeof t?.score === 'number' ? t.score : null,
        winner: !!t?.winner,
    });
    return {
        drawOrder: mu.drawOrder ?? 0,
        matchId: m.matchId != null ? String(m.matchId) : null,
        tbd1: !!mu.tbdTeam1, tbd2: !!mu.tbdTeam2,
        home: side(m.home, mu.homeTeam, mu.homeTeamShortName),
        away: side(m.away, mu.awayTeam, mu.awayTeamShortName),
        state, label, kickoff,
    };
}

export function extractBracket(playoff) {
    if (!playoff) return { rounds: [], bronze: null };
    const rounds = (playoff.rounds || []).map(r => ({
        stage: r.stage,
        name: roundName(r),
        matchups: (r.matchups || []).map(mapMatchup).filter(Boolean)
            .sort((a, b) => (a.drawOrder ?? 0) - (b.drawOrder ?? 0)),
    }));
    // bronzeFinal may be a matchup, or a round-like object wrapping matchups
    let bronze = null;
    const bf = playoff.bronzeFinal;
    if (bf) bronze = mapMatchup(Array.isArray(bf.matchups) ? bf.matchups[0] : bf);
    return { rounds, bronze };
}
