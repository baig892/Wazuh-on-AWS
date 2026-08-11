# Daily EBS backups for Wazuh nodes.
# Resources are selected by the Backup=true tag so new nodes are included automatically.

resource "aws_backup_vault" "wazuh" {
  name        = "${var.name_prefix}-backup-vault"
  kms_key_arn = var.kms_key_arn
  tags        = var.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name_prefix        = "${var.name_prefix}-backup-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_plan" "wazuh" {
  name = "${var.name_prefix}-backup-plan"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.wazuh.name
    schedule          = "cron(0 3 * * ? *)" # 03:00 UTC "you change this to your preferred time
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = var.retention_days
    }

    dynamic "copy_action" {
      for_each = var.dr_vault_arn == null ? [] : [1]

      content {
        destination_vault_arn = var.dr_vault_arn

        lifecycle {
          delete_after = var.retention_days
        }
      }
    }
  }

  tags = var.tags
}

# Back up instances with Backup=true.
resource "aws_backup_selection" "wazuh" {
  name         = "${var.name_prefix}-backup-selection"
  plan_id      = aws_backup_plan.wazuh.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
}
