variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type    = number
  default = 3
}

variable "enable_interface_endpoints" {
  description = "Create interface VPC endpoints for Secrets Manager/KMS/SSM/CloudWatch Logs. Off by default for the demo stack to save ~$28/mo (7 endpoints x ~$0.126/hr in eu-west-2 x 2 AZs) when it isn't needed for a quick smoke test."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
