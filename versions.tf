# versions.tf
# ------------
# Pins the Terraform CLI version and the providers we use, and configures
# WHERE Terraform stores its "state" file.
#
# Terraform state = Terraform's memory of what it has created. Because our
# pipeline runs on fresh, throwaway GitHub Actions runners, the state CANNOT
# live on the runner's local disk (it would vanish after each run). So we store
# it remotely in an S3 bucket that you create once (see README, "Bootstrap").
#
# The bucket NAME is intentionally NOT hardcoded here. You pass it at init time:
#   terraform init -backend-config="bucket=YOUR_BUCKET" -backend-config="key=oidc-demo/terraform.tfstate" -backend-config="region=YOUR_REGION"
# The pipeline does this for you using a GitHub Actions variable.

terraform {
  required_version = ">= 1.10.0" # 1.10+ gives us native S3 state locking (no DynamoDB needed)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Left empty on purpose. Values are supplied via -backend-config at init time.
    # use_lockfile = true enables S3-native state locking (Terraform >= 1.10).
    use_lockfile = true
    encrypt      = true
  }
}
