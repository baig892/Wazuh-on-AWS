output "vault_arn" {
  value = aws_backup_vault.wazuh.arn
}

output "plan_id" {
  value = aws_backup_plan.wazuh.id
}
