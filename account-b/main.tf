terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# -----------------------------------------------------------------
# Bucket S3
# -----------------------------------------------------------------
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  tags = {
    Name    = var.bucket_name
    Project = "aws-iam-cross-account-s3-access"
  }
}

# -----------------------------------------------------------------
# Bloquear acesso público ao bucket
# -----------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------
# Versionamento
# -----------------------------------------------------------------
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Disabled"
  }
}

# -----------------------------------------------------------------
# Bucket Policy: autoriza a IAM Role da Conta A como principal
# Criada somente quando create_bucket_policy = true e role_arn fornecido
# -----------------------------------------------------------------
resource "aws_s3_bucket_policy" "cross_account" {
  count  = var.create_bucket_policy && var.role_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.main.id

  # Garante que o bloqueio de acesso público seja aplicado antes da policy
  depends_on = [aws_s3_bucket_public_access_block.main]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountListBucket"
        Effect = "Allow"
        Principal = {
          AWS = var.role_arn
        }
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.main.arn]
      },
      {
        Sid    = "AllowCrossAccountObjectAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = ["${aws_s3_bucket.main.arn}/*"]
      }
    ]
  })
}
