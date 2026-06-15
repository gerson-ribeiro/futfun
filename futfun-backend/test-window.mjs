// Quick test: verifies that TheSportsDB returns matches in the -1/+3 day window
// Run with: node test-window.mjs

const BASE_URL = 'https://www.thesportsdb.com/api/v1/json/3';
const LEAGUE_ID = '4562';

function getMatchWindow() {
  const now = new Date();
  const from = new Date(now);
  from.setUTCDate(now.getUTCDate() - 1);
  from.setUTCHours(0, 0, 0, 0);
  const to = new Date(now);
  to.setUTCDate(now.getUTCDate() + 3);
  to.setUTCHours(23, 59, 59, 999);
  return { from, to, dateFrom: from.toISOString().split('T')[0], dateTo: to.toISOString().split('T')[0] };
}

async function fetchJson(path) {
  const res = await fetch(`${BASE_URL}${path}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

async function main() {
  const { from, to, dateFrom, dateTo } = getMatchWindow();
  console.log(`\nWindow: ${dateFrom} → ${dateTo}\n`);

  // 1. Get current round
  let currentRound = 17;
  try {
    const pastData = await fetchJson(`/eventspastleague.php?id=${LEAGUE_ID}`);
    const last = (pastData?.events ?? [])[0];
    if (last?.intRound) currentRound = parseInt(last.intRound, 10);
  } catch {}
  console.log(`Current round: ${currentRound}`);

  // 2. Fetch rounds currentRound → +2
  const rawEvents = [];
  const seen = new Set();
  for (let r = currentRound; r <= currentRound + 2; r++) {
    try {
      const data = await fetchJson(`/eventsround.php?id=${LEAGUE_ID}&r=${r}&s=2026`);
      rawEvents.push(...(data?.events ?? []));
      console.log(`  Round ${r}: ${(data?.events ?? []).length} events`);
    } catch (e) {
      console.log(`  Round ${r}: FAILED (${e.message})`);
    }
  }

  // 3. eventsnextleague
  try {
    const d = await fetchJson(`/eventsnextleague.php?id=${LEAGUE_ID}`);
    rawEvents.push(...(d?.events ?? []));
  } catch {}

  // 4. Brazil next match
  try {
    const d = await fetchJson(`/eventsnext.php?id=134496`);
    rawEvents.push(...(d?.events ?? []));
  } catch {}

  // 5. Filter by window and deduplicate
  const results = [];
  for (const e of rawEvents) {
    if (!e?.idEvent || seen.has(e.idEvent)) continue;
    seen.add(e.idEvent);
    const name = (e.strEvent ?? '') + ' ' + (e.strHomeTeam ?? '') + ' ' + (e.strAwayTeam ?? '');
    if (/\bU\d{2}\b/i.test(name) || /women|féminin|femenino/i.test(name)) continue;
    const kickoff = new Date(e.strTimestamp ?? (e.dateEvent ? `${e.dateEvent}T${e.strTime ?? '00:00:00'}` : null));
    if (isNaN(kickoff)) continue;
    if (kickoff >= from && kickoff <= to) {
      results.push({ date: e.dateEvent, time: e.strTime, event: e.strEvent });
    }
  }

  results.sort((a, b) => a.date.localeCompare(b.date) || (a.time ?? '').localeCompare(b.time ?? ''));

  console.log(`\n✅ Matches in window: ${results.length}\n`);
  for (const r of results) {
    console.log(`  ${r.date} ${r.time ?? '??:??'} — ${r.event}`);
  }
}

main().catch(console.error);
