---
title: Prometheus, Grafana, and a Custom Alert
---

Rancher Monitoring repackages the community `kube-prometheus-stack`, so installing that chart directly gives you the same Prometheus, Grafana, and Alertmanager - and the same place to hang your own alerts.

<!--more-->

## Install the Stack

Add the community repository and install the chart with modest resource requests so it fits the lab VM:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.requests.cpu=50m
```

The chart installs the Prometheus operator, which registers the `monitoring.coreos.com` CRDs.

## Wait for the Components

Give the operator a moment, then watch the pods come up:

```bash
kubectl -n monitoring get pods -w
```

Prometheus pods carry `app.kubernetes.io/name=prometheus` and Grafana pods carry `app.kubernetes.io/name=grafana`. Once both show `Running`, the core stack is live.

## Add an Alert

Create a `PrometheusRule` with your own alerting rule. The `release: monitoring` label matches the operator's ruleSelector so it gets adopted:

```bash
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
```

Confirm the rule registered:

```bash
kubectl -n monitoring get prometheusrules
```

In a Rancher install, the same rule would appear under Monitoring in the UI, and Alertmanager would route it to whichever receiver you configured.
