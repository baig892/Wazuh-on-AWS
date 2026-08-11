variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "certificate_arn" {
  description = "ACM certificate for the internal ALB HTTPS listener."
  type        = string
}

variable "target_instance_ids" {
  description = "Dashboard EC2 instance IDs to attach to the target group."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
