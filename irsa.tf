# -----------------------------------------------------------------------
# AWS Load Balancer Controller — Pod Identity + Helm
#
# Pod Identity is the modern replacement for IRSA (as of LBC v2.7.0+).
# It is simpler:
#   - No OIDC provider needed
#   - No annotation on the ServiceAccount
#   - Same trust principal (pods.eks.amazonaws.com) works across all clusters
#   - AWS rotates credentials automatically
#
# The eks-pod-identity module (v2.5.0) handles:
#   1. IAM Role with correct trust policy (pods.eks.amazonaws.com)
#   2. The official LBC IAM policy (attach_aws_lb_controller_policy = true)
#   3. The aws_eks_pod_identity_association resource
#
# -----------------------------------------------------------------------

module "aws_lbc_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.5.0"

  name = "${local.cluster_name}-aws-lbc"

  # This flag creates and attaches the official AWS LBC IAM policy automatically
  # Source: https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
  attach_aws_lb_controller_policy = true

  # Associate the role with the LBC ServiceAccount in the cluster
  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = {
    Name = "${local.cluster_name}-aws-lbc"
  }

  depends_on = [module.eks]
}