# Spec: Matches & Predictions Redesign

**Date:** 2026-06-08  
**Status:** Approved

---

## Overview

Three coordinated changes to improve the matches browsing and prediction flow:

1. Expand the matches screen to show 7 days of upcoming games (was 3), with load-more to extend further
2. Remove predicted games from the matches screen — they live exclusively on the predictions screen
3. Lock card design for games not yet open for betting, with a flag (`hasPrediction`) returned by the backend to avoid a second API call

The betting window stays the same: from 1 day before kickoff until kickoff time.

---

## Decision Log

- **Card style for locked games:** Option A — full card with team flags, disabled inputs, amber badge "Abre em X dias", grey "Bloqueado" button
- **Predictions screen layout:** Option C — only predicted games shown, no extra section for available games
- **Load more strategy:** Option 1 — `daysAhead` parameter on existing `/api/upcoming-matches` endpoint
- **Filtering predicted games from matches screen:** backend adds `hasPrediction: boolean` per match (join with user's predictions), frontend hides where true — one API call, business logic on backend
- **No DB storage of unpredicted matches:** matches are only persisted when a prediction is made; browsing always uses live provider data

---

## Tela de Jogos (Matches Screen)

### Default window
`d0` to `d+7`. Was `d-1` to `d+3`.

### Load more
Each click extends the window:
- 1st click: `daysAhead=14`
- 2nd click: `daysAhead=21`
- 3rd click: `daysAhead=999` (all available)
- After 3rd click, the button is hidden

### Card states

| Condition | Card behaviour |
|---|---|
| `hasPrediction: true` | Hidden — not rendered |
| `hasPrediction: false` + `kickoffTime < now` | Hidden — game already started, too late to bet |
| `hasPrediction: false` + kickoff within d+1 | Full card: team flags, score inputs enabled, "Palpitar" button active |
| `hasPrediction: false` + kickoff beyond d+1 | Full card: team flags, inputs disabled, amber badge "Abre em X dias", grey "Bloqueado" button |

### No second API call
The matches screen does not call `/api/predictions` independently. The `hasPrediction` flag comes embedded in each match object from `/api/upcoming-matches`.

---

## Tela de Palpites (Predictions Screen)

Shows only games where the user has made a prediction. Source: database (existing `/api/predictions` endpoint, unchanged).

### Card states

| Condition | Behaviour |
|---|---|
| `SCHEDULED` + kickoff > now + kickoff ≤ d+1 | Prediction shown + **"Editar"** button → opens existing edit dialog |
| `SCHEDULED` + kickoff > now + kickoff > d+1 | Prediction shown, no edit button (window not open yet) |
| `FINISHED` | Prediction + actual score + points badge |

No extra section for "available games without prediction" — user goes to matches screen for that.

---

## Backend Changes

### `GET /api/upcoming-matches`

**New query param:** `daysAhead` (integer, default=7, no hard max — 999 means "all available from provider")

**Window change:** `dateFrom = today 00:00 UTC`, `dateTo = today + daysAhead days 23:59 UTC`  
(was: `dateFrom = yesterday`, `dateTo = today + 3 days`)

**New field per match:** `hasPrediction: boolean`  
After fetching matches from the provider, the handler queries the DB for prediction rows matching `{ userId, matchId IN [fetched match IDs] }` and sets the flag. This is one extra DB query per request, not one per match.

**Provider data availability:** if the provider has no data beyond a certain date, the endpoint returns whatever is available without error. The frontend shows "Sem mais jogos disponíveis" when the load-more response returns an empty list.

**No match persistence:** the endpoint never writes to the `Match` table. Only `/api/predictions` (POST) does that.

### `POST /api/predictions`
Unchanged. Continues to upsert the match to the DB on first prediction, then saves the prediction row.

### `PredictionWindow.isOpen()`
Unchanged. Current logic (`now < kickoffTime && kickoffTime ≤ tomorrow end-of-day UTC`) already matches the "1 day before kickoff until kickoff" rule.

---

## What Does Not Change

- Ranking screen
- Dashboard screen
- Admin screens (users, invites, competitions)
- Scoring rules and cron jobs
- Auth / invite system
- `PredictionWindow` logic
- `/api/predictions` GET and PUT endpoints

---

## Out of Scope (discussed, deferred)

- **Per-competition ranking:** user wants separate rankings per competition instead of a single global ranking. To be designed in a separate spec.
