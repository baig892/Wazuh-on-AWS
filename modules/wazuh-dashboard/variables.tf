variable "name_prefix" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "node_count" {
  type = number
}

variable "kms_key_arn" {
  type = string
}

variable "dashboard_admin_secret_arn" {
  type = string
}

variable "indexer_private_ips" {
  description = "Indexer nodes the dashboard talks to."
  type        = list(string)
  default     = []
}

variable "key_pair_name" {
  type    = string
  default = null
}

variable "ami_id" {
  description = "Override AMI ID. Defaults to latest Ubuntu 22.04 LTS via data source if left null."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
