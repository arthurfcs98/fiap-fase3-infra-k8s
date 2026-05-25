data "aws_caller_identity" "current" {}

# AWS Academy nega iam:GetRole em `voclabs`, então não podemos usar
# `aws_iam_session_context`. Construímos o ARN base manualmente a partir
# do ARN da sessão assumida:
#   arn:aws:sts::ACCOUNT:assumed-role/ROLE_NAME/SESSION_NAME
#   →  arn:aws:iam::ACCOUNT:role/ROLE_NAME
locals {
  caller_role_name = element(split("/", data.aws_caller_identity.current.arn), 1)
  caller_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.caller_role_name}"
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
  region       = var.region
}

module "eks" {
  source = "./modules/eks"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  subnet_ids          = module.vpc.public_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  admin_role_arn      = local.caller_role_arn
}

module "ingress" {
  source = "./modules/ingress"

  depends_on = [module.eks]
}

module "observability" {
  source = "./modules/observability"

  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  vpc_cidr      = module.vpc.vpc_cidr
  cluster_name  = var.cluster_name
  instance_type = "t3.small"
}
