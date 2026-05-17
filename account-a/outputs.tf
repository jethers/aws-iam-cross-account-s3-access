output "role_arn" {
  description = "ARN da IAM Role criada na Conta A — use este valor como role_arn no account-b"
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_name" {
  description = "Nome do Instance Profile associado à EC2"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "instance_id" {
  description = "ID da instância EC2 criada"
  value       = aws_instance.ec2.id
}

output "instance_public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.ec2.public_ip
}

output "security_group_id" {
  description = "ID do security group da instância EC2"
  value       = aws_security_group.ec2_sg.id
}

output "s3_vpc_endpoint_id" {
  description = "ID do VPC Gateway Endpoint para S3"
  value       = aws_vpc_endpoint.s3.id
}
