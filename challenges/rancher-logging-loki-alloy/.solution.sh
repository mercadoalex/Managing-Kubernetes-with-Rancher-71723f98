#!/bin/bash
set -euo pipefail

# CI solution for "Aggregate Cluster Logs with Loki and Alloy".
# Runs on the dev-machine workstation against the cluster (which also runs
# Rancher and, from the init task, the monitoring stack / Grafana).
#
# Installs Loki (single-binary, filesystem) and Alloy (DaemonSet shipper),
# then adds a Loki datasource to the existing Grafana via its API. Validated
# live on rancher-k3s-e09b66ec.

export KUBECONFIG=$HOME/.kube/config

helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 1. Loki - single binary, filesystem storage, everything heavy disabled.
cat > /tmp/loki-values.yaml <<'EOF'
deploymentMode: SingleBinary
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  useTestSchema: true
  limits_config:
    retention_period: 24h
    allow_structured_metadata: true
    volume_enabled: true
  auth_enabled: false
singleBinary:
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
  persistence:
    enabled: false
backend: {replicas: 0}
read: {replicas: 0}
write: {replicas: 0}
ingester: {replicas: 0}
querier: {replicas: 0}
queryFrontend: {replicas: 0}
queryScheduler: {replicas: 0}
distributor: {replicas: 0}
compactor: {replicas: 0}
indexGateway: {replicas: 0}
bloomPlanner: {replicas: 0}
bloomBuilder: {replicas: 0}
bloomGateway: {replicas: 0}
gateway:
  enabled: false
lokiCanary:
  enabled: false
monitoring:
  selfMonitoring:
    enabled: false
    grafanaAgent:
      installOperator: false
chunksCache:
  enabled: false
resultsCache:
  enabled: false
minio:
  enabled: false
test:
  enabled: false
EOF

if ! helm status loki -n loki >/dev/null 2>&1; then
  helm install loki grafana-community/loki \
    --namespace loki --create-namespace \
    -f /tmp/loki-values.yaml
fi
kubectl -n loki rollout status statefulset/loki --timeout=300s

examinerctl task wait verify_loki_running --timeout 300s

# 2. Alloy - DaemonSet shipper pushing to Loki.
cat > /tmp/alloy-values.yaml <<'EOF'
alloy:
  configMap:
    content: |-
      discovery.kubernetes "pods" {
        role = "pod"
      }

      discovery.relabel "pod_logs" {
        targets = discovery.kubernetes.pods.targets

        rule {
          source_labels = ["__meta_kubernetes_namespace"]
          target_label  = "namespace"
        }
        rule {
          source_labels = ["__meta_kubernetes_pod_name"]
          target_label  = "pod"
        }
        rule {
          source_labels = ["__meta_kubernetes_pod_container_name"]
          target_label  = "container"
        }
        rule {
          source_labels = ["__meta_kubernetes_node_name"]
          target_label  = "node"
        }
      }

      loki.source.kubernetes "pods" {
        targets    = discovery.relabel.pod_logs.output
        forward_to = [loki.write.default.receiver]
      }

      loki.write "default" {
        endpoint {
          url = "http://loki.loki.svc.cluster.local:3100/loki/api/v1/push"
        }
      }
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
controller:
  type: daemonset
EOF

if ! helm status alloy -n alloy >/dev/null 2>&1; then
  helm install alloy grafana/alloy \
    --namespace alloy --create-namespace \
    -f /tmp/alloy-values.yaml
fi
kubectl -n alloy rollout status daemonset/alloy --timeout=300s

examinerctl task wait verify_alloy_shipping --timeout 240s

# 3. Add Loki as a datasource in the existing Grafana via its API.
GPASS=$(kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d)

pkill -f "port-forward.*34302:80" 2>/dev/null || true
kubectl -n monitoring port-forward svc/monitoring-grafana 34302:80 >/tmp/pf_sol.log 2>&1 &
PF=$!
sleep 6

# Only add it if a Loki datasource does not already exist.
EXISTING=$(curl -sf -u "admin:${GPASS}" 'http://127.0.0.1:34302/api/datasources' 2>/dev/null \
  | tr '}' '\n' | grep '"type":"loki"' | head -1 || true)
if [ -z "${EXISTING}" ]; then
  curl -sf -u "admin:${GPASS}" -X POST 'http://127.0.0.1:34302/api/datasources' \
    -H 'Content-Type: application/json' \
    -d '{"name":"Loki","type":"loki","access":"proxy","url":"http://loki.loki.svc.cluster.local:3100","isDefault":false}' \
    >/dev/null || true
fi
kill $PF 2>/dev/null || true

examinerctl task wait verify_logs_queryable --timeout 300s
