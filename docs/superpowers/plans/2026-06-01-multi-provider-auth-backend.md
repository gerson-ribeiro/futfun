# Multi-Provider Auth + Invite System — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir Azure AD-only auth por Google + Microsoft OAuth com sistema de convites, roles de usuário (ADMIN/MEMBER/PENDING) e envio de emails via Resend.

**Architecture:** Callback OAuth unificado em `/api/auth/callback?provider=google|microsoft` usando a interface `IOAuthProvider`. Um `OAuthCallbackHandler` centraliza a lógica de criação de usuário, detecção de convite e emissão de JWT com role. Admin endpoints protegidos por `withAdmin` middleware.

**Tech Stack:** Next.js 15, TypeScript, Prisma + PostgreSQL, Redis, `google-auth-library`, `@azure/msal-node` (mantido), `resend`, `jsonwebtoken`, `uuid`

> **Nota de arquitetura — Mobile OAuth Flow:** O Flutter abre a URL de OAuth em browser externo via `url_launcher`. O backend recebe o callback do Google/Microsoft e **não pode retornar JSON** (o browser não repassa para o app). Em vez disso, o callback redireciona para um deep link: `futfun://auth?accessToken=xxx&refreshToken=xxx&role=MEMBER&...`. O Flutter captura esse deep link via `app_links` e atualiza o estado de auth. Ver Task 11 (callback route) e Task 15 (.env.example).

---

## Mapa de Arquivos

### Novos
- `src/application/ports/IOAuthProvider.ts`
- `src/application/ports/IEmailService.ts`
- `src/application/handlers/OAuthCallbackHandler.ts`
- `src/application/handlers/CreateInviteHandler.ts`
- `src/infrastructure/auth/GoogleOAuthService.ts`
- `src/infrastructure/auth/OAuthProviderFactory.ts`
- `src/infrastructure/auth/__tests__/GoogleOAuthService.test.ts`
- `src/infrastructure/auth/__tests__/OAuthCallbackHandler.test.ts`
- `src/infrastructure/email/ResendEmailService.ts`
- `src/infrastructure/email/__tests__/ResendEmailService.test.ts`
- `app/api/auth/google/login/route.ts`
- `app/api/auth/callback/route.ts`
- `app/api/invites/[token]/route.ts`
- `app/api/admin/invites/route.ts`
- `app/api/admin/invites/[id]/route.ts`
- `app/api/admin/users/route.ts`
- `app/api/admin/users/[id]/role/route.ts`
- `app/api/admin/users/[id]/route.ts`

### Modificados
- `prisma/schema.prisma`
- `src/application/ports/ITokenService.ts`
- `src/infrastructure/auth/JwtTokenService.ts`
- `src/infrastructure/auth/__tests__/JwtTokenService.test.ts`
- `src/infrastructure/auth/MicrosoftOAuthService.ts`
- `src/infrastructure/auth/__tests__/MicrosoftOAuthService.test.ts`
- `src/infrastructure/container/container.ts`
- `src/presentation/middleware/authMiddleware.ts`
- `app/api/auth/microsoft/login/route.ts`
- `app/api/auth/refresh/route.ts`
- `package.json`

### Deletados
- `app/api/auth/microsoft/callback/route.ts`
- `app/api/auth/setup-password/route.ts`
- `app/api/auth/verify-password/route.ts`
- `src/application/ports/IMicrosoftOAuthService.ts`

---

## Task 1: Instalar dependências e remover obsoletas

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Instalar novas dependências**

```bash
cd E:/source/personal/futfun-backend
npm install resend google-auth-library
npm uninstall bcryptjs
npm uninstall @types/bcryptjs
```

- [ ] **Step 2: Verificar package.json**

`dependencies` deve conter `resend` e `google-auth-library`. Não deve mais conter `bcryptjs`.

- [ ] **Step 3: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore: add resend + google-auth-library, remove bcryptjs"
```

---

## Task 2: Migração do schema Prisma

**Files:**
- Modify: `prisma/schema.prisma`

- [ ] **Step 1: Atualizar schema.prisma**

Substituir o conteúdo do model `User` e adicionar o enum `UserRole` e o model `Invite`:

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
}

enum UserRole {
  PENDING
  MEMBER
  ADMIN
}

model User {
  id            String      @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  provider      String
  providerId    String
  email         String      @unique
  displayName   String
  role          UserRole    @default(PENDING)
  createdAt     DateTime    @default(now())
  lastLoginAt   DateTime    @default(now())

  predictions      Prediction[]
  ranking          Ranking?
  rankingHistories RankingHistory[]
  sentInvites      Invite[]

  @@unique([provider, providerId])
  @@map("users")
}

model Invite {
  id          String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  email       String
  token       String    @unique
  expiresAt   DateTime
  usedAt      DateTime?
  createdBy   String    @db.Uuid
  createdAt   DateTime  @default(now())

  creator     User      @relation(fields: [createdBy], references: [id])

  @@index([token])
  @@index([email])
  @@map("invites")
}

// Manter os outros models (Match, Prediction, Ranking, RankingHistory) sem alteração
```

- [ ] **Step 2: Gerar a migração**

```bash
npx prisma migrate dev --name multi_provider_auth
```

Esperado: migração criada em `prisma/migrations/` e cliente Prisma regenerado.

- [ ] **Step 3: Verificar que o cliente foi gerado**

```bash
npx prisma generate
```

Esperado: saída sem erros.

- [ ] **Step 4: Commit**

```bash
git add prisma/schema.prisma prisma/migrations/
git commit -m "feat: migrate schema to multi-provider auth with invite system"
```

---

## Task 3: Interface IOAuthProvider + OAuthProviderFactory

**Files:**
- Create: `src/application/ports/IOAuthProvider.ts`
- Create: `src/infrastructure/auth/OAuthProviderFactory.ts`
- Delete: `src/application/ports/IMicrosoftOAuthService.ts`

- [ ] **Step 1: Criar IOAuthProvider**

```typescript
// src/application/ports/IOAuthProvider.ts

export interface OAuthTokens {
  accessToken: string;
  idToken: string;
}

export interface OAuthUserInfo {
  providerId: string;
  email: string;
  displayName: string;
}

export interface IOAuthProvider {
  getAuthorizationUrl(state: string): string;
  exchangeCodeForTokens(code: string): Promise<OAuthTokens>;
  getUserInfo(accessToken: string): Promise<OAuthUserInfo>;
}
```

- [ ] **Step 2: Criar OAuthProviderFactory**

```typescript
// src/infrastructure/auth/OAuthProviderFactory.ts

import { IOAuthProvider } from '@application/ports/IOAuthProvider';
import { GoogleOAuthService } from './GoogleOAuthService';
import { MicrosoftOAuthService } from './MicrosoftOAuthService';

export type OAuthProviderName = 'google' | 'microsoft';

export function createOAuthProvider(provider: OAuthProviderName): IOAuthProvider {
  switch (provider) {
    case 'google':
      return new GoogleOAuthService();
    case 'microsoft':
      return new MicrosoftOAuthService();
    default:
      throw new Error(`Unknown OAuth provider: ${provider}`);
  }
}
```

- [ ] **Step 3: Deletar IMicrosoftOAuthService.ts**

```bash
rm "E:/source/personal/futfun-backend/src/application/ports/IMicrosoftOAuthService.ts"
```

- [ ] **Step 4: Commit**

```bash
git add src/application/ports/IOAuthProvider.ts src/infrastructure/auth/OAuthProviderFactory.ts
git rm src/application/ports/IMicrosoftOAuthService.ts
git commit -m "feat: add IOAuthProvider interface and OAuthProviderFactory"
```

---

## Task 4: Refatorar MicrosoftOAuthService para implementar IOAuthProvider

**Files:**
- Modify: `src/infrastructure/auth/MicrosoftOAuthService.ts`
- Modify: `src/infrastructure/auth/__tests__/MicrosoftOAuthService.test.ts`

- [ ] **Step 1: Atualizar MicrosoftOAuthService**

```typescript
// src/infrastructure/auth/MicrosoftOAuthService.ts

import { ConfidentialClientApplication } from '@azure/msal-node';
import { IOAuthProvider, OAuthTokens, OAuthUserInfo } from '@application/ports/IOAuthProvider';

export class MicrosoftOAuthService implements IOAuthProvider {
  private msalClient: ConfidentialClientApplication;

  constructor() {
    this.msalClient = new ConfidentialClientApplication({
      auth: {
        clientId: process.env.MICROSOFT_CLIENT_ID!,
        authority: `https://login.microsoftonline.com/${process.env.MICROSOFT_TENANT_ID || 'common'}`,
        clientSecret: process.env.MICROSOFT_CLIENT_SECRET!,
      },
    });
  }

  getAuthorizationUrl(state: string): string {
    const redirectUri = `${process.env.APP_BASE_URL}/api/auth/callback?provider=microsoft`;
    const clientId = process.env.MICROSOFT_CLIENT_ID!;
    const tenantId = process.env.MICROSOFT_TENANT_ID || 'common';
    const scopes = encodeURIComponent('openid profile email User.Read');
    const encodedState = encodeURIComponent(state);
    return `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/authorize?client_id=${clientId}&response_type=code&redirect_uri=${encodeURIComponent(redirectUri)}&scope=${scopes}&response_mode=query&state=${encodedState}`;
  }

  async exchangeCodeForTokens(code: string): Promise<OAuthTokens> {
    const redirectUri = `${process.env.APP_BASE_URL}/api/auth/callback?provider=microsoft`;
    const response = await this.msalClient.acquireTokenByCode({
      code,
      scopes: ['openid', 'profile', 'email', 'User.Read'],
      redirectUri,
    });
    return {
      accessToken: response.accessToken,
      idToken: response.idToken || '',
    };
  }

  async getUserInfo(accessToken: string): Promise<OAuthUserInfo> {
    const response = await fetch('https://graph.microsoft.com/v1.0/me', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) throw new Error(`Failed to fetch Microsoft user info: ${response.status}`);
    const user = await response.json();
    return {
      providerId: user.id,
      email: user.mail || user.userPrincipalName,
      displayName: user.displayName,
    };
  }
}
```

- [ ] **Step 2: Atualizar teste**

```typescript
// src/infrastructure/auth/__tests__/MicrosoftOAuthService.test.ts

import { MicrosoftOAuthService } from '../MicrosoftOAuthService';

describe('MicrosoftOAuthService', () => {
  beforeEach(() => {
    process.env.MICROSOFT_CLIENT_ID = 'test-client-id';
    process.env.MICROSOFT_TENANT_ID = 'common';
    process.env.MICROSOFT_CLIENT_SECRET = 'test-secret';
    process.env.APP_BASE_URL = 'http://localhost:4000';
  });

  test('should generate authorization URL with required params', () => {
    const service = new MicrosoftOAuthService();
    const url = service.getAuthorizationUrl('');
    expect(url).toContain('login.microsoftonline.com');
    expect(url).toContain('test-client-id');
    expect(url).toContain('response_type=code');
    expect(url).toContain('callback%3Fprovider%3Dmicrosoft');
  });

  test('should include state in authorization URL', () => {
    const service = new MicrosoftOAuthService();
    const url = service.getAuthorizationUrl('invite:abc123');
    expect(url).toContain('state=invite%3Aabc123');
  });
});
```

- [ ] **Step 3: Rodar testes**

```bash
cd E:/source/personal/futfun-backend && npx jest src/infrastructure/auth/__tests__/MicrosoftOAuthService.test.ts --no-coverage
```

Esperado: 2 testes passando.

- [ ] **Step 4: Commit**

```bash
git add src/infrastructure/auth/MicrosoftOAuthService.ts src/infrastructure/auth/__tests__/MicrosoftOAuthService.test.ts
git commit -m "refactor: MicrosoftOAuthService implements IOAuthProvider, state param support"
```

---

## Task 5: Criar GoogleOAuthService

**Files:**
- Create: `src/infrastructure/auth/GoogleOAuthService.ts`
- Create: `src/infrastructure/auth/__tests__/GoogleOAuthService.test.ts`

- [ ] **Step 1: Escrever teste primeiro**

```typescript
// src/infrastructure/auth/__tests__/GoogleOAuthService.test.ts

import { GoogleOAuthService } from '../GoogleOAuthService';

describe('GoogleOAuthService', () => {
  beforeEach(() => {
    process.env.GOOGLE_CLIENT_ID = 'test-google-client-id.apps.googleusercontent.com';
    process.env.GOOGLE_CLIENT_SECRET = 'test-google-secret';
    process.env.APP_BASE_URL = 'http://localhost:4000';
  });

  test('should generate authorization URL with required params', () => {
    const service = new GoogleOAuthService();
    const url = service.getAuthorizationUrl('');
    expect(url).toContain('accounts.google.com/o/oauth2/v2/auth');
    expect(url).toContain('test-google-client-id');
    expect(url).toContain('response_type=code');
    expect(url).toContain('scope=');
    expect(url).toContain('callback%3Fprovider%3Dgoogle');
  });

  test('should include state in authorization URL', () => {
    const service = new GoogleOAuthService();
    const url = service.getAuthorizationUrl('invite:xyz789');
    expect(url).toContain('state=invite%3Axyz789');
  });
});
```

- [ ] **Step 2: Rodar teste para verificar que falha**

```bash
cd E:/source/personal/futfun-backend && npx jest src/infrastructure/auth/__tests__/GoogleOAuthService.test.ts --no-coverage
```

Esperado: FAIL — "Cannot find module '../GoogleOAuthService'"

- [ ] **Step 3: Implementar GoogleOAuthService**

```typescript
// src/infrastructure/auth/GoogleOAuthService.ts

import { OAuth2Client } from 'google-auth-library';
import { IOAuthProvider, OAuthTokens, OAuthUserInfo } from '@application/ports/IOAuthProvider';

export class GoogleOAuthService implements IOAuthProvider {
  private client: OAuth2Client;
  private redirectUri: string;

  constructor() {
    this.redirectUri = `${process.env.APP_BASE_URL}/api/auth/callback?provider=google`;
    this.client = new OAuth2Client(
      process.env.GOOGLE_CLIENT_ID!,
      process.env.GOOGLE_CLIENT_SECRET!,
      this.redirectUri
    );
  }

  getAuthorizationUrl(state: string): string {
    return this.client.generateAuthUrl({
      access_type: 'offline',
      scope: ['openid', 'profile', 'email'],
      state,
    });
  }

  async exchangeCodeForTokens(code: string): Promise<OAuthTokens> {
    const { tokens } = await this.client.getToken(code);
    if (!tokens.access_token) throw new Error('No access token returned from Google');
    return {
      accessToken: tokens.access_token,
      idToken: tokens.id_token || '',
    };
  }

  async getUserInfo(accessToken: string): Promise<OAuthUserInfo> {
    const response = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) throw new Error(`Failed to fetch Google user info: ${response.status}`);
    const user = await response.json();
    return {
      providerId: user.sub,
      email: user.email,
      displayName: user.name,
    };
  }
}
```

- [ ] **Step 4: Rodar teste para verificar que passa**

```bash
cd E:/source/personal/futfun-backend && npx jest src/infrastructure/auth/__tests__/GoogleOAuthService.test.ts --no-coverage
```

Esperado: 2 testes passando.

- [ ] **Step 5: Commit**

```bash
git add src/infrastructure/auth/GoogleOAuthService.ts src/infrastructure/auth/__tests__/GoogleOAuthService.test.ts
git commit -m "feat: add GoogleOAuthService implementing IOAuthProvider"
```

---

## Task 6: Atualizar TokenPayload e JwtTokenService

**Files:**
- Modify: `src/application/ports/ITokenService.ts`
- Modify: `src/infrastructure/auth/JwtTokenService.ts`
- Modify: `src/infrastructure/auth/__tests__/JwtTokenService.test.ts`

- [ ] **Step 1: Atualizar ITokenService.ts**

```typescript
// src/application/ports/ITokenService.ts

export interface TokenPayload {
  userId: string;
  email: string;
  role: 'PENDING' | 'MEMBER' | 'ADMIN';
  iat?: number;
  exp?: number;
}

export interface ITokenService {
  generateAccessToken(payload: TokenPayload): string;
  generateRefreshToken(payload: TokenPayload): string;
  verifyAccessToken(token: string): TokenPayload;
  verifyRefreshToken(token: string): TokenPayload;
}
```

- [ ] **Step 2: Atualizar JwtTokenService.ts**

```typescript
// src/infrastructure/auth/JwtTokenService.ts

import jwt from 'jsonwebtoken';
import { ITokenService, TokenPayload } from '@application/ports/ITokenService';

export class JwtTokenService implements ITokenService {
  private readonly secret: string;
  private readonly accessExpires: string;
  private readonly refreshExpires: string;

  constructor() {
    this.secret = process.env.JWT_SECRET!;
    this.accessExpires = process.env.JWT_ACCESS_EXPIRES_IN || '15m';
    this.refreshExpires = process.env.JWT_REFRESH_EXPIRES_IN || '7d';
  }

  generateAccessToken(payload: TokenPayload): string {
    return jwt.sign(
      { userId: payload.userId, email: payload.email, role: payload.role },
      this.secret,
      { expiresIn: this.accessExpires as jwt.SignOptions['expiresIn'] }
    );
  }

  generateRefreshToken(payload: TokenPayload): string {
    return jwt.sign(
      { userId: payload.userId, email: payload.email, role: payload.role },
      this.secret,
      { expiresIn: this.refreshExpires as jwt.SignOptions['expiresIn'] }
    );
  }

  verifyAccessToken(token: string): TokenPayload {
    return jwt.verify(token, this.secret) as TokenPayload;
  }

  verifyRefreshToken(token: string): TokenPayload {
    return jwt.verify(token, this.secret) as TokenPayload;
  }
}
```

- [ ] **Step 3: Atualizar testes de JwtTokenService**

```typescript
// src/infrastructure/auth/__tests__/JwtTokenService.test.ts

import { JwtTokenService } from '../JwtTokenService';

describe('JwtTokenService', () => {
  beforeEach(() => {
    process.env.JWT_SECRET = 'test-secret-must-be-at-least-32-chars-long';
    process.env.JWT_ACCESS_EXPIRES_IN = '15m';
    process.env.JWT_REFRESH_EXPIRES_IN = '7d';
  });

  test('should generate and verify access token with role', () => {
    const service = new JwtTokenService();
    const payload = { userId: 'user-123', email: 'test@example.com', role: 'MEMBER' as const };
    const token = service.generateAccessToken(payload);
    const verified = service.verifyAccessToken(token);
    expect(verified.userId).toBe('user-123');
    expect(verified.email).toBe('test@example.com');
    expect(verified.role).toBe('MEMBER');
  });

  test('should generate and verify refresh token with role', () => {
    const service = new JwtTokenService();
    const payload = { userId: 'user-123', email: 'test@example.com', role: 'ADMIN' as const };
    const token = service.generateRefreshToken(payload);
    const verified = service.verifyRefreshToken(token);
    expect(verified.userId).toBe('user-123');
    expect(verified.role).toBe('ADMIN');
  });

  test('should throw for invalid access token', () => {
    const service = new JwtTokenService();
    expect(() => service.verifyAccessToken('invalid-token')).toThrow();
  });
});
```

- [ ] **Step 4: Rodar testes**

```bash
cd E:/source/personal/futfun-backend && npx jest src/infrastructure/auth/__tests__/JwtTokenService.test.ts --no-coverage
```

Esperado: 3 testes passando.

- [ ] **Step 5: Commit**

```bash
git add src/application/ports/ITokenService.ts src/infrastructure/auth/JwtTokenService.ts src/infrastructure/auth/__tests__/JwtTokenService.test.ts
git commit -m "feat: add role field to TokenPayload and JwtTokenService"
```

---

## Task 7: Criar OAuthCallbackHandler (TDD)

**Files:**
- Create: `src/application/handlers/OAuthCallbackHandler.ts`
- Create: `src/application/handlers/__tests__/OAuthCallbackHandler.test.ts`

- [ ] **Step 1: Escrever testes primeiro**

```typescript
// src/application/handlers/__tests__/OAuthCallbackHandler.test.ts

import { OAuthCallbackHandler } from '../OAuthCallbackHandler';
import { IOAuthProvider } from '@application/ports/IOAuthProvider';
import { ITokenService, TokenPayload } from '@application/ports/ITokenService';

const mockProvider: IOAuthProvider = {
  getAuthorizationUrl: jest.fn(),
  exchangeCodeForTokens: jest.fn().mockResolvedValue({
    accessToken: 'provider-access-token',
    idToken: 'provider-id-token',
  }),
  getUserInfo: jest.fn().mockResolvedValue({
    providerId: 'google-sub-123',
    email: 'user@example.com',
    displayName: 'Test User',
  }),
};

const mockTokenService: ITokenService = {
  generateAccessToken: jest.fn().mockReturnValue('access-jwt'),
  generateRefreshToken: jest.fn().mockReturnValue('refresh-jwt'),
  verifyAccessToken: jest.fn(),
  verifyRefreshToken: jest.fn(),
};

const mockRedis = {
  setex: jest.fn().mockResolvedValue('OK'),
  get: jest.fn(),
  del: jest.fn(),
};

function makePrisma(overrides: Partial<ReturnType<typeof makeDefaultPrisma>> = {}) {
  return { ...makeDefaultPrisma(), ...overrides };
}

function makeDefaultPrisma() {
  return {
    user: {
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({
        id: 'user-uuid',
        email: 'user@example.com',
        displayName: 'Test User',
        role: 'PENDING',
      }),
      update: jest.fn().mockResolvedValue({
        id: 'user-uuid',
        email: 'user@example.com',
        displayName: 'Test User',
        role: 'MEMBER',
      }),
    },
    invite: {
      findFirst: jest.fn().mockResolvedValue(null),
      update: jest.fn().mockResolvedValue({}),
    },
  };
}

describe('OAuthCallbackHandler', () => {
  beforeEach(() => {
    process.env.ADMIN_SEED_EMAIL = 'admin@example.com';
    jest.clearAllMocks();
  });

  test('creates new PENDING user when no invite and not admin email', async () => {
    const prisma = makePrisma();
    const handler = new OAuthCallbackHandler(
      mockProvider,
      mockTokenService,
      prisma as any,
      mockRedis as any
    );

    const result = await handler.handle({ code: 'auth-code', provider: 'google', state: '' });

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ role: 'PENDING', provider: 'google' }),
      })
    );
    expect(result.user.role).toBe('PENDING');
    expect(result.accessToken).toBe('access-jwt');
  });

  test('creates new ADMIN user when email matches ADMIN_SEED_EMAIL', async () => {
    const adminProvider: IOAuthProvider = {
      ...mockProvider,
      getUserInfo: jest.fn().mockResolvedValue({
        providerId: 'google-sub-admin',
        email: 'admin@example.com',
        displayName: 'Admin User',
      }),
    };
    const prisma = makePrisma({
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'admin-uuid',
          email: 'admin@example.com',
          displayName: 'Admin User',
          role: 'ADMIN',
        }),
        update: jest.fn(),
      },
    });
    const handler = new OAuthCallbackHandler(
      adminProvider,
      mockTokenService,
      prisma as any,
      mockRedis as any
    );

    const result = await handler.handle({ code: 'auth-code', provider: 'google', state: '' });

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ role: 'ADMIN' }),
      })
    );
    expect(result.user.role).toBe('ADMIN');
  });

  test('creates new MEMBER user when valid invite token in state', async () => {
    const futureDate = new Date(Date.now() + 86400000);
    const prisma = makePrisma({
      invite: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'invite-uuid',
          email: 'user@example.com',
          token: 'valid-token',
          expiresAt: futureDate,
          usedAt: null,
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'user-uuid',
          email: 'user@example.com',
          displayName: 'Test User',
          role: 'MEMBER',
        }),
        update: jest.fn(),
      },
    });
    const handler = new OAuthCallbackHandler(
      mockProvider,
      mockTokenService,
      prisma as any,
      mockRedis as any
    );

    const result = await handler.handle({
      code: 'auth-code',
      provider: 'google',
      state: 'invite:valid-token',
    });

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ role: 'MEMBER' }),
      })
    );
    expect(prisma.invite.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'invite-uuid' } })
    );
    expect(result.user.role).toBe('MEMBER');
  });

  test('updates lastLoginAt for existing user and returns current role', async () => {
    const existingUser = {
      id: 'existing-uuid',
      email: 'user@example.com',
      displayName: 'Existing User',
      role: 'MEMBER',
    };
    const prisma = makePrisma({
      user: {
        findFirst: jest.fn().mockResolvedValue(existingUser),
        update: jest.fn().mockResolvedValue(existingUser),
        create: jest.fn(),
      },
    });
    const handler = new OAuthCallbackHandler(
      mockProvider,
      mockTokenService,
      prisma as any,
      mockRedis as any
    );

    const result = await handler.handle({ code: 'auth-code', provider: 'google', state: '' });

    expect(prisma.user.create).not.toHaveBeenCalled();
    expect(prisma.user.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'existing-uuid' } })
    );
    expect(result.user.role).toBe('MEMBER');
  });
});
```

- [ ] **Step 2: Rodar para verificar que falha**

```bash
cd E:/source/personal/futfun-backend && npx jest src/application/handlers/__tests__/OAuthCallbackHandler.test.ts --no-coverage
```

Esperado: FAIL — "Cannot find module '../OAuthCallbackHandler'"

- [ ] **Step 3: Implementar OAuthCallbackHandler**

```typescript
// src/application/handlers/OAuthCallbackHandler.ts

import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';
import { IOAuthProvider } from '@application/ports/IOAuthProvider';
import { ITokenService, TokenPayload } from '@application/ports/ITokenService';

export interface CallbackInput {
  code: string;
  provider: string;
  state: string;
}

export interface CallbackResult {
  accessToken: string;
  refreshToken: string;
  user: { id: string; email: string; displayName: string; role: string };
}

function parseInviteToken(state: string): string | null {
  if (state.startsWith('invite:')) return state.slice(7);
  return null;
}

export class OAuthCallbackHandler {
  constructor(
    private readonly oauthProvider: IOAuthProvider,
    private readonly tokenService: ITokenService,
    private readonly prisma: PrismaClient,
    private readonly redis: Redis
  ) {}

  async handle(input: CallbackInput): Promise<CallbackResult> {
    const { code, provider, state } = input;

    const tokens = await this.oauthProvider.exchangeCodeForTokens(code);
    const userInfo = await this.oauthProvider.getUserInfo(tokens.accessToken);

    const inviteToken = parseInviteToken(state);

    let user = await this.prisma.user.findFirst({
      where: { provider, providerId: userInfo.providerId },
    });

    if (!user) {
      let role: 'PENDING' | 'MEMBER' | 'ADMIN' = 'PENDING';

      if (userInfo.email === process.env.ADMIN_SEED_EMAIL) {
        role = 'ADMIN';
      } else if (inviteToken) {
        const invite = await this.prisma.invite.findFirst({
          where: {
            token: inviteToken,
            usedAt: null,
            expiresAt: { gt: new Date() },
          },
        });
        if (invite) {
          role = 'MEMBER';
          await this.prisma.invite.update({
            where: { id: invite.id },
            data: { usedAt: new Date() },
          });
        }
      }

      user = await this.prisma.user.create({
        data: {
          provider,
          providerId: userInfo.providerId,
          email: userInfo.email,
          displayName: userInfo.displayName,
          role,
        },
      });
    } else {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date() },
      });
    }

    const payload: TokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role as TokenPayload['role'],
    };

    const accessToken = this.tokenService.generateAccessToken(payload);
    const refreshToken = this.tokenService.generateRefreshToken(payload);
    await this.redis.setex(`refresh-token:${user.id}`, 7 * 24 * 60 * 60, refreshToken);

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email, displayName: user.displayName, role: user.role },
    };
  }
}
```

- [ ] **Step 4: Rodar testes**

```bash
cd E:/source/personal/futfun-backend && npx jest src/application/handlers/__tests__/OAuthCallbackHandler.test.ts --no-coverage
```

Esperado: 4 testes passando.

- [ ] **Step 5: Commit**

```bash
git add src/application/handlers/OAuthCallbackHandler.ts src/application/handlers/__tests__/OAuthCallbackHandler.test.ts
git commit -m "feat: add OAuthCallbackHandler with invite detection and role assignment"
```

---

## Task 8: Criar ResendEmailService (TDD)

**Files:**
- Create: `src/application/ports/IEmailService.ts`
- Create: `src/infrastructure/email/ResendEmailService.ts`
- Create: `src/infrastructure/email/__tests__/ResendEmailService.test.ts`

- [ ] **Step 1: Criar IEmailService**

```typescript
// src/application/ports/IEmailService.ts

export interface IEmailService {
  sendInvite(to: string, inviteToken: string, inviterName: string): Promise<void>;
  sendApprovalNotification(to: string, displayName: string): Promise<void>;
}
```

- [ ] **Step 2: Escrever testes**

```typescript
// src/infrastructure/email/__tests__/ResendEmailService.test.ts

jest.mock('resend', () => ({
  Resend: jest.fn().mockImplementation(() => ({
    emails: {
      send: jest.fn().mockResolvedValue({ data: { id: 'email-id' }, error: null }),
    },
  })),
}));

import { ResendEmailService } from '../ResendEmailService';

describe('ResendEmailService', () => {
  beforeEach(() => {
    process.env.RESEND_API_KEY = 're_test_key';
    process.env.APP_BASE_URL = 'https://app.futfun.com';
    jest.clearAllMocks();
  });

  test('sendInvite should call Resend with correct recipient and subject', async () => {
    const service = new ResendEmailService();
    const { Resend } = require('resend');
    const mockInstance = Resend.mock.results[0].value;

    await service.sendInvite('user@example.com', 'token-abc', 'Gerson');

    expect(mockInstance.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: ['user@example.com'],
        subject: expect.stringContaining('FutFun'),
        html: expect.stringContaining('token-abc'),
      })
    );
  });

  test('sendApprovalNotification should call Resend with correct recipient', async () => {
    const service = new ResendEmailService();
    const { Resend } = require('resend');
    const mockInstance = Resend.mock.results[0].value;

    await service.sendApprovalNotification('user@example.com', 'João Silva');

    expect(mockInstance.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: ['user@example.com'],
        subject: expect.stringContaining('aprovado'),
        html: expect.stringContaining('João Silva'),
      })
    );
  });

  test('should throw when Resend returns an error', async () => {
    const { Resend } = require('resend');
    Resend.mockImplementation(() => ({
      emails: {
        send: jest.fn().mockResolvedValue({ data: null, error: { message: 'API error' } }),
      },
    }));

    const service = new ResendEmailService();
    await expect(service.sendInvite('user@example.com', 'token', 'Admin')).rejects.toThrow('API error');
  });
});
```

- [ ] **Step 3: Rodar para verificar que falha**

```bash
cd E:/source/personal/futfun-backend && npx jest src/infrastructure/email/__tests__/ResendEmailService.test.ts --no-coverage
```

Esperado: FAIL — "Cannot find module '../ResendEmailService'"

- [ ] **Step 4: Implementar ResendEmailService**

```typescript
// src/infrastructure/email/ResendEmailService.ts

import { Resend } from 'resend';
import { IEmailService } from '@application/ports/IEmailService';

export class ResendEmailService implements IEmailService {
  private resend: Resend;

  constructor() {
    this.resend = new Resend(process.env.RESEND_API_KEY!);
  }

  async sendInvite(to: string, inviteToken: string, inviterName: string): Promise<void> {
    const inviteUrl = `${process.env.APP_BASE_URL}/invite?token=${inviteToken}`;
    const { error } = await this.resend.emails.send({
      from: 'FutFun <noreply@futfun.com>',
      to: [to],
      subject: 'Você foi convidado para o FutFun ⚽',
      html: `
        <h2>Você recebeu um convite!</h2>
        <p>${inviterName} te convidou para participar do <strong>FutFun</strong> — o bolão da Copa do Mundo 2026.</p>
        <p>Clique no link abaixo para aceitar o convite (válido por 7 dias):</p>
        <p><a href="${inviteUrl}" style="background:#16a34a;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Aceitar convite</a></p>
        <p>Ou copie: ${inviteUrl}</p>
      `,
    });
    if (error) throw new Error(error.message);
  }

  async sendApprovalNotification(to: string, displayName: string): Promise<void> {
    const { error } = await this.resend.emails.send({
      from: 'FutFun <noreply@futfun.com>',
      to: [to],
      subject: 'Seu acesso ao FutFun foi aprovado! ⚽',
      html: `
        <h2>Bem-vindo(a) ao FutFun, ${displayName}!</h2>
        <p>Seu acesso foi <strong>aprovado</strong>. Agora você pode entrar e fazer seus palpites para a Copa do Mundo 2026.</p>
        <p><a href="${process.env.APP_BASE_URL}" style="background:#16a34a;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Acessar o FutFun</a></p>
      `,
    });
    if (error) throw new Error(error.message);
  }
}
```

- [ ] **Step 5: Rodar testes**

```bash
cd E:/source/personal/futfun-backend && npx jest src/infrastructure/email/__tests__/ResendEmailService.test.ts --no-coverage
```

Esperado: 3 testes passando.

- [ ] **Step 6: Commit**

```bash
git add src/application/ports/IEmailService.ts src/infrastructure/email/ResendEmailService.ts src/infrastructure/email/__tests__/ResendEmailService.test.ts
git commit -m "feat: add ResendEmailService for invite and approval emails"
```

---

## Task 9: Criar CreateInviteHandler (TDD)

**Files:**
- Create: `src/application/handlers/CreateInviteHandler.ts`
- Create: `src/application/handlers/__tests__/CreateInviteHandler.test.ts`

- [ ] **Step 1: Escrever teste**

```typescript
// src/application/handlers/__tests__/CreateInviteHandler.test.ts

import { CreateInviteHandler } from '../CreateInviteHandler';
import { IEmailService } from '@application/ports/IEmailService';

const mockEmailService: IEmailService = {
  sendInvite: jest.fn().mockResolvedValue(undefined),
  sendApprovalNotification: jest.fn().mockResolvedValue(undefined),
};

function makePrisma(userExists = false, invitePending = false) {
  return {
    user: {
      findUnique: jest.fn().mockResolvedValue(
        userExists ? { id: 'u1', email: 'target@example.com', role: 'MEMBER' } : null
      ),
    },
    invite: {
      findFirst: jest.fn().mockResolvedValue(
        invitePending ? { id: 'i1', email: 'target@example.com', usedAt: null } : null
      ),
      create: jest.fn().mockResolvedValue({ id: 'new-invite', token: 'generated-token' }),
    },
  };
}

describe('CreateInviteHandler', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates invite and sends email for valid new recipient', async () => {
    const prisma = makePrisma(false, false);
    const handler = new CreateInviteHandler(prisma as any, mockEmailService);

    await handler.handle({
      email: 'target@example.com',
      createdBy: 'admin-uuid',
      inviterName: 'Gerson',
    });

    expect(prisma.invite.create).toHaveBeenCalled();
    expect(mockEmailService.sendInvite).toHaveBeenCalledWith(
      'target@example.com',
      expect.any(String),
      'Gerson'
    );
  });

  test('throws if user with that email is already a MEMBER or ADMIN', async () => {
    const prisma = makePrisma(true, false);
    const handler = new CreateInviteHandler(prisma as any, mockEmailService);

    await expect(
      handler.handle({ email: 'target@example.com', createdBy: 'admin-uuid', inviterName: 'Gerson' })
    ).rejects.toThrow('already a member');
  });

  test('throws if pending invite already exists for this email', async () => {
    const prisma = makePrisma(false, true);
    const handler = new CreateInviteHandler(prisma as any, mockEmailService);

    await expect(
      handler.handle({ email: 'target@example.com', createdBy: 'admin-uuid', inviterName: 'Gerson' })
    ).rejects.toThrow('pending invite');
  });
});
```

- [ ] **Step 2: Rodar para verificar que falha**

```bash
cd E:/source/personal/futfun-backend && npx jest src/application/handlers/__tests__/CreateInviteHandler.test.ts --no-coverage
```

Esperado: FAIL

- [ ] **Step 3: Implementar CreateInviteHandler**

```typescript
// src/application/handlers/CreateInviteHandler.ts

import { PrismaClient } from '@prisma/client';
import { v4 as uuidv4 } from 'uuid';
import { IEmailService } from '@application/ports/IEmailService';

export interface CreateInviteInput {
  email: string;
  createdBy: string;
  inviterName: string;
}

export class CreateInviteHandler {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly emailService: IEmailService
  ) {}

  async handle(input: CreateInviteInput): Promise<{ inviteId: string }> {
    const { email, createdBy, inviterName } = input;

    const existingUser = await this.prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      throw new Error(`User ${email} is already a member`);
    }

    const existingInvite = await this.prisma.invite.findFirst({
      where: { email, usedAt: null, expiresAt: { gt: new Date() } },
    });
    if (existingInvite) {
      throw new Error(`There is already a pending invite for ${email}`);
    }

    const token = uuidv4();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const invite = await this.prisma.invite.create({
      data: { email, token, expiresAt, createdBy },
    });

    await this.emailService.sendInvite(email, token, inviterName);

    return { inviteId: invite.id };
  }
}
```

- [ ] **Step 4: Rodar testes**

```bash
cd E:/source/personal/futfun-backend && npx jest src/application/handlers/__tests__/CreateInviteHandler.test.ts --no-coverage
```

Esperado: 3 testes passando.

- [ ] **Step 5: Commit**

```bash
git add src/application/handlers/CreateInviteHandler.ts src/application/handlers/__tests__/CreateInviteHandler.test.ts
git commit -m "feat: add CreateInviteHandler with email sending and validation"
```

---

## Task 10: Atualizar authMiddleware (adicionar withAdmin)

**Files:**
- Modify: `src/presentation/middleware/authMiddleware.ts`

- [ ] **Step 1: Atualizar authMiddleware.ts**

```typescript
// src/presentation/middleware/authMiddleware.ts

import { NextRequest, NextResponse } from 'next/server';
import { JwtTokenService } from '@infrastructure/auth/JwtTokenService';
import { TokenPayload } from '@application/ports/ITokenService';

export function withAuth(
  handler: (req: NextRequest, user: TokenPayload, context?: any) => Promise<NextResponse>
) {
  return async (req: NextRequest, context?: any): Promise<NextResponse> => {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: { message: 'Missing or invalid Authorization header', code: 'UNAUTHORIZED' } },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);
    const tokenService = new JwtTokenService();

    try {
      const user = tokenService.verifyAccessToken(token);
      return handler(req, user, context);
    } catch {
      return NextResponse.json(
        { error: { message: 'Invalid or expired token', code: 'TOKEN_EXPIRED' } },
        { status: 401 }
      );
    }
  };
}

export function withAdmin(
  handler: (req: NextRequest, user: TokenPayload, context?: any) => Promise<NextResponse>
) {
  return withAuth(async (req, user, context) => {
    if (user.role !== 'ADMIN') {
      return NextResponse.json(
        { error: { message: 'Forbidden', code: 'FORBIDDEN' } },
        { status: 403 }
      );
    }
    return handler(req, user, context);
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add src/presentation/middleware/authMiddleware.ts
git commit -m "feat: add withAdmin middleware for admin-only route protection"
```

---

## Task 11: Atualizar rotas de auth e criar callback unificado

**Files:**
- Create: `app/api/auth/google/login/route.ts`
- Modify: `app/api/auth/microsoft/login/route.ts`
- Create: `app/api/auth/callback/route.ts`
- Modify: `app/api/auth/refresh/route.ts`
- Delete: `app/api/auth/microsoft/callback/route.ts`
- Delete: `app/api/auth/setup-password/route.ts`
- Delete: `app/api/auth/verify-password/route.ts`

- [ ] **Step 1: Criar rota Google login**

```typescript
// app/api/auth/google/login/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { GoogleOAuthService } from '@infrastructure/auth/GoogleOAuthService';
import { handleError } from '@presentation/middleware/errorHandler';

export async function GET(req: NextRequest) {
  try {
    const state = req.nextUrl.searchParams.get('state') || '';
    const service = new GoogleOAuthService();
    const authUrl = service.getAuthorizationUrl(state);
    return NextResponse.json({ authUrl });
  } catch (error) {
    return handleError(error);
  }
}
```

- [ ] **Step 2: Atualizar rota Microsoft login**

```typescript
// app/api/auth/microsoft/login/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { MicrosoftOAuthService } from '@infrastructure/auth/MicrosoftOAuthService';
import { handleError } from '@presentation/middleware/errorHandler';

export async function GET(req: NextRequest) {
  try {
    const state = req.nextUrl.searchParams.get('state') || '';
    const service = new MicrosoftOAuthService();
    const authUrl = service.getAuthorizationUrl(state);
    return NextResponse.json({ authUrl });
  } catch (error) {
    return handleError(error);
  }
}
```

- [ ] **Step 3: Criar callback unificado**

O callback redireciona para deep link do app mobile em vez de retornar JSON — único modo de devolver tokens ao Flutter após fluxo em browser externo.

```typescript
// app/api/auth/callback/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { createOAuthProvider, OAuthProviderName } from '@infrastructure/auth/OAuthProviderFactory';
import { JwtTokenService } from '@infrastructure/auth/JwtTokenService';
import { OAuthCallbackHandler } from '@application/handlers/OAuthCallbackHandler';
import { getContainer } from '@infrastructure/container/container';

const VALID_PROVIDERS: OAuthProviderName[] = ['google', 'microsoft'];

export async function GET(req: NextRequest) {
  const scheme = process.env.APP_DEEP_LINK_SCHEME || 'futfun';
  const errorUrl = `${scheme}://auth?error=true`;

  try {
    const provider = req.nextUrl.searchParams.get('provider');
    const code = req.nextUrl.searchParams.get('code');
    const state = req.nextUrl.searchParams.get('state') || '';

    if (!provider || !VALID_PROVIDERS.includes(provider as OAuthProviderName) || !code) {
      return NextResponse.redirect(errorUrl);
    }

    const oauthProvider = createOAuthProvider(provider as OAuthProviderName);
    const tokenService = new JwtTokenService();
    const { prisma, redis } = getContainer();

    const handler = new OAuthCallbackHandler(oauthProvider, tokenService, prisma, redis);
    const result = await handler.handle({ code, provider, state });

    const deepLink = new URL(`${scheme}://auth`);
    deepLink.searchParams.set('accessToken', result.accessToken);
    deepLink.searchParams.set('refreshToken', result.refreshToken);
    deepLink.searchParams.set('userId', result.user.id);
    deepLink.searchParams.set('email', result.user.email);
    deepLink.searchParams.set('displayName', result.user.displayName);
    deepLink.searchParams.set('role', result.user.role);

    return NextResponse.redirect(deepLink.toString());
  } catch {
    return NextResponse.redirect(errorUrl);
  }
}
```

- [ ] **Step 4: Atualizar rota de refresh (incluir role do DB)**

```typescript
// app/api/auth/refresh/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { JwtTokenService } from '@infrastructure/auth/JwtTokenService';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const schema = z.object({ refreshToken: z.string() });

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { refreshToken } = schema.parse(body);

    const tokenService = new JwtTokenService();
    const { prisma, redis } = getContainer();

    const payload = tokenService.verifyRefreshToken(refreshToken);
    const storedToken = await redis.get(`refresh-token:${payload.userId}`);

    if (!storedToken || storedToken !== refreshToken) {
      return NextResponse.json(
        { error: { message: 'Invalid refresh token', code: 'INVALID_REFRESH_TOKEN' } },
        { status: 401 }
      );
    }

    const user = await prisma.user.findUnique({ where: { id: payload.userId } });
    if (!user) {
      return NextResponse.json(
        { error: { message: 'User not found', code: 'USER_NOT_FOUND' } },
        { status: 404 }
      );
    }

    // Always use current role from DB to reflect any permission changes
    const newPayload: TokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role as TokenPayload['role'],
    };

    const accessToken = tokenService.generateAccessToken(newPayload);
    return NextResponse.json({ accessToken });
  } catch (error) {
    return handleError(error);
  }
}
```

- [ ] **Step 5: Deletar rotas obsoletas**

```bash
rm "E:/source/personal/futfun-backend/app/api/auth/microsoft/callback/route.ts"
rm "E:/source/personal/futfun-backend/app/api/auth/setup-password/route.ts"
rm "E:/source/personal/futfun-backend/app/api/auth/verify-password/route.ts"
```

- [ ] **Step 6: Commit**

```bash
git add app/api/auth/
git rm app/api/auth/microsoft/callback/route.ts app/api/auth/setup-password/route.ts app/api/auth/verify-password/route.ts
git commit -m "feat: add Google login route, unified OAuth callback, remove password routes"
```

---

## Task 12: Rota pública de validação de invite

**Files:**
- Create: `app/api/invites/[token]/route.ts`

- [ ] **Step 1: Criar rota**

```typescript
// app/api/invites/[token]/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export async function GET(
  _req: NextRequest,
  { params }: { params: { token: string } }
) {
  try {
    const { prisma } = getContainer();
    const invite = await prisma.invite.findFirst({
      where: {
        token: params.token,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true, email: true, expiresAt: true },
    });

    if (!invite) {
      return NextResponse.json(
        { error: { message: 'Invite not found, expired, or already used', code: 'INVALID_INVITE' } },
        { status: 404 }
      );
    }

    return NextResponse.json({ valid: true, email: invite.email, expiresAt: invite.expiresAt });
  } catch (error) {
    return handleError(error);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/api/invites/
git commit -m "feat: add public invite token validation route"
```

---

## Task 13: Rotas de admin (usuários e convites)

**Files:**
- Create: `app/api/admin/users/route.ts`
- Create: `app/api/admin/users/[id]/role/route.ts`
- Create: `app/api/admin/users/[id]/route.ts`
- Create: `app/api/admin/invites/route.ts`
- Create: `app/api/admin/invites/[id]/route.ts`

- [ ] **Step 1: Listar usuários**

```typescript
// app/api/admin/users/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const GET = withAdmin(async (_req: NextRequest) => {
  try {
    const { prisma } = getContainer();
    const users = await prisma.user.findMany({
      select: {
        id: true,
        email: true,
        displayName: true,
        provider: true,
        role: true,
        createdAt: true,
        lastLoginAt: true,
      },
      orderBy: { createdAt: 'asc' },
    });
    return NextResponse.json({ users });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 2: Alterar role de usuário**

```typescript
// app/api/admin/users/[id]/role/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { ResendEmailService } from '@infrastructure/email/ResendEmailService';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const schema = z.object({ role: z.enum(['PENDING', 'MEMBER', 'ADMIN']) });

export const PATCH = withAdmin(async (req: NextRequest, _user: TokenPayload, context: any) => {
  try {
    const { id } = context.params;
    const body = await req.json();
    const { role } = schema.parse(body);

    const { prisma } = getContainer();

    const target = await prisma.user.findUnique({ where: { id } });
    if (!target) {
      return NextResponse.json(
        { error: { message: 'User not found', code: 'USER_NOT_FOUND' } },
        { status: 404 }
      );
    }

    const wasPromotedToMember = target.role === 'PENDING' && role === 'MEMBER';

    const updated = await prisma.user.update({
      where: { id },
      data: { role },
      select: { id: true, email: true, displayName: true, role: true },
    });

    if (wasPromotedToMember) {
      const emailService = new ResendEmailService();
      await emailService.sendApprovalNotification(updated.email, updated.displayName);
    }

    return NextResponse.json({ user: updated });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 3: Deletar usuário**

```typescript
// app/api/admin/users/[id]/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const DELETE = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  try {
    const { id } = context.params;
    const { prisma } = getContainer();

    const target = await prisma.user.findUnique({ where: { id } });
    if (!target) {
      return NextResponse.json(
        { error: { message: 'User not found', code: 'USER_NOT_FOUND' } },
        { status: 404 }
      );
    }

    await prisma.user.delete({ where: { id } });
    return NextResponse.json({ success: true });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 4: Criar convite**

```typescript
// app/api/admin/invites/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { ResendEmailService } from '@infrastructure/email/ResendEmailService';
import { CreateInviteHandler } from '@application/handlers/CreateInviteHandler';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const schema = z.object({ email: z.string().email() });

export const POST = withAdmin(async (req: NextRequest, user: TokenPayload) => {
  try {
    const body = await req.json();
    const { email } = schema.parse(body);

    const { prisma } = getContainer();
    const emailService = new ResendEmailService();
    const handler = new CreateInviteHandler(prisma, emailService);

    const adminUser = await prisma.user.findUnique({
      where: { id: user.userId },
      select: { displayName: true },
    });

    const result = await handler.handle({
      email,
      createdBy: user.userId,
      inviterName: adminUser?.displayName || 'Admin',
    });

    return NextResponse.json({ inviteId: result.inviteId }, { status: 201 });
  } catch (error) {
    return handleError(error);
  }
});

export const GET = withAdmin(async (_req: NextRequest) => {
  try {
    const { prisma } = getContainer();
    const invites = await prisma.invite.findMany({
      select: {
        id: true,
        email: true,
        expiresAt: true,
        usedAt: true,
        createdAt: true,
        creator: { select: { displayName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return NextResponse.json({ invites });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 5: Cancelar convite**

```typescript
// app/api/admin/invites/[id]/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const DELETE = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  try {
    const { id } = context.params;
    const { prisma } = getContainer();

    const invite = await prisma.invite.findUnique({ where: { id } });
    if (!invite) {
      return NextResponse.json(
        { error: { message: 'Invite not found', code: 'INVITE_NOT_FOUND' } },
        { status: 404 }
      );
    }
    if (invite.usedAt) {
      return NextResponse.json(
        { error: { message: 'Cannot cancel an already used invite', code: 'INVITE_ALREADY_USED' } },
        { status: 400 }
      );
    }

    await prisma.invite.delete({ where: { id } });
    return NextResponse.json({ success: true });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 6: Commit**

```bash
git add app/api/admin/ app/api/invites/
git commit -m "feat: add admin routes for user management and invite system"
```

---

## Task 14: Atualizar container e rodar todos os testes

**Files:**
- Modify: `src/infrastructure/container/container.ts`

- [ ] **Step 1: Atualizar container (adicionar EmailService)**

```typescript
// src/infrastructure/container/container.ts

import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';
import { FootballDataOrgAdapter } from '@infrastructure/football-data/FootballDataOrgAdapter';
import { MatchSyncJob } from '@infrastructure/football-data/MatchSyncJob';
import { ResendEmailService } from '@infrastructure/email/ResendEmailService';
import { IEmailService } from '@application/ports/IEmailService';

export interface IContainer {
  prisma: PrismaClient;
  redis: Redis;
  matchSyncJob: MatchSyncJob;
  emailService: IEmailService;
}

let container: IContainer | null = null;

export function initializeContainer(): IContainer {
  if (container) return container;

  const prisma = new PrismaClient();
  const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
  const footballProvider = new FootballDataOrgAdapter();
  const matchSyncJob = new MatchSyncJob(prisma, footballProvider);
  const emailService = new ResendEmailService();

  container = { prisma, redis, matchSyncJob, emailService };
  return container;
}

export function getContainer(): IContainer {
  if (!container) throw new Error('Container not initialized. Call initializeContainer() first.');
  return container;
}
```

- [ ] **Step 2: Rodar todos os testes**

```bash
cd E:/source/personal/futfun-backend && npx jest --no-coverage
```

Esperado: todos os testes passando (incluindo os 12 de PointsCalculationService).

- [ ] **Step 3: Commit final**

```bash
git add src/infrastructure/container/container.ts
git commit -m "chore: add emailService to DI container"
```

---

## Task 15: Atualizar .env.example

- [ ] **Step 1: Atualizar .env.example**

Criar ou atualizar o arquivo `.env.example` na raiz do backend:

```bash
# Database
DATABASE_URL="postgresql://futfun:password@localhost:5432/futfun"

# Redis
REDIS_URL="redis://localhost:6379"

# Microsoft OAuth (mantido)
MICROSOFT_CLIENT_ID="your-microsoft-client-id"
MICROSOFT_CLIENT_SECRET="your-microsoft-client-secret"
MICROSOFT_TENANT_ID="common"

# Google OAuth (novo)
GOOGLE_CLIENT_ID="your-google-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-google-client-secret"

# JWT
JWT_SECRET="your-256-bit-secret-minimum-32-chars"
JWT_ACCESS_EXPIRES_IN="15m"
JWT_REFRESH_EXPIRES_IN="7d"

# App
APP_BASE_URL="http://localhost:4000"
APP_DEEP_LINK_SCHEME="futfun"
PORT=4000
NODE_ENV="development"
CORS_ALLOWED_ORIGINS="http://localhost:3000"

# Football Data
FOOTBALL_DATA_ORG_API_KEY="your-api-key"
FOOTBALL_DATA_ORG_BASE_URL="https://api.football-data.org/v4"
FOOTBALL_COMPETITION_CODE="WC"
LIVE_POLL_INTERVAL_SECONDS=60
IDLE_POLL_INTERVAL_SECONDS=600

# Email
RESEND_API_KEY="re_your_api_key"

# Admin
ADMIN_SEED_EMAIL="gerson.abimael.rp@gmail.com"
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "chore: update .env.example with Google OAuth, Resend, and ADMIN_SEED_EMAIL"
```
