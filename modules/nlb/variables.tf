variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "manager_instance_ids" {
  description = "Manager EC2 instance IDs to register as NLB targets (all of them - master and workers both accept agent traffic)."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
