variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "retention_days" {
  type = number
}

variable "resource_arns" {
  description = "Unused now that selection is tag-based (Backup=true) - kept for backward compatibility, safe to remove once you've confirmed nothing references it."
  type        = list(string)
  default     = []
}

variable "dr_vault_arn" {
  description = "ARN of a backup vault in the DR region. When set, the daily plan adds a copy_action to replicate each recovery point there. Leave null to disable cross-region copy (e.g. for the demo stack)."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
