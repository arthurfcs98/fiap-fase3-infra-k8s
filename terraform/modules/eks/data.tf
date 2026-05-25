# Roles pré-criadas pelo AWS Academy.
# Têm prefixos gerados (ex: c207442...-LabEksClusterRole-jH6Z...), por isso
# usamos regex para descobri-los dinamicamente.

data "aws_iam_roles" "lab_eks_cluster" {
  name_regex = ".*LabEksClusterRole.*"
}

data "aws_iam_role" "lab_eks_cluster" {
  name = tolist(data.aws_iam_roles.lab_eks_cluster.names)[0]
}

data "aws_iam_roles" "lab_eks_node" {
  name_regex = ".*LabEksNodeRole.*"
}

data "aws_iam_role" "lab_eks_node" {
  name = tolist(data.aws_iam_roles.lab_eks_node.names)[0]
}
