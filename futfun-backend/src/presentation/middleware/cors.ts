import { NextRequest, NextResponse } from 'next/server';

export function withCors(handler: (req: NextRequest) => Promise<NextResponse>) {
  return (req: NextRequest) => {
    // CORS headers will be set manually since Next.js API routes don't use express middleware directly
    const response = handler(req);
    return response;
  };
}

export function getCorsHeaders(origin?: string): HeadersInit {
  const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || 'http://localhost:3000').split(',');
  const isAllowed = !origin || allowedOrigins.includes(origin);

  return {
    'Access-Control-Allow-Origin': isAllowed ? origin || '*' : '',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'true',
  };
}
