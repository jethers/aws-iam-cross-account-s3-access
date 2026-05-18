variable "aws_region" {
  description = "Região AWS da Conta B"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile AWS CLI configurado para a Conta B"
  type        = string
  default     = "default"
}

variable "bucket_name" {
  description = "Nome do bucket S3 a ser criado na Conta B"
  type        = string

  validation {
    condition     = length(var.bucket_name) > 0
    error_message = "O bucket_name não pode ser vazio."
  }
}

variable "role_arn" {
  description = "ARN da IAM Role da Conta A que terá acesso ao bucket (ex: arn:aws:iam::ACCOUNT_ID_A:role/nome-da-role). Deixe vazio na primeira execução."
  type        = string
  default     = ""
}

variable "create_bucket_policy" {
  description = "Define se a bucket policy cross-account será criada. Defina como true somente após a IAM Role da Conta A ter sido provisionada."
  type        = bool
  default     = false
}
