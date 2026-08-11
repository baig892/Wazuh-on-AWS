provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "wazuh-siem"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Second region for DR (Backup & Restore - S3 CRR target + cross-region
# EBS snapshot copy vault). Only resolved/used when var.enable_dr is true;
# otherwise this provider config exists but nothing is ever created with it.

provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      Project     = "wazuh-siem"
      Environment = var.environment
      ManagedBy   = "terraform"
      DR          = "true"
    }
  }
}
