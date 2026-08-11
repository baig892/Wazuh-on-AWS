# Secrets are created here but values are added separately.
# This keeps passwords and keys out of Terraform variables and state.

resource "aws_secretsmanager_secret" "dashboard_admin" {
  name       = "${var.name_prefix}/dashboard-admin-password"
  kms_key_id = var.kms_key_arn
  tags       = var.tags
}

resource "aws_secretsmanager_secret" "indexer_admin" {
  name       = "${var.name_prefix}/indexer-admin-password"
  kms_key_id = var.kms_key_arn
  tags       = var.tags
}

resource "aws_secretsmanager_secret" "cluster_key" {
  name       = "${var.name_prefix}/manager-cluster-key"
  kms_key_id = var.kms_key_arn
  tags       = var.tags
}

# TODO: Add automatic rotation for admin passwords.
