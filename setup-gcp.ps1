# ============================================================
# FutFun — GCP Setup Script (PowerShell)
# Arquitetura MVP: Cloud Run + Neon.tech (PostgreSQL)
# Sem Redis, sem Cloud SQL, sem VPC Connector
# Execute APÓS a billing account estar ativa
# Uso: .\setup-gcp.ps1
# ============================================================

$ErrorActionPreference = "Stop"

$PROJECT_ID = (gcloud config get-value project)
$REGION     = "southamerica-east1"

Write-Host "==============================" -ForegroundColor Cyan
Write-Host "FutFun GCP Setup (MVP)"
Write-Host "Projeto: $PROJECT_ID"
Write-Host "Regiao:  $REGION"
Write-Host "Banco:   Neon.tech (externo)"
Write-Host "==============================`n" -ForegroundColor Cyan

# ─────────────────────────────────────────────
# PASSO 1 — Habilitar APIs (sem SQL, sem Redis, sem VPC)
# ─────────────────────────────────────────────
Write-Host ">>> [1/4] Habilitando APIs..." -ForegroundColor Yellow
gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com containerregistry.googleapis.com --project=$PROJECT_ID
Write-Host "OK APIs habilitadas`n" -ForegroundColor Green

# ─────────────────────────────────────────────
# PASSO 2 — IAM para Cloud Run acessar secrets
# ─────────────────────────────────────────────
Write-Host ">>> [2/4] Configurando IAM..." -ForegroundColor Yellow
$PROJECT_NUMBER = (gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
$CLOUD_RUN_SA   = "${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:${CLOUD_RUN_SA}" `
  --role="roles/secretmanager.secretAccessor" `
  --quiet

Write-Host "OK IAM configurado para $CLOUD_RUN_SA`n" -ForegroundColor Green

# ─────────────────────────────────────────────
# PASSO 3 — Lembrete: criar banco no Neon.tech
# ─────────────────────────────────────────────
Write-Host ">>> [3/4] ACAO MANUAL NECESSARIA:" -ForegroundColor Magenta
Write-Host ""
Write-Host "   1. Acesse: https://neon.tech"
Write-Host "   2. Crie uma conta gratuita"
Write-Host "   3. Crie um projeto chamado 'futfun'"
Write-Host "   4. Copie a connection string (formato: postgresql://user:pass@host/dbname?sslmode=require)"
Write-Host "   5. Execute .\setup-gcp-secrets.ps1 com essa connection string"
Write-Host ""

# ─────────────────────────────────────────────
# PASSO 4 — Instrucao de deploy
# ─────────────────────────────────────────────
Write-Host ">>> [4/4] Apos configurar os secrets, faca o deploy:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   cd futfun-backend"
Write-Host "   gcloud builds submit --config cloudbuild.yaml ."
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Setup base concluido!"
Write-Host "Proximo passo: .\setup-gcp-secrets.ps1"
Write-Host "============================================" -ForegroundColor Cyan
