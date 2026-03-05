# -----------------------------------------------------------------------
# ECR Repository
# Equivalent to Azure Container Registry (ACR)
# -----------------------------------------------------------------------

resource "aws_ecr_repository" "hello_world" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE" # Allow overwriting tags (e.g. "latest")

  image_scanning_configuration {
    scan_on_push = true # Scan images for CVEs on every push
  }

  tags = {
    Name = var.ecr_repository_name
  }
}

# Lifecycle policy — keep only the last 10 images to save storage costs
resource "aws_ecr_lifecycle_policy" "hello_world" {
  repository = aws_ecr_repository.hello_world.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------
# IAM policy to allow GitHub Actions to push to ECR
# Attach this to the OIDC role used by your GitHub Actions workflow.
# See: https://docs.github.com/en/actions/security-for-github-actions/
#      security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
# -----------------------------------------------------------------------

# OIDC provider for GitHub Actions — allows keyless auth from GHA to AWS
# This is the AWS equivalent of Azure's Federated Identity Credential
data "aws_iam_openid_connect_provider" "github" {
  count = 0 # Set to 1 after manually creating the OIDC provider (see README)
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint for token.actions.githubusercontent.com (stable, maintained by GitHub)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1",
  "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_actions" {
  name        = "${local.cluster_name}-github-actions"
  description = "IAM role assumed by GitHub Actions via OIDC (keyless auth)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            # Scope to your specific repo — replace with your GitHub org/repo
            "token.actions.githubusercontent.com:sub" = "repo:Shlomi-Lantser/hello-world-app:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = aws_ecr_repository.hello_world.arn
      }
    ]
  })
}

# Allow GitHub Actions to also update the deployments repo via git
# (needed for the image tag update step in CI/CD)
resource "aws_iam_role_policy" "github_actions_eks_describe" {
  name = "eks-describe"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}
