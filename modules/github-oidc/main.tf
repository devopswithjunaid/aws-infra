# modules/github-oidc
# ===================
# Registers GitHub Actions as an OIDC identity provider in AWS IAM.
# Creating this only says "tokens from GitHub are a valid identity source".
# It does NOT grant access by itself -- each role's trust policy decides that.

# Read GitHub's OIDC TLS certificate so we can supply its fingerprint as the
# provider thumbprint. Doing this dynamically means it self-heals if GitHub
# rotates their certificate authority.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = merge(var.tags, { Name = "${var.project_name}-github-oidc" })
}
