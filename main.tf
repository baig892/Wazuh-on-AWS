data "aws_caller_identity" "current" {}

locals {
  name_prefix = "wazuh-${var.environment}"

  common_tags = {
    Project     = "wazuh-siem"
    Environment = var.environment
  }
}

module "networking" {
  source = "./modules/networking"

  name_prefix                = local.name_prefix
  vpc_cidr                   = var.vpc_cidr
  az_count                   = var.az_count
  enable_interface_endpoints = var.enable_interface_endpoints
  tags                       = local.common_tags
}

module "security" {
  source = "./modules/security"

  name_prefix     = local.name_prefix
  vpc_id          = module.networking.vpc_id
  vpc_cidr        = module.networking.vpc_cidr
  client_vpn_cidr = var.client_vpn_cidr
  tags            = local.common_tags
}

module "secrets" {
  source = "./modules/secrets"

  name_prefix = local.name_prefix
  kms_key_arn = module.security.kms_key_arn
  tags        = local.common_tags
}

#Monitoring (created before client_vpn so its log group can be
# wired straight into the VPN's connection_log_options)

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix        = local.name_prefix
  kms_key_arn        = module.security.kms_key_arn
  log_retention_days = var.log_retention_days
  monitored_instance_ids = concat(
    module.wazuh_manager.instance_ids,
    module.wazuh_indexer.instance_ids,
    module.wazuh_dashboard.instance_ids,
  )
  tags = local.common_tags
}

module "client_vpn" {
  source = "./modules/client-vpn"

  name_prefix                 = local.name_prefix
  vpc_id                      = module.networking.vpc_id
  vpc_cidr                    = module.networking.vpc_cidr
  private_subnet_ids          = module.networking.private_subnet_ids
  client_cidr_block           = var.client_vpn_cidr
  server_certificate_arn      = var.vpn_server_certificate_arn
  client_root_certificate_arn = var.vpn_client_root_certificate_arn
  connection_log_group        = module.monitoring.vpn_log_group
  tags                        = local.common_tags
}

module "wazuh_manager" {
  source = "./modules/wazuh-manager"

  name_prefix            = local.name_prefix
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  security_group_id      = module.security.manager_sg_id
  instance_type          = var.manager_instance_type
  node_count             = var.manager_node_count
  kms_key_arn            = module.security.kms_key_arn
  cluster_key_secret_arn = module.secrets.cluster_key_secret_arn
  key_pair_name          = var.key_pair_name
  tags                   = local.common_tags
}

module "wazuh_indexer" {
  source = "./modules/wazuh-indexer"

  name_prefix              = local.name_prefix
  private_subnet_ids       = module.networking.private_subnet_ids
  security_group_id        = module.security.indexer_sg_id
  instance_type            = var.indexer_instance_type
  node_count               = var.indexer_node_count
  data_volume_size_gb      = var.indexer_volume_size_gb
  kms_key_arn              = module.security.kms_key_arn
  indexer_admin_secret_arn = module.secrets.indexer_admin_secret_arn
  key_pair_name            = var.key_pair_name
  tags                     = local.common_tags
}

module "wazuh_dashboard" {
  source = "./modules/wazuh-dashboard"

  name_prefix                = local.name_prefix
  private_subnet_ids         = module.networking.private_subnet_ids
  security_group_id          = module.security.dashboard_sg_id
  instance_type              = var.dashboard_instance_type
  node_count                 = var.dashboard_node_count
  kms_key_arn                = module.security.kms_key_arn
  dashboard_admin_secret_arn = module.secrets.dashboard_admin_secret_arn
  indexer_private_ips        = module.wazuh_indexer.private_ips
  key_pair_name              = var.key_pair_name
  tags                       = local.common_tags
}

# Internal ALB - dashboard HTTPS traffic only. Needs a real ACM certificate
# (var.dashboard_certificate_arn), provisioned out of band same as the VPN
# certs.

module "alb" {
  source = "./modules/alb"

  name_prefix         = local.name_prefix
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  security_group_id   = module.security.alb_sg_id
  certificate_arn     = var.dashboard_certificate_arn
  target_instance_ids = module.wazuh_dashboard.instance_ids
  tags                = local.common_tags
}

# Internal NLB - agent registration/event traffic (TCP 1514/1515) to the
# manager fleet. Separate from the ALB above because agents speak raw TCP,
# not HTTP.

module "nlb" {
  source = "./modules/nlb"

  name_prefix          = local.name_prefix
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  manager_instance_ids = module.wazuh_manager.instance_ids
  tags                 = local.common_tags
}

# DR region (Backup & Restore)
# Deliberately minimal - see modules/dr/main.tf and the decision record.
module "dr" {
  count  = var.enable_dr ? 1 : 0
  source = "./modules/dr"

  providers = {
    aws = aws.dr
  }

  name_prefix = local.name_prefix
  account_id  = data.aws_caller_identity.current.account_id
  tags        = local.common_tags
}

# Storage (S3 archive tier, 90d-hot -> 12mo-archive)
module "storage" {
  source = "./modules/storage"

  name_prefix            = local.name_prefix
  account_id             = data.aws_caller_identity.current.account_id
  kms_key_arn            = module.security.kms_key_arn
  archive_retention_days = var.archive_retention_days
  vpc_endpoint_id        = module.networking.s3_endpoint_id
  replica_bucket_arn     = var.enable_dr ? module.dr[0].archive_replica_bucket_arn : null
  replica_kms_key_arn    = var.enable_dr ? module.dr[0].kms_key_arn : null
  tags                   = local.common_tags
}

# Backup (daily EBS snapshots, tag-based selection)
module "backup" {
  count  = var.enable_backup ? 1 : 0
  source = "./modules/backup"

  name_prefix    = local.name_prefix
  kms_key_arn    = module.security.kms_key_arn
  retention_days = var.backup_retention_days
  dr_vault_arn   = var.enable_dr ? module.dr[0].backup_vault_arn : null
  tags           = local.common_tags

  depends_on = [
    module.wazuh_manager,
    module.wazuh_indexer,
    module.wazuh_dashboard,
  ]
}
