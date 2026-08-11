variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Short environment name used in tags/names, e.g. prod, demo."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the Wazuh VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread across. 3 for production HA, can be reduced for demo but VPN/ALB assume >=2."
  type        = number
  default     = 3
}

# Client VPN / administrative access

variable "client_vpn_cidr" {
  description = "CIDR range handed out to connected Client VPN users. Must not overlap vpc_cidr."
  type        = string
  default     = "10.100.0.0/22"
}

variable "vpn_server_certificate_arn" {
  description = "ACM ARN of the server certificate used by the Client VPN endpoint. Provision this out of band (mutual TLS cert chain) - see README."
  type        = string
}

variable "vpn_client_root_certificate_arn" {
  description = "ACM Private CA / ACM ARN of the client root certificate used for mutual TLS auth on the Client VPN endpoint."
  type        = string
}

# Wazuh Manager cluster
variable "manager_node_count" {
  description = "Number of Wazuh manager nodes. 3 for production, 1 for demo."
  type        = number
  default     = 3
}

variable "manager_instance_type" {
  description = "EC2 instance type for Wazuh manager nodes."
  type        = string
  default     = "m6i.large"
}

# Wazuh Indexer cluster

variable "indexer_node_count" {
  description = "Number of Wazuh indexer nodes. 3 for production, 1 for demo."
  type        = number
  default     = 3
}

variable "indexer_instance_type" {
  description = "EC2 instance type for Wazuh indexer nodes."
  type        = string
  default     = "m6i.xlarge"
}

variable "indexer_volume_size_gb" {
  description = "Size in GB of each indexer's gp3 data volume. Sizing: ~25GB/day ingest x 90d hot x 2 (1 replica) / 3 nodes ~= 1.5TB/node minimum - set above that with headroom for growth and segment merge overhead."
  type        = number
  default     = 1700
}

# Wazuh Dashboard

variable "dashboard_instance_type" {
  description = "EC2 instance type for the Wazuh dashboard node(s)."
  type        = string
  default     = "t3.medium"
}

variable "dashboard_node_count" {
  description = "Number of dashboard nodes (active/standby). 2 for production, 1 for demo."
  type        = number
  default     = 2
}

# Backup / DR

variable "backup_retention_days" {
  description = "Retention in days for AWS Backup recovery points."
  type        = number
  default     = 35
}

variable "enable_backup" {
  description = "Whether to provision AWS Backup vault/plan. Disable for throwaway demo stacks."
  type        = bool
  default     = true
}

# SSH / emergency access

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for emergency console access. Prefer SSM Session Manager day to day - see decision record."
  type        = string
  default     = null
}

# Internal ALB (dashboard) / NLB (agents)

variable "dashboard_certificate_arn" {
  description = "ACM certificate ARN for the internal ALB's HTTPS listener in front of the dashboard. Provision out of band, same reasoning as the VPN certs - see README."
  type        = string
}

# Networking extras

variable "enable_interface_endpoints" {
  description = "Create interface VPC endpoints for Secrets Manager/KMS/SSM/CloudWatch Logs. Disable for the demo stack to save cost on a quick smoke test."
  type        = bool
  default     = true
}

# Monitoring

variable "log_retention_days" {
  description = "Retention for CloudTrail/Config S3 logs and the VPN CloudWatch log group."
  type        = number
  default     = 400
}

# Archive storage (S3)

variable "archive_retention_days" {
  description = "Total retention (days) for the S3 archive tier before expiry. 12 months per the brief."
  type        = number
  default     = 400
}

# Disaster recovery

variable "enable_dr" {
  description = "Provision the DR-region resources (replica S3 bucket, DR KMS key, DR backup vault) and wire cross-region S3 CRR + AWS Backup copy_action. See decision record for the Backup & Restore approach, RPO/RTO and cost trade-off. Off by default for the demo stack."
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "AWS region for DR resources. Must differ from aws_region."
  type        = string
  default     = "eu-west-1"
}
