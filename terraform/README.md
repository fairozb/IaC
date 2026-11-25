# EC2 instance (fairoz-demo)

Terraform configuration for a single Amazon EC2 instance in the existing default VPC.

## What this creates

- One `t3.micro` instance (`aws_instance.fairoz_demo`) in `us-east-1`
- Subnet: the default subnet in `us-east-1f`, looked up with a data source
- Security group: the default security group of the default VPC, looked up with a data source
- Name tag: `fairoz-demo`
- Networking: an automatically assigned ephemeral public IP (not an Elastic IP)

VPC, subnet, and security group IDs are not hardcoded. Terraform reads them at plan time from the account's default VPC.

The public IP can change after the instance is stopped and started.

## Prerequisites

- Terraform 1.5.0 or newer
- An AWS account whose default VPC still has a default subnet in `us-east-1f` and the default security group
- AWS credentials configured outside this repository

Do not put access keys, secret keys, or session tokens in any `.tf` or `.tfvars` file. This configuration sets only the region. The AWS provider uses the standard credential chain:

- Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` when using temporary credentials)
- A shared config or credentials file, optionally selected with `AWS_PROFILE`
- An IAM role (for example on an EC2 instance or in CI)

## Usage

From this directory:

```bash
terraform init
terraform plan
terraform apply
terraform output
```

`terraform output` prints the instance ID and the ephemeral public IP after apply.

To remove the instance:

```bash
terraform destroy
```

Destroy deletes only the EC2 instance managed here. It does not delete the default VPC, subnet, or security group.
