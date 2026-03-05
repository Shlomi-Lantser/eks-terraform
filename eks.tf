# -----------------------------------------------------------------------
# EKS Cluster
# Uses terraform-aws-modules/eks/aws ~> 21.0 (latest: 21.15.1)
# -----------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # Worker nodes in private subnets

  # Set cluster_endpoint_public_access = false + VPN/bastion for production.
  endpoint_public_access  = true
  endpoint_private_access = true

  # Grants the Terraform caller cluster-admin automatically.
  enable_cluster_creator_admin_permissions = true

  # -----------------------------------------------------------------------
  # EKS Managed Add-ons
  # most_recent = true lets AWS pick the latest compatible version automatically
  # -----------------------------------------------------------------------
  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    # before_compute = true ensures vpc-cni is deployed BEFORE nodes boot up
    # Without this, nodes start without CNI → "cni plugin not initialized" error
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    # before_compute = true ensures Pod Identity agent is ready before nodes
    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true
    }
  }

  # -----------------------------------------------------------------------
  # Managed Node Group
  # -----------------------------------------------------------------------
  eks_managed_node_groups = {
    default = {
      # use_custom_launch_template = false lets us set disk_size directly.
      # When true (the default), disk_size is ignored and you'd need to
      # configure block_device_mappings in the launch template instead.
      use_custom_launch_template = false

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      disk_size      = 50

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        role = "general"
      }
    }
  }
  create_cloudwatch_log_group = false
}
