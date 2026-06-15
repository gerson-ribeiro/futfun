// app/api/image-proxy/route.ts
//
// Server-side image proxy for team crests.
// Needed because external CDNs (crests.football-data.org, thesportsdb.com)
// do not return CORS headers, so Flutter web cannot fetch them directly.
// This endpoint fetches the image server-side and re-serves it with
// Access-Control-Allow-Origin: * so the browser accepts it.

import { NextRequest, NextResponse } from 'next/server';

const ALLOWED_HOSTS = new Set([
  'crests.football-data.org',
  'www.thesportsdb.com',
  'r2.thesportsdb.com',  // TheSportsDB CDN (used for team badges since 2024)
  'media.api-sports.io',
]);

export async function GET(req: NextRequest) {
  const url = req.nextUrl.searchParams.get('url');

  if (!url) {
    return new NextResponse('Missing url parameter', { status: 400 });
  }

  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return new NextResponse('Invalid URL', { status: 400 });
  }

  if (!ALLOWED_HOSTS.has(parsed.hostname)) {
    return new NextResponse('URL not allowed', { status: 403 });
  }

  let upstream: Response;
  try {
    upstream = await fetch(url, { signal: AbortSignal.timeout(10_000) });
  } catch {
    return new NextResponse('Failed to fetch image', { status: 502 });
  }

  if (!upstream.ok) {
    return new NextResponse('Upstream error', { status: 502 });
  }

  const contentType = upstream.headers.get('content-type') ?? 'application/octet-stream';
  const buffer = await upstream.arrayBuffer();

  return new NextResponse(buffer, {
    headers: {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=86400',
    },
  });
}
