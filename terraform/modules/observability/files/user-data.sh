#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Installing docker + compose ==="
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -a -G docker ec2-user

mkdir -p /usr/local/lib/docker/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/v2.30.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "=== Building observability stack ==="
mkdir -p /opt/observability/{prometheus,loki,grafana/provisioning/datasources,grafana/provisioning/dashboards,grafana/dashboards,otel,tempo}

# ---------------------------------------------------------------------------
# docker-compose.yml
# ---------------------------------------------------------------------------
cat >/opt/observability/docker-compose.yml <<'YAML'
services:
  prometheus:
    image: prom/prometheus:v3.0.0
    container_name: prometheus
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --web.enable-remote-write-receiver
      - --web.enable-lifecycle
      - --storage.tsdb.retention.time=15d
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prom_data:/prometheus
    ports: ["9090:9090"]

  loki:
    image: grafana/loki:3.2.0
    container_name: loki
    restart: unless-stopped
    command: -config.file=/etc/loki/config.yaml
    volumes:
      - ./loki/config.yaml:/etc/loki/config.yaml:ro
      - loki_data:/loki
    ports: ["3100:3100"]

  tempo:
    image: grafana/tempo:2.6.1
    container_name: tempo
    restart: unless-stopped
    command: -config.file=/etc/tempo/config.yaml
    volumes:
      - ./tempo/config.yaml:/etc/tempo/config.yaml:ro
      - tempo_data:/var/tempo
    ports:
      - "3200:3200"  # tempo HTTP

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.111.0
    container_name: otel-collector
    restart: unless-stopped
    command: --config=/etc/otel/config.yaml
    volumes:
      - ./otel/config.yaml:/etc/otel/config.yaml:ro
    ports:
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
    depends_on: [prometheus, loki, tempo]

  grafana:
    image: grafana/grafana:11.3.0
    container_name: grafana
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: __GRAFANA_PASSWORD__
      GF_AUTH_ANONYMOUS_ENABLED: "false"
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_INSTALL_PLUGINS: ""
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
      - grafana_data:/var/lib/grafana
    ports: ["3000:3000"]
    depends_on: [prometheus, loki, tempo]

volumes:
  prom_data:
  loki_data:
  tempo_data:
  grafana_data:
YAML

# substitui senha sem expor no log do user-data
sed -i "s|__GRAFANA_PASSWORD__|${grafana_admin_password}|" /opt/observability/docker-compose.yml

# ---------------------------------------------------------------------------
# prometheus.yml
# ---------------------------------------------------------------------------
cat >/opt/observability/prometheus/prometheus.yml <<'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: ${cluster_name}

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
YAML

# ---------------------------------------------------------------------------
# loki config (single-binary, filesystem)
# ---------------------------------------------------------------------------
cat >/opt/observability/loki/config.yaml <<'YAML'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  allow_structured_metadata: true
  retention_period: 168h

ruler:
  alertmanager_url: ""
YAML

# ---------------------------------------------------------------------------
# tempo config (single-binary)
# ---------------------------------------------------------------------------
cat >/opt/observability/tempo/config.yaml <<'YAML'
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4319
        grpc:
          endpoint: 0.0.0.0:4316

ingester:
  trace_idle_period: 10s
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: 168h

storage:
  trace:
    backend: local
    local:
      path: /var/tempo/blocks
    wal:
      path: /var/tempo/wal
YAML

# ---------------------------------------------------------------------------
# otel-collector config — recebe OTLP, fan-out pra Prom/Loki/Tempo
# ---------------------------------------------------------------------------
cat >/opt/observability/otel/config.yaml <<'YAML'
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 5s
  resource:
    attributes:
      - key: cluster
        value: ${cluster_name}
        action: upsert

exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    tls:
      insecure: true

  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    default_labels_enabled:
      exporter: true
      job: true

  otlphttp/tempo:
    endpoint: http://tempo:4319
    tls:
      insecure: true

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [resource, batch]
      exporters: [prometheusremotewrite]
    logs:
      receivers: [otlp]
      processors: [resource, batch]
      exporters: [loki]
    traces:
      receivers: [otlp]
      processors: [resource, batch]
      exporters: [otlphttp/tempo]
YAML

# ---------------------------------------------------------------------------
# Grafana datasources auto-provisioned
# ---------------------------------------------------------------------------
cat >/opt/observability/grafana/provisioning/datasources/datasources.yml <<'YAML'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: 15s

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    jsonData:
      tracesToLogsV2:
        datasourceUid: loki
        spanStartTimeShift: -1m
        spanEndTimeShift: 1m
        filterByTraceID: true
YAML

# ---------------------------------------------------------------------------
# Grafana dashboards auto-provisioned
# ---------------------------------------------------------------------------
cat >/opt/observability/grafana/provisioning/dashboards/dashboards.yml <<'YAML'
apiVersion: 1

providers:
  - name: 'fiap-fase3'
    orgId: 1
    folder: 'FIAP Fase 3'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
YAML

# Dashboard "Volume diário + Tempo por status + Erros + Latência"
cat >/opt/observability/grafana/dashboards/fiap-fase3-app.json <<'JSON'
{
  "title": "FIAP Fase 3 - API NestJS",
  "uid": "fiap-fase3-app",
  "tags": ["fiap", "fase3"],
  "timezone": "browser",
  "schemaVersion": 39,
  "refresh": "30s",
  "time": { "from": "now-6h", "to": "now" },
  "panels": [
    {
      "id": 1,
      "title": "Volume diário de OS criadas",
      "type": "timeseries",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "sum(increase(orders_created_total[1d]))", "legendFormat": "OSs criadas/dia" }
      ],
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 }
    },
    {
      "id": 2,
      "title": "Tempo médio por status (s)",
      "type": "timeseries",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "histogram_quantile(0.5, sum(rate(order_status_duration_seconds_bucket[5m])) by (le, to_status))", "legendFormat": "p50 {{to_status}}" }
      ],
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 }
    },
    {
      "id": 3,
      "title": "Erros HTTP 5xx",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "sum(rate(http_server_request_duration_seconds_count{http_response_status_code=~\"5..\"}[5m]))" }
      ],
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 8 }
    },
    {
      "id": 4,
      "title": "Latência p95 (s)",
      "type": "timeseries",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "histogram_quantile(0.95, sum(rate(http_server_request_duration_seconds_bucket[5m])) by (le, http_route))", "legendFormat": "{{http_route}}" }
      ],
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 8 }
    },
    {
      "id": 5,
      "title": "Logs JSON do app (últimas linhas)",
      "type": "logs",
      "datasource": { "type": "loki", "uid": "loki" },
      "targets": [
        { "expr": "{service_name=\"fiap-fase3-app\"} | json", "refId": "A" }
      ],
      "gridPos": { "h": 10, "w": 24, "x": 0, "y": 16 }
    }
  ]
}
JSON

echo "=== Starting stack ==="
cd /opt/observability
docker compose up -d

echo "=== Done. Grafana on :3000, OTLP on :4318 ==="
