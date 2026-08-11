# S3 archive bucket for Wazuh alert data.
# Data is retained here after the indexer's hot retention period.

resource "aws_s3_bucket" "archive" {
  bucket = "${var.name_prefix}-archive-${var.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket                  = aws_s3_bucket.archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning is required for S3 replication.
resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }

    bucket_key_enabled = true
  }
}

# Move older archive data to Glacier and expire it after the retention period.
resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    id     = "tier-then-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = var.archive_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Restrict archive access to the VPC endpoint and S3 replication role.
data "aws_iam_policy_document" "archive_bucket" {
  statement {
    sid       = "DenyOutsideVpcEndpointOrReplication"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.archive.arn, "${aws_s3_bucket.archive.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"
      values   = [var.vpc_endpoint_id]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [local.replication_role_arn]
    }
  }
}

locals {
  replication_role_arn = length(aws_iam_role.replication) > 0 ? aws_iam_role.replication[0].arn : "arn:aws:iam::000000000000:role/no-replication-configured"
}

resource "aws_s3_bucket_policy" "archive" {
  count  = var.vpc_endpoint_id == null ? 0 : 1
  bucket = aws_s3_bucket.archive.id
  policy = data.aws_iam_policy_document.archive_bucket.json
}

# ---------- Cross-region replication ----------

data "aws_iam_policy_document" "replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count              = var.replica_bucket_arn == null ? 0 : 1
  name_prefix        = "${var.name_prefix}-s3-repl-"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "replication" {
  count = var.replica_bucket_arn == null ? 0 : 1

  statement {
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.archive.arn]
  }

  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]

    resources = ["${aws_s3_bucket.archive.arn}/*"]
  }

  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags"
    ]

    resources = ["${var.replica_bucket_arn}/*"]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  statement {
    actions   = ["kms:Encrypt"]
    resources = [var.replica_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "replication" {
  count  = var.replica_bucket_arn == null ? 0 : 1
  name   = "${var.name_prefix}-s3-repl"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

resource "aws_s3_bucket_replication_configuration" "archive" {
  count  = var.replica_bucket_arn == null ? 0 : 1
  bucket = aws_s3_bucket.archive.id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"

    destination {
      bucket        = var.replica_bucket_arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = var.replica_kms_key_arn
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.archive]
}
