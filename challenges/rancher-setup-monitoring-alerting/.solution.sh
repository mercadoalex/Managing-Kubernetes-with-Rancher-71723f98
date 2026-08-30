#!/bin/bash
set -euo pipefail

# CI solution for "Deploy a Monitoring Stack and Define an Alert".
# Runs on the dev-machine workstation against the cluster (which also runs
# Rancher). Installs kube-prometheus-stack with trimmed resources so it fits
# alongside Rancher, then defines a custom alerting rule.

export KUBECONFIG=$HOME/.kube/config

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=2h \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set grafana.resources.requests.cpu=50m \
  --set grafana.resources.requests.memory=128Mi \
  --set alertmanager.alertmanagerSpec.resources.requests.cpu=25m \
  --set alertmanager.alertmanagerSpec.resources.requests.memory=64Mi

examinerctl task wait verify_prometheus_operator --timeout 180s

# Wait for Prometheus and Grafana to come up.
kubectl -n monitoring rollout status deployment/monitoring-grafana --timeout=300s
for i in $(seq 1 60); do
  if kubectl get pods -A -l app.kubernetes.io/name=prometheus \
      -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -q "Running"; then
    break
  fi
  sleep 5
done

examinerctl task wait verify_prometheus_running --timeout 180s
examinerctl task wait verify_grafana_running --timeout 180s

# Deploy a crash-looping pod so a real condition exists to alert on.
kubectl create namespace demo 2>/dev/null || true
kubectl -n demo run crasher --image=busybox --restart=Always -- /bin/sh -c "exit 1" 2>/dev/null || true

# Define a custom alerting rule on the crasher's restart count. The release
# label matches the operator's ruleSelector so the rule is adopted. The metric
# is a monotonic counter, so once it passes the threshold the alert stays true
# and reliably fires (unlike a sliding-window increase()).
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
    - alert: PodCrashLooping
      expr: kube_pod_container_status_restarts_total{namespace="demo", pod=~"crasher.*"} > 3
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "The crasher pod is crash-looping"
EOF

examinerctl task wait verify_custom_rule --timeout 60s
examinerctl task wait verify_alert_firing --timeout 480s
