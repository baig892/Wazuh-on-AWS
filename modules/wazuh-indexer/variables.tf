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

variable "data_volume_size_gb" {
  type = number
}

variable "kms_key_arn" {
  type = string
}

variable "indexer_admin_secret_arn" {
  type = string
}

variable "key_pair_name" {
  type    = string
  default = null
}

variable "ami_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
