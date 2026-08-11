output "vpc_id" {
  value = module.networking.vpc_id
}

output "client_vpn_dns_name" {
  value = module.client_vpn.dns_name
}

output "manager_private_ips" {
  value = module.wazuh_manager.private_ips
}

output "manager_master_instance_id" {
  value = module.wazuh_manager.master_instance_id
}

output "indexer_private_ips" {
  value = module.wazuh_indexer.private_ips
}

output "dashboard_private_ips" {
  value = module.wazuh_dashboard.private_ips
}

output "dashboard_alb_dns_name" {
  value = module.alb.dns_name
}

output "agent_nlb_dns_name" {
  value = module.nlb.dns_name
}

output "archive_bucket" {
  value = module.storage.bucket_id
}

output "backup_vault_arn" {
  value = var.enable_backup ? module.backup[0].vault_arn : null
}

output "dr_enabled" {
  value = var.enable_dr
}

output "dr_archive_replica_bucket" {
  value = var.enable_dr ? module.dr[0].archive_replica_bucket_arn : null
}

output "dr_backup_vault_arn" {
  value = var.enable_dr ? module.dr[0].backup_vault_arn : null
}
