variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "client_cidr_block" {
  description = "Address pool handed out to connected VPN clients."
  type        = string
}

variable "server_certificate_arn" {
  type = string
}

variable "client_root_certificate_arn" {
  type = string
}

variable "connection_log_group" {
  description = "CloudWatch log group name for VPN connection logs. Leave null to disable (e.g. if monitoring module isn't wired up yet)."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
