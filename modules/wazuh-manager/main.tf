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

  # First node is the cluster master; remaining nodes are workers.
  manager_roles = [for i in range(var.node_count) : i == 0 ? "master" : "worker"]
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

resource "aws_iam_role" "manager" {
  name_prefix        = "${var.name_prefix}-mgr-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# SSM is used for instance access instead of SSH.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.manager.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow managers to retrieve the cluster key.
data "aws_iam_policy_document" "manager_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.cluster_key_secret_arn]
  }

  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "manager_secrets" {
  name   = "${var.name_prefix}-mgr-secrets"
  role   = aws_iam_role.manager.id
  policy = data.aws_iam_policy_document.manager_secrets.json
}

resource "aws_iam_instance_profile" "manager" {
  name_prefix = "${var.name_prefix}-mgr-"
  role        = aws_iam_role.manager.name
}

resource "aws_instance" "manager" {
  count                  = var.node_count
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = element(var.private_subnet_ids, count.index)
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.manager.name
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

  # Wazuh configuration will be handled by Ansible/SSM.
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
  EOT

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-manager-${count.index + 1}"
    Role        = "wazuh-manager"
    ManagerRole = local.manager_roles[count.index]
    Backup      = "true"
  })

  lifecycle {
    # Don't replace instances when the AMI data source changes.
    ignore_changes = [ami]
  }
}
