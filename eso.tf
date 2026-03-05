# -----------------------------------------------------------------------
# External Secrets Operator (ESO)
#
# ESO syncs secrets from AWS Secrets Manager into Kubernetes Secrets.
# Uses Pod Identity for secure IAM authentication (no static credentials).
#
# Resources created:
#   1. AWS Secrets Manager secret — ArgoCD admin password
#   2. IAM Role (Pod Identity) — allows ESO to read from Secrets Manager
#   3. Pod Identity association — links IAM role to ESO ServiceAccount
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# 1. AWS Secrets Manager — ArgoCD admin password
# -----------------------------------------------------------------------
resource "aws_secretsmanager_secret" "argocd_admin_password" {
  name        = "${var.project_name}/${var.environment}/argocd-admin-password"
  description = "ArgoCD admin password - managed by ESO"

  # Prevent accidental deletion
  recovery_window_in_days = 0 # Set to 0 for dev (instant delete), use 7-30 for prod

  tags = {
    Name = "argocd-admin-password"
  }
}

resource "aws_secretsmanager_secret_version" "argocd_admin_password" {
  secret_id = aws_secretsmanager_secret.argocd_admin_password.id

  secret_string = jsonencode({
    password = bcrypt(var.argocd_admin_password)
  })
}
# -----------------------------------------------------------------------
# 2. IAM Role for ESO — Pod Identity
#    Allows ESO to read secrets from Secrets Manager
# -----------------------------------------------------------------------
module "eso_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.5.0"

  name = "${local.cluster_name}-eso"

  # Custom policy — only allow reading from Secrets Manager
  additional_policy_arns = {
    eso = aws_iam_policy.eso_secrets_manager.arn
  }

  # Associate with ESO ServiceAccount
  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }

  tags = {
    Name = "${local.cluster_name}-eso"
  }

  depends_on = [
    module.eks,
    aws_iam_policy.eso_secrets_manager
  ]
}

# -----------------------------------------------------------------------
# IAM Policy — ESO Secrets Manager permissions
# Scoped to only the secrets this cluster needs
# -----------------------------------------------------------------------
resource "aws_iam_policy" "eso_secrets_manager" {
  name        = "${local.cluster_name}-eso-secrets-manager"
  description = "Allows ESO to read secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------
# Data source — AWS account ID
# -----------------------------------------------------------------------
data "aws_caller_identity" "current" {}
