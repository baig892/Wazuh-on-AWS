variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "log_retention_days" {
  description = "Retention for CloudTrail/Config S3 logs and the VPN CloudWatch log group."
  type        = number
  default     = 400 # > 12 months, matches the archive retention story in the decision record
}

variable "monitored_instance_ids" {
  description = "EC2 instance IDs to attach a StatusCheckFailed alarm to (manager + indexer + dashboard)."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
