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
