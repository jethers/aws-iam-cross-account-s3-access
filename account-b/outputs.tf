output "bucket_arn" {
  description = "ARN do bucket S3 criado na Conta B — use este valor como bucket_arn no account-a"
  value       = aws_s3_bucket.main.arn
}

output "bucket_name" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_domain_name" {
  description = "Domain name do bucket S3"
  value       = aws_s3_bucket.main.bucket_domain_name
}
