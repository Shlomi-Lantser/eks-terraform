terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0",
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
  }

  backend "s3" {
    bucket         = "terraform-tfstates-shlomi"
    key            = "eks-hello-world/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    use_lockfile = true
    profile = "assignment-profile"
  }
 }

provider "aws" {
  region  = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
