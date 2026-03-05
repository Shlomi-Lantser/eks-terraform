# -----------------------------------------------------------------------
# VPC
# Uses terraform-aws-modules/vpc/aws v6.6.0
# -----------------------------------------------------------------------

locals {
  cluster_name = "${var.project_name}-${var.environment}-cluster"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # NAT Gateway — single for cost savings in dev/test.
  # Set single_nat_gateway = false + one_nat_gateway_per_az = true for production HA.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Required for EKS and AWS LB Controller
  enable_dns_hostnames = true
  enable_dns_support   = true

  # -----------------------------------------------------------------------
  # Subnet tags required by EKS and the AWS Load Balancer Controller
  # These tags tell the LB controller which subnets to use for ALBs.
  # -----------------------------------------------------------------------
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}
