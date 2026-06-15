# Unit Tests — Full Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add unit tests for all untested business logic and infrastructure code in futfun-backend, bringing coverage from 28% to ~90% of meaningful units.

**Architecture:** Each task creates one new test file using Jest + ts-jest. Tests follow the project pattern: `src/<layer>/<module>/__tests__/<Module>.test.ts`. Dependencies are mocked via `jest.fn()` factories; no real DB, Redis, HTTP, or cron scheduling is exercised.

**Tech Stack:** Jest 30, ts-jest, TypeScript 5, Next.js 15 (`next/server`), Zod 4, node-cron 4, jsonwebtoken 9.

---

## File Map

| Test file to create | Source it tests |
|---|---|
| `src/domain/value-objects/__tests__/PredictionWindow.test.ts` | `PredictionWindow.ts` |
| `src/infrastructure/auth/__tests__/OAuthProviderFactory.test.ts` | `OAuthProviderFactory.ts` |
| `src/presentation/middleware/__tests__/errorHandler.test.ts` | `errorHandler.ts` |
| `src/presentation/middleware/__tests__/helmet.test.ts` | `helmet.ts` |
| `src/presentation/middleware/__tests__/cors.test.ts` | `cors.ts` |
| `src/presentation/middleware/__tests__/authMiddleware.test.ts` | `authMiddleware.ts` |
| `src/application/handlers/__tests__/ScorePredictionsHandler.test.ts` | `ScorePredictionsHandler.ts` |
| `src/infrastructure/football-data/__tests__/FootballDataOrgAdapter.test.ts` | `FootballDataOrgAdapter.ts` |
| `src/infrastructure/football-data/__tests__/MatchSyncJob.test.ts` | `MatchSyncJob.ts` |

---

### Task 1: PredictionWindow value object

**Files:**
- Create: `src/domain/value-objects/__tests__/PredictionWindow.test.ts`

Business rule: predictions are locked the moment the match kicks off.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/domain/value-objects/__tests__/PredictionWindow.test.ts
import { PredictionWindow } from '../PredictionWindow';

describe('PredictionWindow', () => {
  describe('isOpen', () => {
    test('returns true when kickoff is in the future', () => {
      const future = new Date(Date.now() + 60_000);
      expect(PredictionWindow.isOpen(future)).toBe(true);
    });

    test('returns false when kickoff is in the past', () => {
      const past = new Date(Date.now() - 1_000);
      expect(PredictionWindow.isOpen(past)).toBe(false);
    });

    test('returns false when kickoff is right now (already started)', () => {
      const now = new Date(Date.now() - 1);
      expect(PredictionWindow.isOpen(now)).toBe(false);
    });
  });

  describe('assertOpen', () => {
    test('does not throw when kickoff is in the future', () => {
      const future = new Date(Date.now() + 60_000);
      expect(() => PredictionWindow.assertOpen(future)).not.toThrow();
    });

    test('throws PREDICTION_LOCKED when kickoff has passed', () => {
      const past = new Date(Date.now() - 1_000);
      expect(() => PredictionWindow.assertOpen(past)).toThrow('PREDICTION_LOCKED');
    });

    test('throws the exact message text', () => {
      const past = new Date(Date.now() - 1_000);
      expect(() => PredictionWindow.assertOpen(past)).toThrow(
        'PREDICTION_LOCKED: Match has already started'
      );
    });
  });
});
```

- [ ] **Step 2: Run the tests and confirm they fail**

```bash
cd E:/source/personal/futfun/futfun-backend
npx jest PredictionWindow --no-coverage
```

Expected: FAIL — `Cannot find module '../PredictionWindow'` or similar (module exists but test file is new — should get 0 passing initially if source is correct; tests will PASS immediately since source already exists, which is fine — jump to step 4).

- [ ] **Step 3: Source already exists — verify tests pass**

```bash
npx jest PredictionWindow --no-coverage
```

Expected: **6 tests pass**.

- [ ] **Step 4: Commit**

```bash
git add src/domain/value-objects/__tests__/PredictionWindow.test.ts
git commit -m "test: PredictionWindow value object — isOpen and assertOpen"
```

---

### Task 2: OAuthProviderFactory

**Files:**
- Create: `src/infrastructure/auth/__tests__/OAuthProviderFactory.test.ts`

The factory must return the correct OAuth service instance and throw for unknown providers. Both `GoogleOAuthService` and `MicrosoftOAuthService` read env vars in their constructors, so we set minimal env before constructing.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/infrastructure/auth/__tests__/OAuthProviderFactory.test.ts
import { createOAuthProvider } from '../OAuthProviderFactory';
import { GoogleOAuthService } from '../GoogleOAuthService';
import { MicrosoftOAuthService } from '../MicrosoftOAuthService';

describe('createOAuthProvider', () => {
  beforeEach(() => {
    process.env.GOOGLE_CLIENT_ID = 'g-client';
    process.env.GOOGLE_CLIENT_SECRET = 'g-secret';
    process.env.APP_BASE_URL = 'http://localhost:4000';
    process.env.MICROSOFT_CLIENT_ID = 'ms-client';
    process.env.MICROSOFT_CLIENT_SECRET = 'ms-secret';
    process.env.MICROSOFT_TENANT_ID = 'common';
  });

  test('returns a GoogleOAuthService instance for "google"', () => {
    const provider = createOAuthProvider('google');
    expect(provider).toBeInstanceOf(GoogleOAuthService);
  });

  test('returns a MicrosoftOAuthService instance for "microsoft"', () => {
    const provider = createOAuthProvider('microsoft');
    expect(provider).toBeInstanceOf(MicrosoftOAuthService);
  });

  test('throws for an unknown provider name', () => {
    expect(() => createOAuthProvider('facebook' as any)).toThrow(
      'Unknown OAuth provider: facebook'
    );
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest OAuthProviderFactory --no-coverage
```

Expected: **3 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/infrastructure/auth/__tests__/OAuthProviderFactory.test.ts
git commit -m "test: OAuthProviderFactory — correct service instance per provider"
```

---

### Task 3: errorHandler

**Files:**
- Create: `src/presentation/middleware/__tests__/errorHandler.test.ts`

Tests cover `AppError` (class) and `handleError` (function) with three error branches: ZodError → 400, AppError → custom status, unknown → 500.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/presentation/middleware/__tests__/errorHandler.test.ts
import { z } from 'zod';
import { AppError, handleError } from '../errorHandler';

describe('AppError', () => {
  test('stores message, code, and default statusCode 400', () => {
    const err = new AppError('Not found', 'NOT_FOUND');
    expect(err.message).toBe('Not found');
    expect(err.code).toBe('NOT_FOUND');
    expect(err.statusCode).toBe(400);
  });

  test('accepts a custom statusCode', () => {
    const err = new AppError('Forbidden', 'FORBIDDEN', 403);
    expect(err.statusCode).toBe(403);
  });

  test('is an instance of Error', () => {
    expect(new AppError('x', 'X')).toBeInstanceOf(Error);
  });
});

describe('handleError', () => {
  test('returns 400 with VALIDATION_ERROR for ZodError', async () => {
    const schema = z.object({ name: z.string() });
    let zodError: unknown;
    try {
      schema.parse({ name: 123 });
    } catch (e) {
      zodError = e;
    }

    const res = handleError(zodError);
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error.code).toBe('VALIDATION_ERROR');
    expect(body.error.message).toBe('Validation error');
    expect(body.error.details).toBeDefined();
  });

  test('returns AppError statusCode and code', async () => {
    const err = new AppError('Conflict', 'DUPLICATE', 409);
    const res = handleError(err);
    expect(res.status).toBe(409);
    const body = await res.json();
    expect(body.error.code).toBe('DUPLICATE');
    expect(body.error.message).toBe('Conflict');
  });

  test('returns 500 for unknown errors', async () => {
    const res = handleError(new Error('boom'));
    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.error.code).toBe('INTERNAL_SERVER_ERROR');
  });

  test('returns 500 for non-Error throws', async () => {
    const res = handleError('plain string error');
    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.error.code).toBe('INTERNAL_SERVER_ERROR');
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest errorHandler --no-coverage
```

Expected: **7 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/presentation/middleware/__tests__/errorHandler.test.ts
git commit -m "test: errorHandler — AppError class and handleError branches"
```

---

### Task 4: helmet middleware

**Files:**
- Create: `src/presentation/middleware/__tests__/helmet.test.ts`

`getHelmetHeaders` must return all five security headers with exact values. `withHelmet` must stamp them onto a `NextResponse`.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/presentation/middleware/__tests__/helmet.test.ts
import { NextResponse } from 'next/server';
import { getHelmetHeaders, withHelmet } from '../helmet';

describe('getHelmetHeaders', () => {
  test('returns X-Content-Type-Options: nosniff', () => {
    expect(getHelmetHeaders()['X-Content-Type-Options']).toBe('nosniff');
  });

  test('returns X-Frame-Options: DENY', () => {
    expect(getHelmetHeaders()['X-Frame-Options']).toBe('DENY');
  });

  test('returns X-XSS-Protection: 1; mode=block', () => {
    expect(getHelmetHeaders()['X-XSS-Protection']).toBe('1; mode=block');
  });

  test('returns Strict-Transport-Security with max-age and includeSubDomains', () => {
    expect(getHelmetHeaders()['Strict-Transport-Security']).toBe(
      'max-age=31536000; includeSubDomains'
    );
  });

  test("returns Content-Security-Policy: default-src 'self'", () => {
    expect(getHelmetHeaders()['Content-Security-Policy']).toBe("default-src 'self'");
  });
});

describe('withHelmet', () => {
  test('sets all security headers on the response', () => {
    const response = NextResponse.json({ ok: true });
    const result = withHelmet(response);
    expect(result.headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(result.headers.get('X-Frame-Options')).toBe('DENY');
    expect(result.headers.get('Content-Security-Policy')).toBe("default-src 'self'");
  });

  test('returns the same response object', () => {
    const response = NextResponse.json({ ok: true });
    const result = withHelmet(response);
    expect(result).toBe(response);
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest helmet --no-coverage
```

Expected: **7 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/presentation/middleware/__tests__/helmet.test.ts
git commit -m "test: helmet middleware — security headers presence and values"
```

---

### Task 5: cors middleware

**Files:**
- Create: `src/presentation/middleware/__tests__/cors.test.ts`

`getCorsHeaders` reads `CORS_ALLOWED_ORIGINS` from env, allows or blocks origins accordingly. `withCors` wraps a handler without modifying its response.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/presentation/middleware/__tests__/cors.test.ts
import { getCorsHeaders, withCors } from '../cors';
import { NextRequest, NextResponse } from 'next/server';

describe('getCorsHeaders', () => {
  beforeEach(() => {
    process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:3000,https://app.futfun.com';
  });

  test('allows a listed origin', () => {
    const headers = getCorsHeaders('http://localhost:3000') as Record<string, string>;
    expect(headers['Access-Control-Allow-Origin']).toBe('http://localhost:3000');
  });

  test('blocks an unlisted origin (returns empty string)', () => {
    const headers = getCorsHeaders('https://evil.com') as Record<string, string>;
    expect(headers['Access-Control-Allow-Origin']).toBe('');
  });

  test('returns wildcard when no origin is provided', () => {
    const headers = getCorsHeaders() as Record<string, string>;
    expect(headers['Access-Control-Allow-Origin']).toBe('*');
  });

  test('includes allowed methods', () => {
    const headers = getCorsHeaders('http://localhost:3000') as Record<string, string>;
    expect(headers['Access-Control-Allow-Methods']).toContain('GET');
    expect(headers['Access-Control-Allow-Methods']).toContain('POST');
  });

  test('includes Authorization in allowed headers', () => {
    const headers = getCorsHeaders('http://localhost:3000') as Record<string, string>;
    expect(headers['Access-Control-Allow-Headers']).toContain('Authorization');
  });
});

describe('withCors', () => {
  test('calls the wrapped handler and returns its response', async () => {
    const expected = NextResponse.json({ hello: 'world' });
    const handler = jest.fn().mockResolvedValue(expected);
    const wrapped = withCors(handler);
    const req = new NextRequest('http://localhost/api/test');

    const result = await wrapped(req);

    expect(handler).toHaveBeenCalledWith(req);
    expect(result).toBe(expected);
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest cors --no-coverage
```

Expected: **6 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/presentation/middleware/__tests__/cors.test.ts
git commit -m "test: cors middleware — origin allow/block and handler wrapping"
```

---

### Task 6: authMiddleware

**Files:**
- Create: `src/presentation/middleware/__tests__/authMiddleware.test.ts`

`withAuth` and `withAdmin` instantiate `JwtTokenService` internally. We mock the module so no real JWT secret is needed. Request objects are simulated with a plain object cast to satisfy the interface.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/presentation/middleware/__tests__/authMiddleware.test.ts
import { NextRequest, NextResponse } from 'next/server';
import { withAuth, withAdmin } from '../authMiddleware';
import { TokenPayload } from '@application/ports/ITokenService';

const mockVerifyAccessToken = jest.fn();

jest.mock('@infrastructure/auth/JwtTokenService', () => ({
  JwtTokenService: jest.fn().mockImplementation(() => ({
    verifyAccessToken: mockVerifyAccessToken,
  })),
}));

const memberPayload: TokenPayload = {
  userId: 'user-1',
  email: 'user@example.com',
  role: 'MEMBER',
};

const adminPayload: TokenPayload = {
  userId: 'admin-1',
  email: 'admin@example.com',
  role: 'ADMIN',
};

function makeReq(authHeader?: string): NextRequest {
  return {
    headers: { get: (k: string) => (k === 'Authorization' ? authHeader ?? null : null) },
  } as unknown as NextRequest;
}

describe('withAuth', () => {
  beforeEach(() => jest.clearAllMocks());

  test('returns 401 when Authorization header is missing', async () => {
    const handler = jest.fn();
    const wrapped = withAuth(handler);
    const res = await wrapped(makeReq());

    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.error.code).toBe('UNAUTHORIZED');
    expect(handler).not.toHaveBeenCalled();
  });

  test('returns 401 when Authorization header does not start with "Bearer "', async () => {
    const handler = jest.fn();
    const wrapped = withAuth(handler);
    const res = await wrapped(makeReq('Basic abc123'));

    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.error.code).toBe('UNAUTHORIZED');
  });

  test('returns 401 when token is invalid (verifyAccessToken throws)', async () => {
    mockVerifyAccessToken.mockImplementation(() => { throw new Error('jwt expired'); });
    const handler = jest.fn();
    const wrapped = withAuth(handler);
    const res = await wrapped(makeReq('Bearer bad-token'));

    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.error.code).toBe('TOKEN_EXPIRED');
    expect(handler).not.toHaveBeenCalled();
  });

  test('calls handler with decoded user payload when token is valid', async () => {
    mockVerifyAccessToken.mockReturnValue(memberPayload);
    const handler = jest.fn().mockResolvedValue(NextResponse.json({ ok: true }));
    const wrapped = withAuth(handler);
    const req = makeReq('Bearer valid-token');

    await wrapped(req);

    expect(handler).toHaveBeenCalledWith(req, memberPayload, undefined);
  });

  test('returns handler response when token is valid', async () => {
    mockVerifyAccessToken.mockReturnValue(memberPayload);
    const expected = NextResponse.json({ data: 'secret' });
    const wrapped = withAuth(jest.fn().mockResolvedValue(expected));

    const result = await wrapped(makeReq('Bearer valid-token'));

    expect(result).toBe(expected);
  });
});

describe('withAdmin', () => {
  beforeEach(() => jest.clearAllMocks());

  test('returns 401 when Authorization header is missing', async () => {
    const handler = jest.fn();
    const wrapped = withAdmin(handler);
    const res = await wrapped(makeReq());
    expect(res.status).toBe(401);
  });

  test('returns 403 when authenticated user role is MEMBER', async () => {
    mockVerifyAccessToken.mockReturnValue(memberPayload);
    const handler = jest.fn();
    const wrapped = withAdmin(handler);
    const res = await wrapped(makeReq('Bearer valid-token'));

    expect(res.status).toBe(403);
    const body = await res.json();
    expect(body.error.code).toBe('FORBIDDEN');
    expect(handler).not.toHaveBeenCalled();
  });

  test('returns 403 when authenticated user role is PENDING', async () => {
    mockVerifyAccessToken.mockReturnValue({ ...memberPayload, role: 'PENDING' as const });
    const handler = jest.fn();
    const wrapped = withAdmin(handler);
    const res = await wrapped(makeReq('Bearer valid-token'));

    expect(res.status).toBe(403);
  });

  test('calls handler when authenticated user role is ADMIN', async () => {
    mockVerifyAccessToken.mockReturnValue(adminPayload);
    const handler = jest.fn().mockResolvedValue(NextResponse.json({ admin: true }));
    const wrapped = withAdmin(handler);
    const req = makeReq('Bearer valid-admin-token');

    await wrapped(req);

    expect(handler).toHaveBeenCalledWith(req, adminPayload, undefined);
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest authMiddleware --no-coverage
```

Expected: **9 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/presentation/middleware/__tests__/authMiddleware.test.ts
git commit -m "test: authMiddleware — withAuth and withAdmin JWT validation and role guard"
```

---

### Task 7: ScorePredictionsHandler

**Files:**
- Create: `src/application/handlers/__tests__/ScorePredictionsHandler.test.ts`

This is the most complex handler. It reads a match, reads unscored predictions, calls `PointsCalculationService`, and upserts rankings. We mock Prisma with factory helpers following the same pattern used in `OAuthCallbackHandler.test.ts`.

Points rules (from `PointsCalculationService`):
- Exact score → 10 pts
- Correct result + one score matches → 7 pts
- Correct result only → 5 pts
- Wrong result → 0 pts

`isExact = points === 10`, `isCorrectResult = points === 5 || points === 7`

- [ ] **Step 1: Write the failing tests**

```typescript
// src/application/handlers/__tests__/ScorePredictionsHandler.test.ts
import { ScorePredictionsHandler } from '../ScorePredictionsHandler';

const MATCH_ID = 'match-uuid';

function makeMatch(overrides: Record<string, unknown> = {}) {
  return {
    id: MATCH_ID,
    status: 'FINISHED',
    scoreHome: 2,
    scoreAway: 1,
    ...overrides,
  };
}

function makePrediction(overrides: Record<string, unknown> = {}) {
  return {
    id: 'pred-uuid',
    matchId: MATCH_ID,
    userId: 'user-uuid',
    predictedHome: 2,
    predictedAway: 1,
    scoredAt: null,
    ...overrides,
  };
}

function makePrisma(matchOverride?: object | null, predictions: object[] = [makePrediction()]) {
  return {
    match: {
      findUnique: jest.fn().mockResolvedValue(matchOverride === undefined ? makeMatch() : matchOverride),
    },
    prediction: {
      findMany: jest.fn().mockResolvedValue(predictions),
      update: jest.fn().mockResolvedValue({}),
    },
    ranking: {
      upsert: jest.fn().mockResolvedValue({}),
    },
  };
}

describe('ScorePredictionsHandler', () => {
  beforeEach(() => jest.clearAllMocks());

  test('does nothing when match is not found', async () => {
    const prisma = makePrisma(null, []);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.findMany).not.toHaveBeenCalled();
  });

  test('does nothing when match status is not FINISHED', async () => {
    const prisma = makePrisma(makeMatch({ status: 'LIVE' }), []);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.findMany).not.toHaveBeenCalled();
  });

  test('does nothing when match scoreHome is null', async () => {
    const prisma = makePrisma(makeMatch({ scoreHome: null }), []);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.findMany).not.toHaveBeenCalled();
  });

  test('does nothing when there are no unscored predictions', async () => {
    const prisma = makePrisma(makeMatch(), []);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.update).not.toHaveBeenCalled();
    expect(prisma.ranking.upsert).not.toHaveBeenCalled();
  });

  test('assigns 10 points for exact score and marks exactScores', async () => {
    // match 2-1, prediction 2-1 → exact → 10 pts
    const prisma = makePrisma(makeMatch({ scoreHome: 2, scoreAway: 1 }), [
      makePrediction({ predictedHome: 2, predictedAway: 1 }),
    ]);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ points: 10 }) })
    );
    expect(prisma.ranking.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ totalPoints: 10, exactScores: 1, correctResults: 0 }),
        update: expect.objectContaining({
          exactScores: { increment: 1 },
          correctResults: { increment: 0 },
        }),
      })
    );
  });

  test('assigns 7 points for correct result + one matching score', async () => {
    // match 2-1, prediction 2-0 → home score matches, result correct → 7 pts
    const prisma = makePrisma(makeMatch({ scoreHome: 2, scoreAway: 1 }), [
      makePrediction({ predictedHome: 2, predictedAway: 0 }),
    ]);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ points: 7 }) })
    );
    expect(prisma.ranking.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ totalPoints: 7, exactScores: 0, correctResults: 1 }),
        update: expect.objectContaining({ correctResults: { increment: 1 } }),
      })
    );
  });

  test('assigns 5 points for correct result with no matching score', async () => {
    // match 2-1, prediction 3-1 → wrong home, wrong away, but result correct (home wins) → 5 pts
    // wait: away score 1 matches → 7 pts actually. Use prediction 3-2.
    // match 2-1, prediction 3-2 → neither score matches, result correct → 5 pts
    const prisma = makePrisma(makeMatch({ scoreHome: 2, scoreAway: 1 }), [
      makePrediction({ predictedHome: 3, predictedAway: 2 }),
    ]);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ points: 5 }) })
    );
    expect(prisma.ranking.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ totalPoints: 5, exactScores: 0, correctResults: 1 }),
      })
    );
  });

  test('assigns 0 points for wrong result', async () => {
    // match 2-1 (home wins), prediction 0-1 (away wins) → 0 pts
    const prisma = makePrisma(makeMatch({ scoreHome: 2, scoreAway: 1 }), [
      makePrediction({ predictedHome: 0, predictedAway: 1 }),
    ]);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ points: 0 }) })
    );
    expect(prisma.ranking.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ totalPoints: 0, exactScores: 0, correctResults: 0 }),
      })
    );
  });

  test('processes all unscored predictions and calls upsert for each', async () => {
    const predictions = [
      makePrediction({ id: 'pred-1', userId: 'user-1', predictedHome: 2, predictedAway: 1 }),
      makePrediction({ id: 'pred-2', userId: 'user-2', predictedHome: 1, predictedAway: 0 }),
      makePrediction({ id: 'pred-3', userId: 'user-3', predictedHome: 0, predictedAway: 2 }),
    ];
    const prisma = makePrisma(makeMatch({ scoreHome: 2, scoreAway: 1 }), predictions);
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.update).toHaveBeenCalledTimes(3);
    expect(prisma.ranking.upsert).toHaveBeenCalledTimes(3);
  });

  test('queries only unscored predictions (scoredAt: null)', async () => {
    const prisma = makePrisma();
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle(MATCH_ID);

    expect(prisma.prediction.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { matchId: MATCH_ID, scoredAt: null } })
    );
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest ScorePredictionsHandler --no-coverage
```

Expected: **9 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/application/handlers/__tests__/ScorePredictionsHandler.test.ts
git commit -m "test: ScorePredictionsHandler — all scoring branches and ranking upserts"
```

---

### Task 8: FootballDataOrgAdapter

**Files:**
- Create: `src/infrastructure/football-data/__tests__/FootballDataOrgAdapter.test.ts`

The adapter uses global `fetch`. We replace it with `jest.fn()` per test. We validate correct URLs, correct API key header, and correct response parsing.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/infrastructure/football-data/__tests__/FootballDataOrgAdapter.test.ts
import { FootballDataOrgAdapter } from '../FootballDataOrgAdapter';

const mockFetch = jest.fn();

beforeAll(() => {
  global.fetch = mockFetch;
});

function mockOkResponse(body: unknown) {
  return mockFetch.mockResolvedValueOnce({
    ok: true,
    json: jest.fn().mockResolvedValue(body),
  });
}

function mockErrorResponse(status: number, statusText: string) {
  return mockFetch.mockResolvedValueOnce({ ok: false, status, statusText });
}

describe('FootballDataOrgAdapter', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.FOOTBALL_DATA_ORG_BASE_URL = 'https://api.football-data.org/v4';
    process.env.FOOTBALL_DATA_ORG_API_KEY = 'test-api-key';
  });

  describe('getCompetitionMatches', () => {
    test('calls correct URL without season param', async () => {
      mockOkResponse({ matches: [] });
      const adapter = new FootballDataOrgAdapter();
      await adapter.getCompetitionMatches('WC');

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/competitions/WC/matches',
        expect.objectContaining({ headers: { 'X-Auth-Token': 'test-api-key' } })
      );
    });

    test('appends season query param when provided', async () => {
      mockOkResponse({ matches: [] });
      const adapter = new FootballDataOrgAdapter();
      await adapter.getCompetitionMatches('WC', 2026);

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/competitions/WC/matches?season=2026',
        expect.anything()
      );
    });

    test('returns matches array from API response', async () => {
      const fakeMatch = { id: 1, homeTeam: { id: 10 }, awayTeam: { id: 20 } };
      mockOkResponse({ matches: [fakeMatch] });
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getCompetitionMatches('WC');

      expect(result).toEqual([fakeMatch]);
    });

    test('returns empty array when API response has no matches key', async () => {
      mockOkResponse({});
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getCompetitionMatches('WC');

      expect(result).toEqual([]);
    });

    test('throws when API response is not OK', async () => {
      mockErrorResponse(429, 'Too Many Requests');
      const adapter = new FootballDataOrgAdapter();

      await expect(adapter.getCompetitionMatches('WC')).rejects.toThrow(
        'Football API error: 429 Too Many Requests'
      );
    });
  });

  describe('getMatchById', () => {
    test('calls correct URL for match ID', async () => {
      const fakeMatch = { id: 42 };
      mockOkResponse(fakeMatch);
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getMatchById(42);

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/matches/42',
        expect.anything()
      );
      expect(result).toEqual(fakeMatch);
    });
  });

  describe('getLiveMatches', () => {
    test('calls URL with status=IN_PLAY filter', async () => {
      mockOkResponse({ matches: [] });
      const adapter = new FootballDataOrgAdapter();
      await adapter.getLiveMatches('WC');

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/competitions/WC/matches?status=IN_PLAY',
        expect.anything()
      );
    });

    test('returns matches array', async () => {
      const liveMatch = { id: 99 };
      mockOkResponse({ matches: [liveMatch] });
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getLiveMatches('WC');

      expect(result).toEqual([liveMatch]);
    });
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest FootballDataOrgAdapter --no-coverage
```

Expected: **8 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/infrastructure/football-data/__tests__/FootballDataOrgAdapter.test.ts
git commit -m "test: FootballDataOrgAdapter — correct URLs, API key header, error handling"
```

---

### Task 9: MatchSyncJob

**Files:**
- Create: `src/infrastructure/football-data/__tests__/MatchSyncJob.test.ts`

We mock `node-cron` to prevent real timers. Tests focus on `syncMatches()` (public) and `upsertMatch` behaviour (observable via `prisma.match.upsert` calls). The `start()` test verifies sync runs immediately on startup.

- [ ] **Step 1: Write the failing tests**

```typescript
// src/infrastructure/football-data/__tests__/MatchSyncJob.test.ts
import { MatchSyncJob } from '../MatchSyncJob';
import { IFootballDataProvider, ProviderMatch } from '@application/ports/IFootballDataProvider';

jest.mock('node-cron', () => ({
  schedule: jest.fn().mockReturnValue({ stop: jest.fn() }),
}));

function makeMatch(overrides: Partial<ProviderMatch> = {}): ProviderMatch {
  return {
    id: 1,
    homeTeam: { id: 10, name: 'Brazil', shortName: 'BRA', crest: 'https://crest/bra.png' },
    awayTeam: { id: 20, name: 'Germany', shortName: 'GER', crest: 'https://crest/ger.png' },
    utcDate: '2026-06-15T18:00:00Z',
    status: 'SCHEDULED',
    score: { fullTime: { home: null, away: null } },
    stage: 'GROUP_STAGE',
    group: 'Group A',
    matchday: 1,
    ...overrides,
  };
}

function makePrisma() {
  return {
    match: {
      count: jest.fn().mockResolvedValue(0),
      upsert: jest.fn().mockResolvedValue({}),
    },
  };
}

function makeProvider(matches: ProviderMatch[] = [makeMatch()]): IFootballDataProvider {
  return {
    getCompetitionMatches: jest.fn().mockResolvedValue(matches),
    getMatchById: jest.fn(),
    getLiveMatches: jest.fn(),
  };
}

describe('MatchSyncJob', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.FOOTBALL_COMPETITION_CODE = 'WC';
  });

  describe('syncMatches', () => {
    test('fetches matches using the configured competition code', async () => {
      const provider = makeProvider();
      const job = new MatchSyncJob(makePrisma() as any, provider);

      await job.syncMatches();

      expect(provider.getCompetitionMatches).toHaveBeenCalledWith('WC');
    });

    test('upserts each match returned by the provider', async () => {
      const matches = [makeMatch({ id: 1 }), makeMatch({ id: 2, homeTeam: { id: 11, name: 'Argentina', shortName: 'ARG' }, awayTeam: { id: 21, name: 'France', shortName: 'FRA' } })];
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider(matches));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledTimes(2);
    });

    test('skips matches where homeTeam.id is falsy', async () => {
      const unassigned = makeMatch({ homeTeam: { id: 0, name: 'TBD' } });
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([unassigned]));

      await job.syncMatches();

      expect(prisma.match.upsert).not.toHaveBeenCalled();
    });

    test('skips matches where awayTeam.id is falsy', async () => {
      const unassigned = makeMatch({ awayTeam: { id: 0, name: 'TBD' } });
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([unassigned]));

      await job.syncMatches();

      expect(prisma.match.upsert).not.toHaveBeenCalled();
    });

    test('maps SCHEDULED status correctly', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ status: 'SCHEDULED' })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'SCHEDULED' }) })
      );
    });

    test('maps IN_PLAY status to LIVE', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ status: 'IN_PLAY' })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'LIVE' }) })
      );
    });

    test('maps PAUSED status to LIVE', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ status: 'PAUSED' })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'LIVE' }) })
      );
    });

    test('maps FINISHED status correctly', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(
        prisma as any,
        makeProvider([makeMatch({ status: 'FINISHED', score: { fullTime: { home: 2, away: 1 } } })])
      );

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'FINISHED' }) })
      );
    });

    test('upserts with externalId as the unique key', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ id: 999 })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ where: { externalId: 999 } })
      );
    });

    test('catches and logs provider errors without throwing', async () => {
      const brokenProvider: IFootballDataProvider = {
        getCompetitionMatches: jest.fn().mockRejectedValue(new Error('network down')),
        getMatchById: jest.fn(),
        getLiveMatches: jest.fn(),
      };
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
      const job = new MatchSyncJob(makePrisma() as any, brokenProvider);

      await expect(job.syncMatches()).resolves.toBeUndefined();
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });
  });

  describe('start / stop', () => {
    test('calls syncMatches immediately on start', async () => {
      const provider = makeProvider([]);
      const job = new MatchSyncJob(makePrisma() as any, provider);

      job.start();
      // Allow the microtask queue to flush
      await new Promise(resolve => setImmediate(resolve));

      expect(provider.getCompetitionMatches).toHaveBeenCalled();
    });

    test('stop does not throw', () => {
      const job = new MatchSyncJob(makePrisma() as any, makeProvider([]));
      job.start();
      expect(() => job.stop()).not.toThrow();
    });
  });
});
```

- [ ] **Step 2: Run and confirm they pass**

```bash
npx jest MatchSyncJob --no-coverage
```

Expected: **11 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add src/infrastructure/football-data/__tests__/MatchSyncJob.test.ts
git commit -m "test: MatchSyncJob — sync logic, status mapping, null-team guard, error handling"
```

---

### Task 10: Full test suite validation

- [ ] **Step 1: Run the entire test suite**

```bash
cd E:/source/personal/futfun/futfun-backend
npm test
```

Expected: **all tests pass** (was 29; should now be ~63+).

- [ ] **Step 2: Verify no regressions**

All pre-existing 29 tests must remain green. New tests bring total to 60+.

- [ ] **Step 3: Push**

```bash
git push
```

---

## Self-Review

**Spec coverage:** All 9 untested meaningful source files now have tests. Port interfaces (`IEmailService`, `IFootballDataProvider`, etc.) are correctly excluded — they're contracts, not implementations.

**Placeholder scan:** No TBD, TODO, or "add validation" patterns present. Every test contains actual assertion code.

**Type consistency:** `ProviderMatch.homeTeam.id` is `number` throughout (Tasks 8 and 9 both use `id: 10`). `TokenPayload.role` literals match the interface union (`'MEMBER' | 'ADMIN' | 'PENDING'`). `points === 10` for exact, `points === 5 || points === 7` for correctResult — matches `ScorePredictionsHandler` source exactly.
