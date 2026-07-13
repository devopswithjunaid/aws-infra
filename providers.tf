# providers.tf (root)
# -------------------
# AWS provider configuration + tags applied to every resource automatically.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
