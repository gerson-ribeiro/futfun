import { NextRequest, NextResponse } from 'next/server';

const CORS_HEADERS = {
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Credentials': 'true',
  'Access-Control-Max-Age': '86400',
};

function getAllowedOrigin(origin: string | null): string | null {
  if (!origin) return null;

  // Em desenvolvimento, permite qualquer origem localhost/127.0.0.1
  if (process.env.NODE_ENV !== 'production') {
    if (origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1')) {
      return origin;
    }
  }

  const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  return allowedOrigins.includes(origin) ? origin : null;
}

export function middleware(request: NextRequest) {
  const origin = request.headers.get('origin');
  const allowedOrigin = getAllowedOrigin(origin);

  // Preflight OPTIONS — responde imediatamente com os headers CORS
  if (request.method === 'OPTIONS') {
    return new NextResponse(null, {
      status: 204,
      headers: {
        ...(allowedOrigin ? { 'Access-Control-Allow-Origin': allowedOrigin } : {}),
        ...CORS_HEADERS,
      },
    });
  }

  // Para todos os outros métodos, deixa o request passar e injeta os headers CORS na resposta
  const response = NextResponse.next();
  if (allowedOrigin) {
    response.headers.set('Access-Control-Allow-Origin', allowedOrigin);
    Object.entries(CORS_HEADERS).forEach(([key, value]) => {
      response.headers.set(key, value);
    });
  }
  return response;
}

export const config = {
  matcher: '/api/:path*',
};
