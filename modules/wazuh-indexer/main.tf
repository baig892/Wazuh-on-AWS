data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]

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

# IAM role for the indexer nodes.
resource "aws_iam_role" "indexer" {
  name_prefix        = "${var.name_prefix}-idx-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.indexer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow the indexer to read its secrets.
data "aws_iam_policy_document" "indexer_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.indexer_admin_secret_arn]
  }

  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "indexer_secrets" {
  name   = "${var.name_prefix}-idx-secrets"
  role   = aws_iam_role.indexer.id
  policy = data.aws_iam_policy_document.indexer_secrets.json
}

resource "aws_iam_instance_profile" "indexer" {
  name_prefix = "${var.name_prefix}-idx-"
  role        = aws_iam_role.indexer.name
}

# Indexer nodes are spread across the private subnets.
resource "aws_instance" "indexer" {
  count                   = var.node_count
  ami                     = local.ami_id
  instance_type           = var.instance_type
  subnet_id               = element(var.private_subnet_ids, count.index)
  vpc_security_group_ids  = [var.security_group_id]
  iam_instance_profile    = aws_iam_instance_profile.indexer.name
  key_name                = var.key_pair_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 40
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, {
    Name   = "${var.name_prefix}-indexer-${count.index + 1}"
    Role   = "wazuh-indexer"
    Backup = "true"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# Separate encrypted EBS volume for index data.
resource "aws_ebs_volume" "indexer_data" {
  count             = var.node_count
  availability_zone = aws_instance.indexer[count.index].availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-indexer-data-${count.index + 1}"
  })
}

resource "aws_volume_attachment" "indexer_data" {
  count       = var.node_count
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.indexer_data[count.index].id
  instance_id = aws_instance.indexer[count.index].id
}

# TODO: Configure the indexer cluster and mount the data volume.
# TODO: Add ISM and S3 snapshot configuration.