# -----------------------------------------------------------------------
# Crossplane IAM
#
# Crossplane needs an IAM role to provision AWS resources on your behalf.
# Uses Pod Identity (same pattern as ESO and LBC).
#
# Resources created:
#   1. IAM Role (Pod Identity) — allows Crossplane to manage S3, IAM etc.
#   2. Pod Identity association — links IAM role to Crossplane ServiceAccount
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# 1. IAM Policy — Crossplane S3 permissions
#    Scoped to only S3 for this demo
#    Extend with additional actions if you want Crossplane to manage more resources
# -----------------------------------------------------------------------
resource "aws_iam_policy" "crossplane_s3" {
  name        = "${local.cluster_name}-crossplane-s3"
  description = "Allows Crossplane AWS provider to manage S3 buckets"

policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Base Bucket Operations
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",

          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls",
          "s3:DeleteBucketOwnershipControls",

          # Policies and Security
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",

          # Tags and Versioning
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:DeleteBucketTagging",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",

          # Lifecycle and Configuration
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:PutAccelerateConfiguration",
          "s3:GetBucketCORS",
          "s3:PutBucketCORS",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetBucketRequestPayment",
          "s3:PutBucketRequestPayment",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:PutReplicationConfiguration",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetBucketObjectLockConfiguration",
          "s3:PutBucketObjectLockConfiguration",

          # Multipart Uploads
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------
# 2. IAM Role for Crossplane — Pod Identity
# -----------------------------------------------------------------------
module "crossplane_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.5.0"

  name = "${local.cluster_name}-crossplane"

  additional_policy_arns = {
    s3 = aws_iam_policy.crossplane_s3.arn
  }

  # Associate with Crossplane AWS provider ServiceAccount
  # The SA name is always "upbound-provider-aws-s3" for the S3 family provider
  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "crossplane-system"
      service_account = "upbound-provider-aws-s3"
    }
  }

  tags = {
    Name = "${local.cluster_name}-crossplane"
  }

  depends_on = [
    module.eks,
    aws_iam_policy.crossplane_s3
  ]
}
