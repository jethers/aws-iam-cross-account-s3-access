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
# IAM Role com trust policy para EC2
# -----------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = var.role_name
    Project = "aws-iam-cross-account-s3-access"
  }
}

# -----------------------------------------------------------------
# Permission Policy: acesso cross-account ao bucket S3 da Conta B
# -----------------------------------------------------------------
resource "aws_iam_policy" "s3_cross_account_policy" {
  name        = "${var.role_name}-s3-policy"
  description = "Permite acesso de leitura, escrita e listagem no bucket S3 da Conta B"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.bucket_arn]
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = ["${var.bucket_arn}/*"]
      }
    ]
  })
}

# -----------------------------------------------------------------
# Anexa a policy à role
# -----------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_cross_account_policy.arn
}

# -----------------------------------------------------------------
# Instance Profile para associar a role à EC2
# -----------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.role_name}-profile"
  role = aws_iam_role.ec2_role.name
}

# -----------------------------------------------------------------
# IPs do serviço EC2 Instance Connect para a região configurada
# Usado para liberar porta 22 somente para os ranges da AWS
# -----------------------------------------------------------------
data "aws_ip_ranges" "ec2_instance_connect" {
  regions  = [var.aws_region]
  services = ["EC2_INSTANCE_CONNECT"]
}

# -----------------------------------------------------------------
# Security Group — libera porta 22 apenas para IPs do EC2 Instance Connect
# Sem egress irrestrito: S3 roteia via VPC Gateway Endpoint (sem saída pela internet)
# -----------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group da instancia EC2 cross-account"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : null

  ingress {
    description = "SSH via EC2 Instance Connect (IPs gerenciados pela AWS para a regiao ${var.aws_region})"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = data.aws_ip_ranges.ec2_instance_connect.cidr_blocks
  }

  egress {
    description = "Saida HTTPS para endpoints AWS (S3 via VPC Gateway Endpoint, demais servicos AWS)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.instance_name}-sg"
    Project   = "aws-iam-cross-account-s3-access"
    SyncToken = data.aws_ip_ranges.ec2_instance_connect.sync_token
  }
}

# -----------------------------------------------------------------
# Instância EC2
# -----------------------------------------------------------------
resource "aws_instance" "ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id                   = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]

  tags = {
    Name    = var.instance_name
    Project = "aws-iam-cross-account-s3-access"
  }
}

# -----------------------------------------------------------------
# Dados da VPC e route table para o Gateway Endpoint
# Se vpc_id não for fornecido, busca a VPC default
# -----------------------------------------------------------------
data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : null
}

data "aws_route_tables" "selected" {
  vpc_id = data.aws_vpc.selected.id

  filter {
    name   = "association.subnet-id"
    values = [var.subnet_id != "" ? var.subnet_id : aws_instance.ec2.subnet_id]
  }
}

# -----------------------------------------------------------------
# VPC Gateway Endpoint para S3
# Garante que o tráfego EC2 → S3 não saia pela internet
# -----------------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.selected.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.selected.ids

  tags = {
    Name    = "s3-gateway-endpoint"
    Project = "aws-iam-cross-account-s3-access"
  }
}
