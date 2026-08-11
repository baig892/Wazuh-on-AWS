# DR resources are deployed in the secondary region using the aliased provider.
# This module only contains the storage and backup targets required for DR.

resource "aws_kms_key" "dr" {
  description             = "${var.name_prefix} DR-region CMK (eu-west-1) for S3 replica + Backup copy vault"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-dr-cmk" })
}

resource "aws_kms_alias" "dr" {
  name          = "alias/${var.name_prefix}-dr-cmk"
  target_key_id = aws_kms_key.dr.key_id
}

resource "aws_s3_bucket" "archive_replica" {
  bucket = "${var.name_prefix}-archive-dr-${var.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "archive_replica" {
  bucket                  = aws_s3_bucket.archive_replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "archive_replica" {
  bucket = aws_s3_bucket.archive_replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive_replica" {
  bucket = aws_s3_bucket.archive_replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.dr.arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_backup_vault" "dr" {
  name        = "${var.name_prefix}-dr-backup-vault"
  kms_key_arn = aws_kms_key.dr.arn
  tags        = var.tags
}
