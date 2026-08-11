variable "name_prefix" {
  type = string
}

variable "account_id" {
  description = "Account ID, used to keep the bucket name globally unique."
  type        = string
}

variable "kms_key_arn" {
  type = string
}

variable "archive_retention_days" {
  description = "Total retention (days) before an archived object expires. 12 months per the brief."
  type        = number
  default     = 400
}

variable "vpc_endpoint_id" {
  description = "S3 gateway VPC endpoint ID. When set, bucket access is restricted to that endpoint. Leave null to skip the restrictive bucket policy (e.g. quick demo stacks)."
  type        = string
  default     = null
}

variable "replica_bucket_arn" {
  description = "ARN of the DR-region replica bucket. When set, CRR is enabled. Leave null to disable (e.g. demo stack, or enable_dr=false)."
  type        = string
  default     = null
}

variable "replica_kms_key_arn" {
  description = "KMS key ARN in the DR region used to encrypt replicated objects. Required if replica_bucket_arn is set."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
