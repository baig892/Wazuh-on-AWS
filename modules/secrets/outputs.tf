output "dashboard_admin_secret_arn" {
  value = aws_secretsmanager_secret.dashboard_admin.arn
}

output "indexer_admin_secret_arn" {
  value = aws_secretsmanager_secret.indexer_admin.arn
}

output "cluster_key_secret_arn" {
  value = aws_secretsmanager_secret.cluster_key.arn
}
