# variables.tf
# -------------
# All the "knobs" of this project. You set these in terraform.tfvars
# (copy terraform.tfvars.example -> terraform.tfvars and fill it in).

variable "region" {
  description = "AWS region to deploy into, e.g. us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A short prefix used to name and tag resources."
  type        = string
  default     = "oidc-demo"
}

variable "github_owner" {
  description = "Your GitHub username or org that OWNS the sample-app repo, e.g. devopswithjunaid."
  type        = string
}

variable "app_repo_name" {
  description = "The name of the APPLICATION repo whose GitHub Actions are allowed to deploy, e.g. sample-app. This is the repo that runs deploy.yml, NOT the aws-infra repo."
  type        = string
  default     = "sample-app"
}

variable "app_port" {
  description = "The TCP port the container listens on (matches EXPOSE in the Dockerfile and PORT in server.js)."
  type        = number
  default     = 8080
}

variable "vpc_cidr" {
  description = "CIDR block for the project VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_cidr_blocks" {
  description = "Who can reach the running container over the internet. Default 0.0.0.0/0 (anyone) is fine for a short-lived demo so you can curl it; for real use, lock this to your own IP like 1.2.3.4/32."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "desired_count" {
  description = "How many copies of each service's task to run. 1 keeps cost minimal."
  type        = number
  default     = 1
}

variable "bootstrap_image" {
  description = "Placeholder image used ONLY for the very first apply (before your app image exists in ECR). It just keeps the service alive; the first pipeline deploy replaces it with your real image. It listens on port 80, so it is intentionally NOT reachable on the app port until you deploy."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}
