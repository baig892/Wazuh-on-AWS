# Shared KMS key for EBS, Secrets Manager, S3 and Backup.

# Needs an explicit policy (rather than the provider default) once CloudTrail

# and Config write to KMS-encrypted buckets - those services act via their

# own service principal, not an IAM role, so root-account-only access isn't

# enough for them specifically.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "EnableIAMUserPermissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid     = "AllowCloudTrail"
    actions = ["kms:GenerateDataKey*", "kms:DescribeKey", "kms:Decrypt"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid     = "AllowConfig"
    actions = ["kms:GenerateDataKey*", "kms:DescribeKey", "kms:Decrypt"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }

  statement {
    sid     = "AllowBackup"
    actions = ["kms:GenerateDataKey*", "kms:DescribeKey", "kms:Decrypt", "kms:CreateGrant"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "wazuh" {
  description             = "${var.name_prefix} CMK for EBS, Secrets Manager, S3 and Backup"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-cmk" })
}

resource "aws_kms_alias" "wazuh" {
  name          = "alias/${var.name_prefix}-cmk"
  target_key_id = aws_kms_key.wazuh.key_id
}

# Security groups

# Internal ALB for the Wazuh dashboard.

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = var.vpc_id
  description = "Internal ALB in front of the Wazuh dashboard"

  ingress {
    description = "HTTPS from Client VPN pool"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Wazuh dashboard nodes.

resource "aws_security_group" "dashboard" {
  name_prefix = "${var.name_prefix}-dashboard-"
  vpc_id      = var.vpc_id
  description = "Wazuh dashboard nodes"

  ingress {
    description     = "HTTPS from internal ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-dashboard-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Wazuh manager cluster.
resource "aws_security_group" "manager" {
  name_prefix = "${var.name_prefix}-manager-"
  vpc_id      = var.vpc_id
  description = "Wazuh manager cluster nodes"

  ingress {
    description = "Agent enrollment and event traffic"
    from_port   = 1514
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Wazuh cluster traffic"
    from_port   = 1516
    to_port     = 1516
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "Wazuh API from dashboard"
    from_port       = 55000
    to_port         = 55000
    protocol        = "tcp"
    security_groups = [aws_security_group.dashboard.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-manager-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Wazuh indexer cluster.
resource "aws_security_group" "indexer" {
  name_prefix = "${var.name_prefix}-indexer-"
  vpc_id      = var.vpc_id
  description = "Wazuh indexer cluster nodes"

  ingress {
    description     = "Indexer API from managers and dashboard"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [
      aws_security_group.manager.id,
      aws_security_group.dashboard.id
    ]
  }

  ingress {
    description = "Indexer cluster traffic"
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-indexer-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# No inbound SSH access. Use SSM for administration.