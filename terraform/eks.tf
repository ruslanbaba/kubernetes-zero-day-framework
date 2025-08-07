variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "zero-day-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "prod"
    Project     = "zero-day-framework"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "zero-day-eks"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    spot = {
      min_size     = 1
      max_size     = 5
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      labels = {
        Environment = "prod"
        Project     = "zero-day-framework"
      }

      tags = {
        ExtraTag = "zero-day-worker"
      }
    }
  }

  # Enable IRSA
  enable_irsa = true

  # Add security groups
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "Node all egress"
      protocol                   = "-1"
      from_port                 = 0
      to_port                   = 0
      type                      = "egress"
      source_node_security_group = true
    }
  }
}
