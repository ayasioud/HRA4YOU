# Usage: .\deploy.ps1

$ErrorActionPreference = "Stop"

$BUCKET_NAME = "sopra-hra4you-tfstate"
$REGION = "eu-west-3"
$env:AWS_PROFILE = "sopra-sso"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "    HRA4YOU - Deploiement Automatique    " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan


Write-Host ""
Write-Host "Etape 1 : Verification du bucket S3..." -ForegroundColor Yellow

$bucketExists = $false
try {
    aws s3api head-bucket --bucket $BUCKET_NAME 2>$null
    Write-Host " Bucket S3 '$BUCKET_NAME' existe deja" -ForegroundColor Green
    $bucketExists = $true
} catch {
    Write-Host "  Bucket S3 '$BUCKET_NAME' n'existe pas → Creation..." -ForegroundColor Yellow

    aws s3api create-bucket `
        --bucket $BUCKET_NAME `
        --region $REGION `
        --create-bucket-configuration LocationConstraint=$REGION

    aws s3api put-bucket-versioning `
        --bucket $BUCKET_NAME `
        --versioning-configuration Status=Enabled

    Write-Host " Bucket S3 cree avec succes" -ForegroundColor Green
    $bucketExists = $false
}


Write-Host ""
Write-Host "Etape 2 : Configuration du backend Terraform..." -ForegroundColor Yellow

$backendContent = @"
# Configuration du Remote Backend sur AWS S3
terraform {
  backend "s3" {
    bucket       = "sopra-hra4you-tfstate"
    key          = "sopra-hra4you/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
    profile      = "sopra-sso"
  }
}
"@

Set-Content -Path "backend.tf" -Value $backendContent
Write-Host "backend.tf configure" -ForegroundColor Green


Write-Host ""
Write-Host "Etape 3 : Initialisation de Terraform..." -ForegroundColor Yellow

if ($bucketExists -eq $false) {
    terraform init -migrate-state -force-copy
} else {
    terraform init
}

Write-Host " Terraform initialise" -ForegroundColor Green

Write-Host ""
Write-Host "Etape 3.5 : Verification du state du bucket S3..." -ForegroundColor Yellow

$stateList = terraform state list 2>$null
if ($stateList -notcontains "aws_s3_bucket.terraform_state") {
    Write-Host "  Bucket non trouvé dans le state → Import automatique..." -ForegroundColor Yellow
    terraform import aws_s3_bucket.terraform_state $BUCKET_NAME
    Write-Host " Bucket importé dans le state" -ForegroundColor Green
} else {
    Write-Host " Bucket déjà dans le state" -ForegroundColor Green
}


Write-Host ""
Write-Host "Etape 4 : Deploiement de l'infrastructure..." -ForegroundColor Yellow

terraform apply -auto-approve

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " Deploiement termine avec succes !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
