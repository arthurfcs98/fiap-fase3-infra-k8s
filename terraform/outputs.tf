output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "IDs das subnets públicas (usadas por EKS, RDS, Lambda)"
  value       = module.vpc.public_subnet_ids
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = module.vpc.vpc_cidr
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "CA do cluster (base64)"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "nlb_dns" {
  description = "DNS do NLB criado pelo NGINX Ingress Controller"
  value       = module.ingress.nlb_dns
}

output "nlb_hosted_zone_id" {
  description = "Hosted zone ID do NLB (útil para Route 53 alias)"
  value       = module.ingress.nlb_hosted_zone_id
}

output "kubectl_config_command" {
  description = "Comando para configurar o kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --profile fiap"
}
