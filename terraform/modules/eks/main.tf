resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.lab_eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = var.cluster_name
  }
}

# NOTE: o `bootstrap_cluster_creator_admin_permissions = true` acima já cria
# automaticamente uma EKS Access Entry para o criador (a role atual da
# sessão Terraform, ex: voclabs). Tentar criar outra explicitamente resulta
# em ResourceInUseException (409). A admin_role_arn permanece como variável
# para compatibilidade futura; se precisar adicionar OUTRO admin (ex: uma
# role distinta), criar um novo `aws_eks_access_entry` com nome diferente.

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = data.aws_iam_role.lab_eks_node.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"
  ami_type       = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${var.cluster_name}-ng"
  }
}
