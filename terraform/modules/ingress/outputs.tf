output "nlb_dns" {
  description = "DNS público do NLB criado pelo Service ingress-nginx-controller"
  value = try(
    data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname,
    "pending-provisioning"
  )
}

output "nlb_hosted_zone_id" {
  description = "Hosted zone ID do NLB"
  value = try(
    data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname,
    ""
  ) != "" ? "Z26RNL4JYFTOTI" : "" # us-east-1 NLB hosted zone fixo
}
