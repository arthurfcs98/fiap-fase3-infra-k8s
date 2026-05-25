resource "helm_release" "nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.11.3"
  atomic           = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      controller = {
        replicaCount = 1
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            # internal: NLB so com IPs privados na VPC.
            # API Gateway VPC Link só conecta com NLBs internos.
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internal"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "256Mi" }
        }
      }
    })
  ]
}

# Espera o NLB ficar com hostname (lazy data source pra capturar o resultado)
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.nginx]
}
