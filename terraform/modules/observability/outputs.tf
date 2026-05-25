output "public_ip" {
  description = "IP público da VM (acesso à UI Grafana)"
  value       = aws_instance.observability.public_ip
}

output "private_ip" {
  description = "IP privado (usado pelos clientes OTLP do EKS e Lambdas)"
  value       = aws_instance.observability.private_ip
}

output "grafana_url" {
  description = "URL pública do Grafana"
  value       = "http://${aws_instance.observability.public_ip}:3000"
}

output "grafana_admin_password" {
  description = "Senha do usuário admin do Grafana"
  value       = random_password.grafana_admin.result
  sensitive   = true
}

output "otlp_http_endpoint" {
  description = "Endpoint OTLP HTTP pra app NestJS + Lambdas (intra-VPC)"
  value       = "http://${aws_instance.observability.private_ip}:4318"
}

output "security_group_id" {
  description = "Security group da VM"
  value       = aws_security_group.observability.id
}
