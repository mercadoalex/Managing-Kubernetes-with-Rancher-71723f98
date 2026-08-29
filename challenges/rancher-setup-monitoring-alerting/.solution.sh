#!/bin/bash
set -euo pipefail

# Install the kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.requests.cpu=50m

examinerctl task wait verify_prometheus_operator --timeout 120s

# Wait for Prometheus and Grafana to come up
kubectl -n monitoring rollout status deployment/monitoring-grafana --timeout=240s
for i in $(seq 1 60); do
  if kubectl get pods -A -l app.kubernetes.io/name=prometheus \
      -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -q "Running"; then
    break
  fi
  sleep 5
done

examinerctl task wait verify_prometheus_running --timeout 120s
examinerctl task wait verify_grafana_running --timeout 120s

# Define a custom alerting rule
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: monitoring
  labels:
    release: monitoring
spec:
  groups:
  - name: custom.rules
    rules:
    - alert: HighMemoryUsage
      expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Node memory usage has been above 85% for 5 minutes."
EOF

examinerctl task wait verify_alert_rule --timeout 30s
