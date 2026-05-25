# Promtail DaemonSet — coleta stdout dos pods do EKS, parseia JSON do
# pino-http, e empurra pra Loki na VM observability via VPC privada.
#
# Pipeline:
# 1. Lê /var/log/pods/*/*/*.log (todos os containers)
# 2. Decodifica formato cri/docker (JSON wrapper)
# 3. Parseia o body (que JÁ É JSON do pino)
# 4. Promove `correlationId`, `level`, `service` para labels Loki

resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  namespace        = "monitoring"
  create_namespace = true
  version          = "6.16.6"
  atomic           = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "${var.loki_endpoint}/loki/api/v1/push"
            # batching pra reduzir requests
            batchwait = "1s"
            batchsize = 1048576
          }
        ]
        snippets = {
          extraScrapeConfigs = <<-EOT
            - job_name: kubernetes-pods-json
              kubernetes_sd_configs:
                - role: pod
              pipeline_stages:
                - cri: {}
                - json:
                    expressions:
                      level: level
                      time: time
                      correlationId: correlationId
                      msg: msg
                      service: service
                - labels:
                    level:
                    correlationId:
                    service:
                - timestamp:
                    source: time
                    format: RFC3339Nano
              relabel_configs:
                - source_labels: [__meta_kubernetes_namespace]
                  target_label: namespace
                - source_labels: [__meta_kubernetes_pod_name]
                  target_label: pod
                - source_labels: [__meta_kubernetes_pod_container_name]
                  target_label: container
                - source_labels: [__meta_kubernetes_pod_label_app]
                  target_label: app
                - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_name]
                  target_label: __path__
                  separator: /
                  replacement: /var/log/pods/*$1/*.log
          EOT
        }
      }
      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "200m", memory = "128Mi" }
      }
    })
  ]
}
