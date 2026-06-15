# ============================================================
# FutFun — Secrets no Secret Manager
# Execute APOS setup-gcp.ps1
# Todos os valores já estão preenchidos — só rodar!
# ============================================================

$PROJECT_ID = (gcloud config get-value project)

Write-Host "Adicionando secrets ao projeto: $PROJECT_ID`n" -ForegroundColor Cyan

# ─────────────────────────────────────────────
# VALORES — já preenchidos
# ─────────────────────────────────────────────

$DATABASE_URL = "postgresql://neondb_owner:npg_9mCde8FcpvhX@ep-delicate-feather-ap9h2aug.c-7.us-east-1.aws.neon.tech/neondb?sslmode=require"

$JWT_SECRET = "066bfe9fe6ab6abe42d703084bcf262ccb73aeff4120fc1f60f694390c1831d7"

$GOOGLE_CLIENT_ID     = "999590228032-s4h8speqnvnc0fpn9da5g5pf1dtt15ft.apps.googleusercontent.com"
$GOOGLE_CLIENT_SECRET = "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"

$MICROSOFT_CLIENT_ID     = "ee767222-100c-4351-9e22-d83c7ce71f0d"
$MICROSOFT_CLIENT_SECRET = "5jr8Q~bqzkXBNI.s4v~zVlGO3GIHE2PsGE3uhc-r"
$MICROSOFT_TENANT_ID     = "common"

$FOOTBALL_API_KEY = "74dadc62ded04960a429d485573c8bf2"
$RESEND_API_KEY   = "re_FdMj8TPz_NLRQUwwM3uz2gjDVK8gAucUz"

$ADMIN_EMAIL = "gerson.abimael.rp@gmail.com"

# PREENCHER APOS O 1o DEPLOY — pegue a URL no console do Cloud Run
$APP_BASE_URL         = "PREENCHER_APOS_DEPLOY"
$CORS_ALLOWED_ORIGINS = "https://futfun-498118.web.app"

# ─────────────────────────────────────────────
# Cria os secrets
# ─────────────────────────────────────────────
function New-Secret {
  param($Name, $Value)
  $Value | gcloud secrets create $Name --data-file=- --project=$PROJECT_ID 2>$null
  if ($LASTEXITCODE -ne 0) {
    $Value | gcloud secrets versions add $Name --data-file=- --project=$PROJECT_ID
  }
  Write-Host "  OK $Name" -ForegroundColor Green
}

New-Secret "DATABASE_URL"              $DATABASE_URL
New-Secret "JWT_SECRET"                $JWT_SECRET
New-Secret "GOOGLE_CLIENT_ID"          $GOOGLE_CLIENT_ID
New-Secret "GOOGLE_CLIENT_SECRET"      $GOOGLE_CLIENT_SECRET
New-Secret "MICROSOFT_CLIENT_ID"       $MICROSOFT_CLIENT_ID
New-Secret "MICROSOFT_CLIENT_SECRET"   $MICROSOFT_CLIENT_SECRET
New-Secret "MICROSOFT_TENANT_ID"       $MICROSOFT_TENANT_ID
New-Secret "FOOTBALL_DATA_ORG_API_KEY" $FOOTBALL_API_KEY
New-Secret "RESEND_API_KEY"            $RESEND_API_KEY
New-Secret "ADMIN_SEED_EMAIL"          $ADMIN_EMAIL
New-Secret "APP_BASE_URL"              $APP_BASE_URL
New-Secret "CORS_ALLOWED_ORIGINS"      $CORS_ALLOWED_ORIGINS

Write-Host "`nSecrets criados!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Proximo passo - 1o deploy:" -ForegroundColor Yellow
Write-Host "  cd E:\source\personal\futfun"
Write-Host "  gcloud builds submit --config futfun-backend/cloudbuild.yaml ."
Write-Host ""
Write-Host "Apos o deploy, atualize APP_BASE_URL:" -ForegroundColor Yellow
Write-Host "  (URL do Cloud Run) | gcloud secrets versions add APP_BASE_URL --data-file=- --project=$PROJECT_ID"
