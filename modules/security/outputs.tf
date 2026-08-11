output "kms_key_arn" {
  value = aws_kms_key.wazuh.arn
}

output "kms_key_id" {
  value = aws_kms_key.wazuh.key_id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "dashboard_sg_id" {
  value = aws_security_group.dashboard.id
}

output "manager_sg_id" {
  value = aws_security_group.manager.id
}

output "indexer_sg_id" {
  value = aws_security_group.indexer.id
}
