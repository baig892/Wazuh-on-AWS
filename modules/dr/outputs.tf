output "kms_key_arn" {
  value = aws_kms_key.dr.arn
}

output "archive_replica_bucket_arn" {
  value = aws_s3_bucket.archive_replica.arn
}

output "backup_vault_arn" {
  value = aws_backup_vault.dr.arn
}
