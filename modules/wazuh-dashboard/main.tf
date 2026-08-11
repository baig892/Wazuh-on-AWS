# Wazuh dashboard nodes running behind the internal ALB.

data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, try(data.aws_ami.ubuntu[0].id, null))
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dashboard" {
  name_prefix        = "${var.name_prefix}-dsh-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# SSM is used for instance access instead of SSH.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.dashboard.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow the dashboard instances to retrieve their admin credentials.
data "aws_iam_policy_document" "dashboard_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.dashboard_admin_secret_arn]
  }

  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "dashboard_secrets" {
  name   = "${var.name_prefix}-dsh-secrets"
  role   = aws_iam_role.dashboard.id
  policy = data.aws_iam_policy_document.dashboard_secrets.json
}

resource "aws_iam_instance_profile" "dashboard" {
  name_prefix = "${var.name_prefix}-dsh-"
  role        = aws_iam_role.dashboard.name
}

resource "aws_instance" "dashboard" {
  count                  = var.node_count
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = element(var.private_subnet_ids, count.index)
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.dashboard.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 40
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  # Require IMDSv2.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  # Dashboard configuration will be handled by Ansible/SSM.
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    # Indexer hosts:
    # ${join(",", var.indexer_private_ips)}
  EOT

  tags = merge(var.tags, {
    Name   = "${var.name_prefix}-dashboard-${count.index + 1}"
    Role   = "wazuh-dashboard"
    Backup = "true"
  })

  lifecycle {
    # Don't replace instances when the AMI data source changes.
    ignore_changes = [ami]
  }
}
