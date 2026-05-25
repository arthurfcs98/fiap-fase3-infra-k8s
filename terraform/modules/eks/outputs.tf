output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true
}

output "cluster_arn" {
  value = aws_eks_cluster.main.arn
}

output "nodegroup_name" {
  value = aws_eks_node_group.main.node_group_name
}
