import { NextResponse } from 'next/server';

export function getHelmetHeaders(): HeadersInit {
  return {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy': "default-src 'self'",
  };
}

export function withHelmet(response: NextResponse): NextResponse {
  Object.entries(getHelmetHeaders()).forEach(([key, value]) => {
    response.headers.set(key, value);
  });
  return response;
}
