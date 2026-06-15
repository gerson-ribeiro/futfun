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
  // withCors is a pass-through shim — it does NOT set CORS headers.
  // Route handlers must call getCorsHeaders() themselves.
  test('calls the wrapped handler and returns its response unchanged', async () => {
    const expected = NextResponse.json({ hello: 'world' });
    const handler = jest.fn().mockResolvedValue(expected);
    const wrapped = withCors(handler);
    const req = new NextRequest('http://localhost/api/test');

    const result = await wrapped(req);

    expect(handler).toHaveBeenCalledWith(req);
    expect(result).toBe(expected);
  });
});
