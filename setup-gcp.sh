#!/bin/bash
# ============================================================
# FutFun — GCP Setup Script
# Execute este script APÓS a billing account estar ativa
# Uso: bash setup-gcp.sh
# ============================================================

set -euo pipefail

# ─────────────────────────────────────────────
# CONFIGURAÇÕES — ajuste conforme necessário
# ─────────────────────────────────────────────
PROJECT_ID=$(gcloud config get-value project)
REGION="southamerica-east1"
DB_INSTANCE="futfun-db"
DB_NAME="futfun"
DB_USER="futfun"
DB_PASSWORD="$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)"
REDIS_INSTANCE="futfun-redis"
VPC_CONNECTOR="futfun-connector"
CLOUD_RUN_SERVICE="futfun-backend"

echo "=============================="
echo "FutFun GCP Setup"
echo "Projeto: $PROJECT_ID"
echo "Região:  $REGION"
echo "=============================="
echo ""

# ─────────────────────────────────────────────
# PASSO 1 — Habilitar APIs
# ─────────────────────────────────────────────
echo ">>> [1/7] Habilitando APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  vpcaccess.googleapis.com \
  containerregistry.googleapis.com \
  servicenetworking.googleapis.com \
  --project="$PROJECT_ID"
echo "✓ APIs habilitadas"

# ─────────────────────────────────────────────
# PASSO 2 — Cloud SQL (PostgreSQL 15)
# ─────────────────────────────────────────────
echo ""
echo ">>> [2/7] Criando Cloud SQL (PostgreSQL 15)..."
echo "    Isso leva ~5 minutos..."

gcloud sql instances create "$DB_INSTANCE" \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region="$REGION" \
  --storage-type=SSD \
  --storage-size=10GB \
  --no-backup \
  --project="$PROJECT_ID"

gcloud sql databases create "$DB_NAME" \
  --instance="$DB_INSTANCE" \
  --project="$PROJECT_ID"

gcloud sql users create "$DB_USER" \
  --instance="$DB_INSTANCE" \
  --password="$DB_PASSWORD" \
  --project="$PROJECT_ID"

# Pega o connection name
DB_CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE" \
  --project="$PROJECT_ID" \
  --format="value(connectionName)")

echo "✓ Cloud SQL criado: $DB_CONNECTION_NAME"
echo "  DB Password (SALVE AGORA): $DB_PASSWORD"

# ─────────────────────────────────────────────
# PASSO 3 — VPC Connector (necessário para Redis)
# ─────────────────────────────────────────────
echo ""
echo ">>> [3/7] Criando VPC Connector..."
gcloud compute networks vpc-access connectors create "$VPC_CONNECTOR" \
  --region="$REGION" \
  --range=10.8.0.0/28 \
  --project="$PROJECT_ID"
echo "✓ VPC Connector criado"

# ─────────────────────────────────────────────
# PASSO 4 — Memorystore Redis
# ─────────────────────────────────────────────
echo ""
echo ">>> [4/7] Criando Memorystore Redis (Basic, 1GB)..."
echo "    Isso leva ~5 minutos..."
gcloud redis instances create "$REDIS_INSTANCE" \
  --size=1 \
  --region="$REGION" \
  --redis-version=redis_7_0 \
  --tier=basic \
  --project="$PROJECT_ID"

REDIS_HOST=$(gcloud redis instances describe "$REDIS_INSTANCE" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(host)")
REDIS_PORT=$(gcloud redis instances describe "$REDIS_INSTANCE" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(port)")

echo "✓ Redis criado: $REDIS_HOST:$REDIS_PORT"

# ─────────────────────────────────────────────
# PASSO 5 — Secrets no Secret Manager
# ─────────────────────────────────────────────
echo ""
echo ">>> [5/7] Criando secrets no Secret Manager..."
echo "    ATENÇÃO: Você precisará preencher os valores abaixo."
echo ""

# Função helper para criar secret
create_secret() {
  local NAME=$1
  local VALUE=$2
  echo -n "$VALUE" | gcloud secrets create "$NAME" \
    --data-file=- \
    --project="$PROJECT_ID" 2>/dev/null || \
  echo -n "$VALUE" | gcloud secrets versions add "$NAME" \
    --data-file=- \
    --project="$PROJECT_ID"
  echo "  ✓ $NAME"
}

# Secrets automáticos (calculados acima)
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}?host=/cloudsql/${DB_CONNECTION_NAME}"
REDIS_URL="redis://${REDIS_HOST}:${REDIS_PORT}"

create_secret "DATABASE_URL" "$DATABASE_URL"
create_secret "REDIS_URL" "$REDIS_URL"

# Secrets manuais — VOCÊ PRECISA PREENCHER
echo ""
echo "==========================================="
echo "ATENÇÃO: Preencha as variáveis abaixo e"
echo "re-execute este bloco no seu terminal:"
echo "==========================================="
cat << 'MANUAL_SECRETS'

# Cole no terminal com seus valores reais:
PROJECT_ID=$(gcloud config get-value project)

gcloud secrets create JWT_SECRET \
  --data-file=<(echo -n "SEU_JWT_SECRET_MIN_32_CHARS") \
  --project="$PROJECT_ID"

gcloud secrets create GOOGLE_CLIENT_ID \
  --data-file=<(echo -n "SEU_GOOGLE_CLIENT_ID.apps.googleusercontent.com") \
  --project="$PROJECT_ID"

gcloud secrets create GOOGLE_CLIENT_SECRET \
  --data-file=<(echo -n "SEU_GOOGLE_CLIENT_SECRET") \
  --project="$PROJECT_ID"

gcloud secrets create MICROSOFT_CLIENT_ID \
  --data-file=<(echo -n "SEU_MICROSOFT_CLIENT_ID") \
  --project="$PROJECT_ID"

gcloud secrets create MICROSOFT_CLIENT_SECRET \
  --data-file=<(echo -n "SEU_MICROSOFT_CLIENT_SECRET") \
  --project="$PROJECT_ID"

gcloud secrets create MICROSOFT_TENANT_ID \
  --data-file=<(echo -n "common") \
  --project="$PROJECT_ID"

gcloud secrets create FOOTBALL_DATA_ORG_API_KEY \
  --data-file=<(echo -n "SUA_FOOTBALL_API_KEY") \
  --project="$PROJECT_ID"

gcloud secrets create RESEND_API_KEY \
  --data-file=<(echo -n "re_SUA_RESEND_KEY") \
  --project="$PROJECT_ID"

gcloud secrets create ADMIN_SEED_EMAIL \
  --data-file=<(echo -n "gerson.abimael.rp@gmail.com") \
  --project="$PROJECT_ID"

# APP_BASE_URL será o URL do Cloud Run — configure depois do 1º deploy
gcloud secrets create APP_BASE_URL \
  --data-file=<(echo -n "https://futfun-backend-XXXX-rj.a.run.app") \
  --project="$PROJECT_ID"

gcloud secrets create CORS_ALLOWED_ORIGINS \
  --data-file=<(echo -n "https://SEU_PROJETO.web.app") \
  --project="$PROJECT_ID"

MANUAL_SECRETS

# ─────────────────────────────────────────────
# PASSO 6 — IAM: Cloud Run SA acessa os secrets
# ─────────────────────────────────────────────
echo ""
echo ">>> [6/7] Configurando IAM para Cloud Run..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
CLOUD_RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CLOUD_RUN_SA}" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CLOUD_RUN_SA}" \
  --role="roles/cloudsql.client" \
  --quiet

echo "✓ IAM configurado para $CLOUD_RUN_SA"

# ─────────────────────────────────────────────
# PASSO 7 — Cloud Build Trigger
# ─────────────────────────────────────────────
echo ""
echo ">>> [7/7] Cloud Build Trigger..."
echo "    Configure manualmente no console ou via:"
echo ""
echo "    gcloud builds triggers create github \\"
echo "      --repo-name=futfun \\"
echo "      --repo-owner=SEU_GITHUB_USER \\"
echo "      --branch-pattern='^main$' \\"
echo "      --build-config=futfun-backend/cloudbuild.yaml \\"
echo "      --project=$PROJECT_ID"
echo ""

# ─────────────────────────────────────────────
# RESUMO FINAL
# ─────────────────────────────────────────────
echo ""
echo "============================================"
echo "SETUP CONCLUÍDO — Próximos passos:"
echo "============================================"
echo ""
echo "1. Preencha os secrets manuais acima (OAuth, APIs)"
echo ""
echo "2. Rode as migrations remotamente:"
echo "   Conecte via Cloud SQL Proxy e rode:"
echo "   npx prisma migrate deploy"
echo "   npx prisma db seed"
echo ""
echo "3. 1º Deploy manual:"
echo "   cd futfun-backend"
echo "   gcloud builds submit --config cloudbuild.yaml ."
echo ""
echo "4. Após 1º deploy, pegue o URL do Cloud Run e:"
echo "   - Atualize o secret APP_BASE_URL"
echo "   - Atualize CORS_ALLOWED_ORIGINS"
echo "   - Configure OAuth redirect URIs nos consoles Google/Microsoft"
echo ""
echo "5. Flutter web — Firebase Hosting:"
echo "   cd futfun-frontend"
echo "   # Substitua YOUR_FIREBASE_PROJECT_ID no .firebaserc"
echo "   flutter build web --dart-define=API_URL=https://SEU_CLOUD_RUN_URL"
echo "   firebase deploy"
echo ""
echo "DB Connection: $DB_CONNECTION_NAME"
echo "DB Password:   $DB_PASSWORD"
echo "Redis:         $REDIS_HOST:$REDIS_PORT"
echo ""
