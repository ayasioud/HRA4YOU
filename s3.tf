# Bucket S3 pour stocker le terraform.state partagé
# Terraform gère automatiquement :
#   - Si le bucket n'existe pas → il le crée
#   - Si le bucket est déjà dans le state → il ne le recrée pas
#   - Si le bucket existe dans AWS mais pas dans le state → terraform import

resource "aws_s3_bucket" "terraform_state" {
  bucket = "sopra-hra4you-tfstate"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "sopra-hra4you-tfstate"
  }
}

# Activer le versioning (pour garder l'historique du state)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bloquer l'accès public au bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Nom du bucket S3 pour le terraform state"
}
