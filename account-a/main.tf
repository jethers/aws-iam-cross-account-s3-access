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
# Anexa a policy gerenciada da AWS para SSM Session Manager
# Permite conectar na instância via console sem precisar de SSH/porta 22
# -----------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
# e permite saída irrestrita (necessário para SSM e S3)
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
    description = "Saida irrestrita para internet (necessario para SSM e S3)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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
