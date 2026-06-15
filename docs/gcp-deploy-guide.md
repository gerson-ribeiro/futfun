# FutFun — GCP Deployment Guide

**Stack:** Cloud Run (backend) + Cloud SQL PostgreSQL + Upstash Redis + Firebase Hosting (Flutter web) + Firebase App Distribution (Android APK)

**Custo estimado:** ~$13-18/mês (Upstash Redis grátis, Cloud SQL $8, Cloud Run ~$5-10)

---

## Pré-requisito: instalar gcloud CLI

Baixe e instale: https://cloud.google.com/sdk/docs/install

Depois reinicie o terminal.

---

## Passo 1 — Criar projeto GCP

```bash
gcloud auth login

gcloud projects create futfun-prod --name="FutFun Production"
gcloud config set project futfun-prod
```

**Manual no console:** Vincule uma conta de cobrança (obrigatório):
- https://console.cloud.google.com/billing
- Billing → Manage billing accounts → selecione a sua → Projects → link `futfun-prod`

---

## Passo 2 — Habilitar APIs

```bash
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com
```

---

## Passo 3 — Cloud SQL (PostgreSQL 16, ~$8/mês)

```bash
# Criar instância
gcloud sql instances create futfun-db \
  --database-version=POSTGRES_16 \
  --tier=db-f1-micro \
  --region=southamerica-east1 \
  --storage-size=10GB \
  --storage-type=SSD

# Criar banco de dados
gcloud sql databases create futfun --instance=futfun-db

# Criar usuário (escolha uma senha forte)
gcloud sql users create futfun_user \
  --instance=futfun-db \
  --password=SENHA_FORTE_AQUI

# Anotar o connection name (necessário na DATABASE_URL)
gcloud sql instances describe futfun-db --format='value(connectionName)'
# Saída esperada: futfun-prod:southamerica-east1:futfun-db
```

**DATABASE_URL** para usar no Secret Manager (passo 5):
```
postgresql://futfun_user:SENHA@/futfun?host=/cloudsql/futfun-prod:southamerica-east1:futfun-db
```

---

## Passo 4 — Redis com Upstash (grátis, sem VPC)

1. Crie conta em: https://console.upstash.com
2. Create Database → Region: **South America (São Paulo)** → TLS: ON
3. Copie a Redis URL no formato: `rediss://default:PASSWORD@host.upstash.io:PORT`

> Isso elimina o custo de ~$35/mês do Memorystore e não precisa de VPC connector.

---

## Passo 5 — Criar secrets no Secret Manager

Execute um por um, substituindo pelos valores reais do seu `.env`:

```bash
# Banco de dados (socket Cloud SQL — não usar IP)
echo -n "postgresql://futfun_user:SENHA@/futfun?host=/cloudsql/futfun-prod:southamerica-east1:futfun-db" \
  | gcloud secrets create DATABASE_URL --data-file=-

# Redis (URL do Upstash)
echo -n "rediss://default:PASSWORD@host.upstash.io:PORT" \
  | gcloud secrets create REDIS_URL --data-file=-

# JWT
echo -n "seu-jwt-secret-minimo-32-chars" \
  | gcloud secrets create JWT_SECRET --data-file=-

# OAuth Google
echo -n "seu-google-client-id.apps.googleusercontent.com" \
  | gcloud secrets create GOOGLE_CLIENT_ID --data-file=-
echo -n "seu-google-client-secret" \
  | gcloud secrets create GOOGLE_CLIENT_SECRET --data-file=-

# OAuth Microsoft
echo -n "seu-microsoft-client-id" \
  | gcloud secrets create MICROSOFT_CLIENT_ID --data-file=-
echo -n "seu-microsoft-client-secret" \
  | gcloud secrets create MICROSOFT_CLIENT_SECRET --data-file=-
echo -n "common" \
  | gcloud secrets create MICROSOFT_TENANT_ID --data-file=-

# Football Data API
echo -n "sua-api-key" \
  | gcloud secrets create FOOTBALL_DATA_ORG_API_KEY --data-file=-

# Resend (email)
echo -n "re_sua_api_key" \
  | gcloud secrets create RESEND_API_KEY --data-file=-

# App config
echo -n "gerson.abimael.rp@gmail.com" \
  | gcloud secrets create ADMIN_SEED_EMAIL --data-file=-

# Preencher depois de fazer o deploy (passo 8)
echo -n "https://futfun-backend-HASH-ue.a.run.app" \
  | gcloud secrets create APP_BASE_URL --data-file=-

# URL do Flutter web (Firebase Hosting)
echo -n "https://futfun-prod.web.app" \
  | gcloud secrets create CORS_ALLOWED_ORIGINS --data-file=-
```

---

## Passo 6 — Permissões do Cloud Run

```bash
PROJECT_NUMBER=$(gcloud projects describe futfun-prod --format='value(projectNumber)')
SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# Acesso aos secrets
gcloud projects add-iam-policy-binding futfun-prod \
  --member="serviceAccount:${SA}" \
  --role="roles/secretmanager.secretAccessor"

# Acesso ao Cloud SQL
gcloud projects add-iam-policy-binding futfun-prod \
  --member="serviceAccount:${SA}" \
  --role="roles/cloudsql.client"
```

---

## Passo 7 — Rodar migrations no Cloud SQL (via proxy local)

### 7a. Baixar o Cloud SQL Auth Proxy (Windows)

```powershell
# PowerShell
Invoke-WebRequest -Uri "https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.11.0/cloud-sql-proxy.x64.exe" -OutFile "cloud-sql-proxy.exe"
```

### 7b. Autenticar com Application Default Credentials

```bash
gcloud auth application-default login
```

### 7c. Rodar o proxy (aba separada do terminal)

```bash
./cloud-sql-proxy.exe futfun-prod:southamerica-east1:futfun-db --port 5433
```

### 7d. Rodar migrations e seed (outra aba)

**Windows CMD:**
```cmd
set DATABASE_URL=postgresql://futfun_user:SENHA@localhost:5433/futfun
cd E:\source\personal\futfun\futfun-backend
npx prisma migrate deploy
npx tsx prisma/seed.ts
```

**Windows PowerShell:**
```powershell
$env:DATABASE_URL = "postgresql://futfun_user:SENHA@localhost:5433/futfun"
cd E:\source\personal\futfun\futfun-backend
npx prisma migrate deploy
npx tsx prisma/seed.ts
```

---

## Passo 8 — Primeiro deploy do backend (Cloud Run)

```bash
cd E:\source\personal\futfun\futfun-backend

# Build e push da imagem para o Container Registry
gcloud builds submit \
  --tag gcr.io/futfun-prod/futfun-backend:latest \
  .

# Deploy no Cloud Run
gcloud run deploy futfun-backend \
  --image gcr.io/futfun-prod/futfun-backend:latest \
  --region southamerica-east1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --add-cloudsql-instances futfun-prod:southamerica-east1:futfun-db \
  --set-env-vars="NODE_ENV=production,JWT_ACCESS_EXPIRES_IN=15m,JWT_REFRESH_EXPIRES_IN=7d,LIVE_POLL_INTERVAL_SECONDS=60,IDLE_POLL_INTERVAL_SECONDS=600,FOOTBALL_DATA_ORG_BASE_URL=https://api.football-data.org/v4,APP_DEEP_LINK_SCHEME=futfun" \
  --set-secrets="DATABASE_URL=DATABASE_URL:latest,REDIS_URL=REDIS_URL:latest,JWT_SECRET=JWT_SECRET:latest,GOOGLE_CLIENT_ID=GOOGLE_CLIENT_ID:latest,GOOGLE_CLIENT_SECRET=GOOGLE_CLIENT_SECRET:latest,MICROSOFT_CLIENT_ID=MICROSOFT_CLIENT_ID:latest,MICROSOFT_CLIENT_SECRET=MICROSOFT_CLIENT_SECRET:latest,MICROSOFT_TENANT_ID=MICROSOFT_TENANT_ID:latest,FOOTBALL_DATA_ORG_API_KEY=FOOTBALL_DATA_ORG_API_KEY:latest,RESEND_API_KEY=RESEND_API_KEY:latest,ADMIN_SEED_EMAIL=ADMIN_SEED_EMAIL:latest,APP_BASE_URL=APP_BASE_URL:latest,CORS_ALLOWED_ORIGINS=CORS_ALLOWED_ORIGINS:latest"
```

**Após o deploy:** O Cloud Run te dará uma URL como `https://futfun-backend-xxxxx-ue.a.run.app`.

Atualize o secret `APP_BASE_URL` com essa URL real:
```bash
echo -n "https://futfun-backend-xxxxx-ue.a.run.app" \
  | gcloud secrets versions add APP_BASE_URL --data-file=-

# Refaça o deploy para pegar o novo secret
gcloud run deploy futfun-backend \
  --image gcr.io/futfun-prod/futfun-backend:latest \
  --region southamerica-east1
```

---

## Passo 9 — Flutter Web (Firebase Hosting)

### 9a. Instalar Firebase CLI e fazer login

```bash
npm install -g firebase-tools
firebase login
```

### 9b. Inicializar Firebase no projeto frontend

```bash
cd E:\source\personal\futfun\futfun-frontend
firebase init
```

Selecionar: **Hosting**
- Projeto: `futfun-prod`
- Public directory: `build/web`
- Single-page app: **Yes**
- Overwrite `index.html`: **No**

> O `firebase.json` já está criado no projeto — basta confirmar quando perguntar se quer sobrescrever.

### 9c. Substituir o placeholder no .firebaserc

Editar `futfun-frontend/.firebaserc`:
```json
{
  "projects": {
    "default": "futfun-prod"
  }
}
```

### 9d. Build e deploy

```bash
cd E:\source\personal\futfun\futfun-frontend

flutter build web --release \
  --web-renderer canvaskit \
  --dart-define=API_URL=https://futfun-backend-xxxxx-ue.a.run.app

firebase deploy --only hosting
```

URL do app web: `https://futfun-prod.web.app`

---

## Passo 10 — Android (Firebase App Distribution)

Para builds automáticos via GitHub Actions, configure os seguintes secrets no repositório GitHub:

| Secret | Descrição |
|--------|-----------|
| `FIREBASE_SERVICE_ACCOUNT` | JSON da conta de serviço do Firebase |
| `FIREBASE_ANDROID_APP_ID` | ID do app Android (ex: `1:123456789:android:abc123`) |
| `API_URL` | URL do Cloud Run |
| `KEYSTORE_BASE64` | Keystore `.jks` encodado em base64 |
| `KEYSTORE_PASSWORD` | Senha do keystore |
| `KEY_ALIAS` | Alias da chave |
| `KEY_PASSWORD` | Senha da chave |

**Para obter `FIREBASE_ANDROID_APP_ID`:**
1. Firebase Console → Project Settings → Your apps → adicionar app Android
2. Package name: `com.futfun.app` (verificar em `android/app/build.gradle`)
3. Baixar `google-services.json` → colocar em `android/app/`
4. Copiar o App ID mostrado na tela

**Para gerar o keystore (primeira vez):**
```bash
keytool -genkey -v -keystore futfun-release.jks \
  -alias futfun -keyalg RSA -keysize 2048 -validity 10000

# Converter para base64
base64 -w 0 futfun-release.jks
```

**Para deploy manual sem GitHub Actions:**
```bash
cd E:\source\personal\futfun\futfun-frontend

flutter build apk --release \
  --dart-define=API_URL=https://futfun-backend-xxxxx-ue.a.run.app

# Instalar Firebase CLI e fazer upload
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app "SEU_FIREBASE_ANDROID_APP_ID" \
  --groups testers \
  --release-notes "Build manual"
```

---

## Atualizações futuras (re-deploy)

Após qualquer mudança no backend:

```bash
cd E:\source\personal\futfun\futfun-backend

gcloud builds submit --tag gcr.io/futfun-prod/futfun-backend:latest .
gcloud run deploy futfun-backend \
  --image gcr.io/futfun-prod/futfun-backend:latest \
  --region southamerica-east1
```

Ou conecte o Cloud Build ao GitHub para deploy automático em push para `main` (o `cloudbuild.yaml` já está pronto em `futfun-backend/cloudbuild.yaml`):
- Console GCP → Cloud Build → Triggers → Connect Repository → GitHub

---

## Checklist de verificação pós-deploy

- [ ] `GET https://seu-backend.run.app/api/competitions` retorna WC e CLI
- [ ] Login OAuth Google/Microsoft redireciona corretamente para o deep link
- [ ] Flutter web carrega em `https://futfun-prod.web.app`
- [ ] Admin consegue entrar em `/admin/competitions` e habilitar/desabilitar
- [ ] Match sync job roda (ver logs no Cloud Run)

---

## Resumo de custos

| Serviço | Tier | Custo/mês |
|---------|------|-----------|
| Cloud Run | 0-3 instâncias, auto-scale to 0 | ~$5-10 |
| Cloud SQL | db-f1-micro, 10GB | ~$8 |
| Upstash Redis | Free tier | **Grátis** |
| Firebase Hosting | Free tier | **Grátis** |
| Secret Manager | ~13 secrets | ~$0 |
| **Total** | | **~$13-18** |
