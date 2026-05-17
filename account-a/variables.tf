variable "aws_region" {
  description = "Região AWS da Conta A"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile AWS CLI configurado para a Conta A"
  type        = string
  default     = "default"
}

variable "ami_id" {
  description = "ID da AMI para a instância EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"
}

variable "bucket_arn" {
  description = "ARN do bucket S3 na Conta B (ex: arn:aws:s3:::nome-do-bucket)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.bucket_arn))
    error_message = "O bucket_arn deve ser um ARN válido de bucket S3 (ex: arn:aws:s3:::nome-do-bucket)."
  }
}

variable "role_name" {
  description = "Nome da IAM Role a ser criada"
  type        = string
  default     = "ec2-cross-account-s3-role"
}

variable "instance_name" {
  description = "Tag Name da instância EC2"
  type        = string
  default     = "ec2-cross-account"
}

variable "vpc_id" {
  description = "ID da VPC onde a instância será criada. Se vazio, usa a VPC default."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "ID da subnet pública onde a instância será criada. Se vazio, usa a subnet default."
  type        = string
  default     = ""
}
