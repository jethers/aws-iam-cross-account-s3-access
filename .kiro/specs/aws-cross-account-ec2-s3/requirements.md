# Requirements Document

## Introduction

This feature provisions Terraform infrastructure across two AWS accounts to allow an EC2 instance in Account A to securely access an S3 bucket in Account B via IAM cross-account access. The solution uses an IAM Role attached to the EC2 instance with explicit read, write, and list permissions on the remote bucket, combined with a bucket policy on Account B's side that authorizes the Account A principal. All S3 traffic is routed through a VPC Gateway Endpoint, ensuring it never traverses the public internet.

## Glossary

- **Account_A**: AWS account that hosts the EC2 instance and the IAM Role.
- **Account_B**: AWS account that hosts the target S3 bucket.
- **EC2_Instance**: Amazon EC2 instance provisioned in Account A.
- **IAM_Role**: IAM Role attached to the EC2_Instance via an instance profile, with cross-account permissions to the S3_Bucket.
- **IAM_Permission_Policy**: Permission policy attached to the IAM_Role that defines the allowed actions on the S3_Bucket.
- **Instance_Profile**: IAM resource that associates the IAM_Role with the EC2_Instance.
- **S3_Bucket**: Amazon S3 bucket provisioned in Account B, target of the cross-account access.
- **Bucket_Policy**: Resource policy attached to the S3_Bucket that authorizes the IAM_Role principal to perform the defined actions.
- **Security_Group**: Security group associated with the EC2_Instance that controls inbound and outbound network traffic.
- **EC2_Instance_Connect**: AWS service that enables SSH access to the instance via the console, from AWS-managed IP ranges.
- **Terraform_Module_A**: Terraform module/configuration responsible for Account A resources.
- **Terraform_Module_B**: Terraform module/configuration responsible for Account B resources.
- **Cross_Account_Access**: IAM access pattern where a principal from one AWS account accesses resources in another AWS account.
- **VPC_Gateway_Endpoint**: AWS VPC endpoint of type Gateway that routes traffic from the VPC directly to S3 without traversing the public internet.

---

## Requirements

### Requirement 1: IAM Role Provisioning in Account A

**User Story:** As an infrastructure engineer, I want to provision an IAM Role in Account A with a trust policy that allows the EC2_Instance to assume it, so that the instance can authenticate using temporary credentials.

#### Acceptance Criteria

1. THE Terraform_Module_A SHALL create an IAM_Role with a trust policy that authorizes the `ec2.amazonaws.com` service to assume the role via `sts:AssumeRole`.
2. THE Terraform_Module_A SHALL create an Instance_Profile associating the IAM_Role with the EC2_Instance.
3. WHEN the Terraform_Module_A is applied, THE Instance_Profile SHALL be attached to the EC2_Instance at provisioning time.
4. IF the IAM_Role ARN is not available as an output of Terraform_Module_A, THEN THE Terraform_Module_A SHALL return a configuration error indicating the missing output.

---

### Requirement 2: Cross-Account Permissions in the IAM Permission Policy

**User Story:** As an infrastructure engineer, I want the IAM_Role in Account A to have an IAM_Permission_Policy with list, read, and write permissions on the S3_Bucket in Account B, so that the EC2_Instance can operate on the remote bucket.

#### Acceptance Criteria

1. THE Terraform_Module_A SHALL create an IAM_Permission_Policy and attach it to the IAM_Role containing the following actions on the S3_Bucket:
   - `s3:ListBucket` (applied to the bucket ARN)
   - `s3:GetObject` (applied to the bucket ARN with `/*` suffix)
   - `s3:PutObject` (applied to the bucket ARN with `/*` suffix)
   - `s3:DeleteObject` (applied to the bucket ARN with `/*` suffix)
2. WHEN the S3_Bucket ARN from Account B is provided as an input variable, THE Terraform_Module_A SHALL use that ARN as the `Resource` in the IAM_Permission_Policy.
3. IF the S3_Bucket ARN is not provided as an input variable, THEN THE Terraform_Module_A SHALL fail at Terraform validation with a descriptive error message.
4. THE IAM_Permission_Policy SHALL contain only the actions listed in criterion 1, with no additional permissions beyond what is necessary (principle of least privilege).

---

### Requirement 3: EC2 Instance Provisioning in Account A

**User Story:** As an infrastructure engineer, I want to provision an EC2 instance in Account A with the IAM_Role attached, so that the instance can make authenticated AWS API calls without requiring static credentials.

#### Acceptance Criteria

1. THE Terraform_Module_A SHALL create an EC2_Instance using an AMI and instance type configurable via input variables.
2. WHEN the EC2_Instance is provisioned, THE Terraform_Module_A SHALL attach the Instance_Profile to the instance.
3. THE Terraform_Module_A SHALL accept the following input variables: `ami_id` (string), `instance_type` (string), `aws_region` (string), and `bucket_arn` (string).
4. IF the `instance_type` variable is not provided, THEN THE Terraform_Module_A SHALL use the default value `t2.micro`.

---

### Requirement 4: S3 Bucket Provisioning in Account B

**User Story:** As an infrastructure engineer, I want to provision an S3 bucket in Account B with appropriate security settings, so that the bucket is ready to receive the cross-account bucket policy.

#### Acceptance Criteria

1. THE Terraform_Module_B SHALL create an S3_Bucket with a name configurable via the `bucket_name` input variable.
2. THE Terraform_Module_B SHALL enable public access block (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) on the S3_Bucket.
3. THE Terraform_Module_B SHALL provision the S3_Bucket with versioning disabled (`status = "Disabled"`).
4. THE Terraform_Module_B SHALL return the S3_Bucket ARN and name as outputs for use by Terraform_Module_A.
5. IF the `bucket_name` variable is not provided, THEN THE Terraform_Module_B SHALL fail at Terraform validation with a descriptive error message.

---

### Requirement 5: Cross-Account Bucket Policy in Account B

**User Story:** As an infrastructure engineer, I want the S3_Bucket in Account B to have a Bucket_Policy that explicitly authorizes the IAM_Role principal from Account A, so that cross-account access is permitted on the resource side.

#### Acceptance Criteria

1. THE Terraform_Module_B SHALL create a Bucket_Policy and attach it to the S3_Bucket authorizing the IAM_Role ARN from Account A as the principal.
2. THE Bucket_Policy SHALL grant the principal the following actions:
   - `s3:ListBucket` (applied to the bucket ARN)
   - `s3:GetObject` (applied to the bucket ARN with `/*` suffix)
   - `s3:PutObject` (applied to the bucket ARN with `/*` suffix)
   - `s3:DeleteObject` (applied to the bucket ARN with `/*` suffix)
3. WHEN the IAM_Role ARN from Account A is provided as the `role_arn` input variable, THE Terraform_Module_B SHALL use that ARN as the `Principal` in the Bucket_Policy.
4. IF the IAM_Role ARN is not provided as an input variable, THEN THE Terraform_Module_B SHALL fail at Terraform validation with a descriptive error message.
5. THE Bucket_Policy SHALL use the `Allow` effect only for the actions listed in criterion 2, with no additional permissions.

---

### Requirement 6: Permission Consistency Between Role and Bucket Policy

**User Story:** As a security engineer, I want to ensure that the permissions defined in the IAM_Permission_Policy in Account A are identical to the permissions defined in the Bucket_Policy in Account B, so that cross-account access works correctly without divergent permissions.

#### Acceptance Criteria

1. THE Terraform_Module_A and THE Terraform_Module_B SHALL define the same set of S3 actions (`s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`) in their respective policies.
2. WHEN actions are applied to the bucket resource, THE IAM_Permission_Policy and THE Bucket_Policy SHALL use the same bucket ARN as the target resource.
3. WHEN actions are applied to objects within the bucket, THE IAM_Permission_Policy and THE Bucket_Policy SHALL use the bucket ARN with `/*` suffix as the target resource.

---

### Requirement 7: Terraform Module Structure and Organization

**User Story:** As an infrastructure engineer, I want the Terraform scripts to be organized in separate directories per AWS account, so that each account can be managed and applied independently.

#### Acceptance Criteria

1. THE Terraform_Module_A SHALL reside in a dedicated directory (e.g., `account-a/`) containing the files `main.tf`, `variables.tf`, and `outputs.tf`.
2. THE Terraform_Module_B SHALL reside in a dedicated directory (e.g., `account-b/`) containing the files `main.tf`, `variables.tf`, and `outputs.tf`.
3. THE Terraform_Module_A SHALL declare the AWS provider configured with Account A's region via the `aws_region` input variable.
4. THE Terraform_Module_B SHALL declare the AWS provider configured with Account B's region via the `aws_region` input variable.
5. WHEN an engineer runs `terraform init && terraform apply` in the Terraform_Module_A directory, THE Terraform_Module_A SHALL provision all Account A resources without requiring Terraform_Module_B to be applied first, provided the required input variables are supplied.
6. WHEN an engineer runs `terraform init && terraform apply` in the Terraform_Module_B directory, THE Terraform_Module_B SHALL provision all Account B resources without requiring Terraform_Module_A to be applied first, provided the required input variables are supplied.

---

### Requirement 8: VPC Gateway Endpoint for S3

**User Story:** As an infrastructure engineer, I want to provision a VPC Gateway Endpoint for S3 in Account A's VPC, so that traffic between the EC2 instance and the S3 bucket in Account B never traverses the public internet.

#### Acceptance Criteria

1. THE Terraform_Module_A SHALL create a VPC_Gateway_Endpoint of type `Gateway` for the S3 service (`com.amazonaws.<region>.s3`) in the VPC where the EC2_Instance resides.
2. THE VPC_Gateway_Endpoint SHALL be associated with the main route table of the VPC, discovered via the `aws_route_table` data source filtered by `association.main = true`.
3. WHEN the `vpc_id` variable is not provided, THE Terraform_Module_A SHALL automatically discover the default VPC using the `aws_vpc` data source with `default = true`.
4. WHEN the `vpc_id` variable is provided, THE Terraform_Module_A SHALL use that VPC's main route table for the VPC_Gateway_Endpoint association.
5. WHEN the VPC_Gateway_Endpoint is provisioned, AWS SHALL automatically add a route in the associated route table directing S3-bound traffic through the endpoint, bypassing the internet gateway.
6. THE Terraform_Module_A SHALL return the VPC_Gateway_Endpoint ID as an output named `s3_vpc_endpoint_id`.

---

### Requirement 9: Security Group and EC2 Instance Access

**User Story:** As an infrastructure engineer, I want the EC2 instance to be accessible via EC2 Instance Connect, so that the instance can be reached securely through the AWS Console without exposing port 22 to arbitrary IPs.

#### Acceptance Criteria

1. THE Terraform_Module_A SHALL create a Security_Group and associate it with the EC2_Instance.
2. THE Security_Group SHALL contain an ingress rule on port 22 (TCP) restricted to the IP ranges of the EC2_Instance_Connect service for the configured region, retrieved dynamically via the `aws_ip_ranges` data source.
3. THE Security_Group SHALL contain an egress rule restricted to HTTPS (port 443, TCP) to `0.0.0.0/0`, allowing outbound communication with AWS service endpoints only (e.g., OS package updates).
4. THE IAM_Role SHALL NOT have the `AmazonSSMManagedInstanceCore` managed policy attached. SSM Session Manager is out of scope for this project; access is provided via EC2_Instance_Connect.
5. WHEN the `aws_region` variable is changed, THE Terraform_Module_A SHALL automatically update the Security_Group IP ranges to reflect the EC2_Instance_Connect IPs for the new region.
6. THE EC2_Instance SHALL have `associate_public_ip_address` enabled to allow access via EC2_Instance_Connect.
