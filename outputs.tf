# -----------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------

# --- Cluster ---
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_region" {
  description = "AWS region the cluster is deployed in"
  value       = var.aws_region
}

output "configure_kubectl" {
  description = "Run this command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# --- Networking ---
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (where worker nodes run)"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (where the ALB is created)"
  value       = module.vpc.public_subnets
}

# --- ECR ---
output "ecr_repository_url" {
  description = "ECR repository URL — use this in your CI/CD pipeline to push images"
  value       = aws_ecr_repository.hello_world.repository_url
}

output "ecr_registry" {
  description = "ECR registry hostname (account.dkr.ecr.region.amazonaws.com)"
  value       = split("/", aws_ecr_repository.hello_world.repository_url)[0]
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — use this in your GHA workflow"
  value       = aws_iam_role.github_actions.arn
}

# --- OIDC ---
output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster (used for IRSA)"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (used for IRSA trust policies)"
  value       = module.eks.oidc_provider_arn
}
