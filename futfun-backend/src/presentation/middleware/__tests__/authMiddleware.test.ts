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
