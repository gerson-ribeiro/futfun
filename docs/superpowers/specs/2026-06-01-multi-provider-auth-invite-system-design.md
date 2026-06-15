# Design: Multi-Provider Auth + Invite System

**Data:** 2026-06-01  
**Status:** Aprovado  
**Projeto:** FutFun — Bolão Copa do Mundo 2026  

---

## Contexto

O FutFun foi inicialmente concebido como um app corporativo com autenticação exclusiva via Azure AD. O escopo foi expandido para uma **plataforma pública**, aberta a qualquer pessoa. As mudanças centrais são:

1. Suporte a **Google OAuth e Microsoft OAuth** (multi-provider)
2. **Remoção da camada de senha extra** — confiança direta no JWT pós-OAuth
3. **Sistema de convites por email** — admin envia link individual (7 dias de validade)
4. **Roles de usuário** — ADMIN, MEMBER, PENDING
5. **Fluxo de aprovação** — usuários sem convite ficam PENDING até aprovação do admin
6. **Admin panel** — telas de gerenciamento de usuários e envio de convites

---

## Arquitetura Geral

```
Flutter App
  │
  ├─ LoginScreen  ──→  GET /api/auth/google/login    ──→ redirect Google
  │                    GET /api/auth/microsoft/login  ──→ redirect Microsoft
  │
  ├─ InviteScreen ──→  GET /api/invites/:token        ──→ valida convite
  │                    (abre via deep link: futfun://invite?token=xxx)
  │
  ├─ OAuth callback retorna para:
  │    GET /api/auth/callback?provider=google|microsoft&code=...&state=...
  │         │
  │         └─ OAuthCallbackHandler (application layer)
  │               ├─ IOAuthProvider (Google ou Microsoft via factory)
  │               ├─ Busca/cria User → define role por lógica de invite/seed
  │               └─ Emite JWT { userId, email, role } + refresh token (Redis)
  │
  ├─ role=ADMIN|MEMBER  →  app normal
  └─ role=PENDING       →  PendingApprovalScreen
```

### Porta unificada `IOAuthProvider`

```typescript
interface OAuthUserInfo {
  providerId: string;
  email: string;
  displayName: string;
}

interface IOAuthProvider {
  getAuthorizationUrl(state: string): string;
  exchangeCodeForTokens(code: string): Promise<OAuthTokens>;
  getUserInfo(accessToken: string): Promise<OAuthUserInfo>;
}
```

`GoogleOAuthService` e `MicrosoftOAuthService` implementam essa interface. O `OAuthCallbackHandler` opera exclusivamente sobre a interface — não conhece o provider concreto.

---

## Schema do Banco (Prisma)

### Model `User` — alterado

```prisma
model User {
  id            String      @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  provider      String      // "google" | "microsoft"
  providerId    String      // ID único retornado pelo provider
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

enum UserRole {
  PENDING   // logou mas aguarda aprovação do admin
  MEMBER    // aprovado, pode palpitar
  ADMIN     // gerencia usuários e convites
}
```

**Campos removidos:** `microsoftId`, `tenantId`, `passwordHash`, `isPasswordSet`

### Model `Invite` — novo

```prisma
model Invite {
  id          String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  email       String
  token       String    @unique   // UUID v4, usado na URL do convite
  expiresAt   DateTime            // createdAt + 7 dias
  usedAt      DateTime?           // null = não utilizado ainda
  createdBy   String    @db.Uuid
  createdAt   DateTime  @default(now())

  creator     User      @relation(fields: [createdBy], references: [id])

  @@index([token])
  @@index([email])
  @@map("invites")
}
```

### Admin inicial

Como `provider` e `providerId` só são conhecidos no primeiro login OAuth, não é possível pré-criar o usuário via Prisma seed. A solução é uma variável de ambiente `ADMIN_SEED_EMAIL`:

```bash
ADMIN_SEED_EMAIL="gerson.abimael.rp@gmail.com"
```

No `OAuthCallbackHandler`, ao criar um novo usuário, se `userInfo.email === process.env.ADMIN_SEED_EMAIL` → `role = ADMIN`. O registro é criado no banco na primeira vez que esse email faz login com Google ou Microsoft.

---

## Fluxo de Auth

### Rotas

```
GET  /api/auth/google/login         → retorna { authUrl }
GET  /api/auth/microsoft/login      → retorna { authUrl }
GET  /api/auth/callback             → ?provider=google|microsoft&code=...&state=...
POST /api/auth/refresh              → { refreshToken } → { accessToken }
POST /api/auth/logout               → invalida refresh token no Redis
```

### Sequência do callback unificado

```
1. Valida presença de `provider` e `code`
2. Cria instância via OAuthProviderFactory(provider)
3. exchangeCodeForTokens(code) → tokens
4. getUserInfo(accessToken) → { providerId, email, displayName }
5. Verifica se `state` contém invite token (formato: `invite:<token>` ou `""` para login normal)
6. Busca User por (provider, providerId)
   ├─ Não existe?
   │    ├─ Email = "gerson.abimael.rp@gmail.com" → role = ADMIN
   │    ├─ state contém invite token válido (não expirado, não usado) → role = MEMBER, marca usedAt
   │    └─ Senão → role = PENDING
   │    └─ Cria User
   └─ Existe? → atualiza lastLoginAt
7. Gera JWT { userId, email, role, iat, exp: +15min }
8. Gera refresh token (UUID v4) → Redis SETEX 7d
9. Retorna { accessToken, refreshToken, user: { id, email, displayName, role } }
```

### JWT payload

```typescript
interface TokenPayload {
  userId: string;
  email: string;
  role: 'PENDING' | 'MEMBER' | 'ADMIN';
  iat: number;
  exp: number;
}
```

---

## Sistema de Convites

### Fluxo do admin

```
POST /api/admin/invites  { email }
  1. Valida email
  2. Verifica que não existe User ativo com esse email
  3. Cria Invite { token: uuidv4(), expiresAt: now+7d }
  4. Envia email via Resend (template "invite")
  5. Retorna { invite: { id, email, expiresAt } }
```

### Fluxo do convidado

```
1. Clica no link: https://app.futfun.com/invite?token=<token>
2. App abre InviteScreen via deep link
3. GET /api/invites/:token → valida token (público, sem auth)
   ├─ Válido   → exibe "Você foi convidado! Entre com Google ou Microsoft"
   └─ Inválido → exibe mensagem de erro (expirado ou já usado)
4. Usuário escolhe provider → login OAuth com state=inviteToken
5. Callback unificado detecta state → cria User com role=MEMBER
```

### Rotas de convites

```
GET    /api/invites/:token          → valida token (público)
POST   /api/admin/invites           → cria e envia convite (ADMIN)
GET    /api/admin/invites           → lista convites (ADMIN)
DELETE /api/admin/invites/:id       → cancela convite não usado (ADMIN)
```

---

## Admin Panel

### Rotas de gerenciamento de usuários

```
GET    /api/admin/users              → lista todos usuários
PATCH  /api/admin/users/:id/role     → { role: 'MEMBER' | 'ADMIN' | 'PENDING' }
DELETE /api/admin/users/:id          → remove usuário
```

**Aprovação:** `PATCH role=MEMBER` → envia email de aprovação via Resend  
**Rejeição:** `DELETE /api/admin/users/:id`

**Middleware `withAdmin`:** verifica JWT + `role === 'ADMIN'` em todos os endpoints `/api/admin/*`. Retorna 403 caso contrário.

---

## Email (Resend)

### Interface

```typescript
interface IEmailService {
  sendInvite(to: string, inviteToken: string, inviterName: string): Promise<void>;
  sendApprovalNotification(to: string, displayName: string): Promise<void>;
}
```

### Templates

| Template | Assunto | Conteúdo |
|---|---|---|
| `invite` | "Você foi convidado para o FutFun ⚽" | Link válido por 7 dias + botões de login |
| `approval` | "Seu acesso ao FutFun foi aprovado! ⚽" | Boas-vindas + link para o app |

### Variáveis de ambiente

**Novas:**
```bash
GOOGLE_CLIENT_ID="xxxx.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="xxxx"
RESEND_API_KEY="re_xxxx"
APP_BASE_URL="https://app.futfun.com"
ADMIN_SEED_EMAIL="gerson.abimael.rp@gmail.com"
```

**Alteradas:**
```bash
# MICROSOFT_REDIRECT_URI muda para:
MICROSOFT_REDIRECT_URI="https://api.futfun.com/api/auth/callback?provider=microsoft"
MICROSOFT_TENANT_ID="common"   # era específico de tenant, agora aceita qualquer conta Microsoft
```

**Google redirect URI:**
```bash
# Não vira env var separada — é construída no código:
# APP_BASE_URL + /api/auth/callback?provider=google
```

**Removidas:**
```bash
MICROSOFT_REDIRECT_URI_OLD  # substituída pela nova acima
```

---

## Frontend (Flutter)

### Mudanças nas telas existentes

**`LoginScreen`:** dois botões OAuth, sem referência a senha
```
[ G  Entrar com Google    ]
[ ⊞  Entrar com Microsoft ]
```

**`AuthViewModel`:** simplificado — estados: `unauthenticated` | `loading` | `authenticated` | `pending`  
Removidos: `awaitingPassword`, `awaitingPasswordSetup`, `setupPassword()`, `verifyPassword()`

**`AuthRepository`:** rename `getMicrosoftLoginUrl` → `getLoginUrl(provider)`, remove `exchangeCallback`, `setupPassword`, `verifyPassword`

### Novas telas

| Tela | Rota | Descrição |
|---|---|---|
| `PendingApprovalScreen` | `/pending` | "Aguardando aprovação" + botão logout |
| `InviteScreen` | `/invite` | Valida token, exibe botões OAuth |
| `AdminUsersScreen` | `/admin/users` | Abas: Pendentes / Membros / Admins + ações |
| `AdminInvitesScreen` | `/admin/invites` | Campo email + lista de invites |

### GoRouter

```
/                 → redireciona baseado no role do JWT
/login            → LoginScreen (público)
/invite           → InviteScreen (público)
/pending          → PendingApprovalScreen (role=PENDING)
/home             → ShellRoute (MEMBER + ADMIN)
  /matches
  /ranking
  /dashboard
/admin            → AdminShellRoute (ADMIN only)
  /admin/users
  /admin/invites
```

### Pacotes

**Novos:** `app_links` (deep link para invite token)  
**Removidos:** fluxo de senha (`setup-password`, `verify-password`)  
**Mantidos:** `url_launcher`, `flutter_secure_storage`, `dio`, `riverpod`, `go_router`

---

## Fases de Implementação

1. **Schema:** migração Prisma (User + Invite + enum)
2. **Backend auth:** `IOAuthProvider`, `GoogleOAuthService`, refactor `MicrosoftOAuthService`, `OAuthCallbackHandler`, novas rotas
3. **Backend admin:** rotas `/api/admin/*` + `withAdmin` middleware + `ResendEmailService`
4. **Frontend auth:** `LoginScreen` dual-provider, `AuthViewModel` simplificado, `PendingApprovalScreen`, `InviteScreen`, deep links
5. **Frontend admin:** `AdminUsersScreen`, `AdminInvitesScreen`, `AdminShellRoute`
6. **Seed + env:** seed do admin inicial, template de `.env`
