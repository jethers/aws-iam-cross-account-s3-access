# aws-iam-cross-account-s3-access

Terraform scripts to provision cross-account access between two AWS accounts. An EC2 instance in **Account A** directly accesses an S3 bucket in **Account B** using an IAM Role with explicit permissions, without requiring an assume role between accounts.

> **Traffic never leaves the AWS network.** The EC2 instance reaches the S3 bucket in Account B through a **VPC Gateway Endpoint**, bypassing the public internet entirely.

## Architecture

```
Account A (EC2)                                          Account B (S3)
┌──────────────────────────────────────────┐            ┌──────────────────────────┐
│                                          │            │                          │
│  ┌──────────────────┐                   │            │  ┌────────────────────┐  │
│  │   EC2 Instance   │                   │            │  │    S3 Bucket       │  │
│  │  (IAM Role via   │                   │            │  │                    │  │
│  │ Instance Profile)│                   │            │  │  Bucket Policy     │  │
│  └────────┬─────────┘                   │            │  │  (authorizes role  │  │
│           │                             │            │  │   ARN)             │  │
│           │ s3:List / Get / Put / Delete │            │  └────────────────────┘  │
│           ▼                             │            │            ▲             │
│  ┌──────────────────┐                   │            │            │             │
│  │  VPC Gateway     │───────────────────┼────────────┼────────────┘             │
│  │  Endpoint (S3)   │  AWS internal     │            │                          │
│  └──────────────────┘  network only     │            │                          │
│                                          │            │                          │
└──────────────────────────────────────────┘            └──────────────────────────┘
```

Access works through the combination of three controls:
- **VPC Gateway Endpoint**: routes all S3 traffic through the AWS internal network — no internet gateway involved
- **Permission Policy** on the IAM Role (Account A): defines the allowed S3 actions
- **Bucket Policy** on S3 (Account B): authorizes the role ARN as the principal

## Provisioned Resources

### Account A (`account-a/`)
| Resource | Description |
|---|---|
| `aws_iam_role` | IAM Role with trust policy for `ec2.amazonaws.com` |
| `aws_iam_policy` | Permission policy with `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` |
| `aws_iam_instance_profile` | Associates the role with the EC2 instance |
| `aws_iam_role_policy_attachment` | Attaches the S3 policy to the role |
| `aws_security_group` | Ingress: port 22 restricted to EC2 Instance Connect IP ranges. Egress: port 443 only (for OS updates) |
| `aws_instance` | EC2 instance with public IP and instance profile |
| `aws_vpc_endpoint` | VPC Gateway Endpoint for S3 — routes S3 traffic internally, bypassing the internet |

### Account B (`account-b/`)
| Resource | Description |
|---|---|
| `aws_s3_bucket` | S3 bucket with configurable name |
| `aws_s3_bucket_public_access_block` | Blocks all public access to the bucket |
| `aws_s3_bucket_versioning` | Versioning configured (disabled by default) |
| `aws_s3_bucket_policy` | Bucket policy that authorizes the Account A IAM Role as principal |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with two profiles (one per account)
- Sufficient IAM permissions in each account:
  - **Account A**: create EC2, IAM Role, IAM Policy, Instance Profile, Security Group, VPC Endpoint
  - **Account B**: create S3 Bucket, Bucket Policy

## Setup

### 1. Configure AWS CLI profiles

In `~/.aws/credentials`:
```ini
[your-account-a-profile]
aws_access_key_id     = AKIA...
aws_secret_access_key = ...

[your-account-b-profile]
aws_access_key_id     = AKIA...
aws_secret_access_key = ...
```

### 2. Create the variable files

```bash
cp account-a/terraform.tfvars.example account-a/terraform.tfvars
cp account-b/terraform.tfvars.example account-b/terraform.tfvars
```

Edit each file with your environment values.

> **Note:** `terraform.tfvars` files are listed in `.gitignore` and should not be committed.

### 3. Get the AMI ID for your region

```bash
aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --region us-east-1 \
  --profile your-account-a-profile \
  --query Parameter.Value \
  --output text
```

## Execution

Order matters: the bucket must exist before creating the role, and the role must exist before creating the bucket policy.

### Step 1 — Account B (creates the bucket without the policy)

Make sure `create_bucket_policy = false` in `account-b/terraform.tfvars`.

```bash
cd account-b
terraform init
terraform apply
```

Note the `bucket_arn` from the output and fill it in `account-a/terraform.tfvars`.

### Step 2 — Account A (creates the EC2 instance, IAM role, and VPC Gateway Endpoint)

```bash
cd ../account-a
terraform init
terraform apply
```

Note the `role_arn` from the output and fill it in `account-b/terraform.tfvars`.

### Step 3 — Account B (adds the bucket policy)

Set `create_bucket_policy = true` in `account-b/terraform.tfvars`.

```bash
cd ../account-b
terraform apply
```

## Connecting to the EC2 Instance

Access is configured via **EC2 Instance Connect**. The Security Group allows inbound SSH (port 22) exclusively from the AWS-managed IP ranges of the EC2 Instance Connect service for the configured region, fetched dynamically at apply time via the `aws_ip_ranges` data source.

SSM Session Manager is not configured in this project. If needed, it can be enabled by attaching the `AmazonSSMManagedInstanceCore` policy to the IAM Role and adjusting the egress rules accordingly.

**Steps:**
1. Go to AWS Console → EC2 → Instances
2. Select the instance → **Connect** → **EC2 Instance Connect**

## Network Security

| Traffic | Direction | Rule |
|---|---|---|
| SSH (port 22) | Inbound | Restricted to EC2 Instance Connect IP ranges only |
| HTTPS (port 443) | Outbound | Allowed to `0.0.0.0/0` (required for OS package updates via `yum`/`dnf`) |
| S3 API calls | Outbound | Routed through VPC Gateway Endpoint — never reaches the internet |

## Destroying Resources

```bash
# Account B first (removes the bucket policy)
cd account-b
terraform destroy

# Then Account A
cd ../account-a
terraform destroy
```

## Project Structure

```
aws-iam-cross-account-s3-access/
├── account-a/
│   ├── main.tf                  # EC2, IAM Role, Security Group, VPC Gateway Endpoint
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars         # not committed
│   └── terraform.tfvars.example
│
├── account-b/
│   ├── main.tf                  # S3 Bucket, Bucket Policy
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars         # not committed
│   └── terraform.tfvars.example
│
├── .kiro/
│   └── specs/
│       └── aws-cross-account-ec2-s3/
│           └── requirements.md  # spec generated with Kiro
│
├── .gitignore
└── README.md
```

## Built with Kiro

This project was developed with the help of [Kiro](https://kiro.dev), an AI-powered development environment by AWS. The process started with requirements definition in Kiro's Spec session, which produced the specification document available at [`.kiro/specs/aws-cross-account-ec2-s3/requirements.md`](.kiro/specs/aws-cross-account-ec2-s3/requirements.md).

From the requirements, Kiro assisted in generating the Terraform scripts, resolving errors during execution, and making incremental configuration adjustments — such as adding the VPC Gateway Endpoint for private S3 access, the security group with EC2 Instance Connect IP ranges, and separating the bucket policy into an independent step to work around AWS principal validation.
