---
kind: tutorial

title: Observability and Monitoring with Rancher

description: |
  Deploy the Rancher Monitoring stack (Prometheus and Grafana), configure alerting,
  set up centralized logging, and learn how to troubleshoot cluster issues.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Monitoring
  - Prometheus
  - Grafana
  - Logging
  - Observability
  - Alerting

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

Observability in Kubernetes means being able to answer three questions about your cluster and workloads:

- **Metrics** - what is happening now? (CPU, memory, request rates, error rates)
- **Logs** - what happened? (application output, system events)
- **Traces** - how did a request flow through the system? (distributed tracing)

Rancher ships a curated monitoring stack based on Prometheus and Grafana that integrates directly with the Rancher UI. This tutorial covers installing and using that stack, configuring alerts, and setting up centralized logging.

## The Rancher Monitoring Stack

Rancher Monitoring V2 is a Helm chart (`rancher-monitoring`) that deploys:

- **Prometheus** - time-series metrics collection and storage
- **Grafana** - visualization dashboards
- **Alertmanager** - alert routing and notification
- **Node Exporter** - host-level metrics (CPU, memory, disk, network per node)
- **kube-state-metrics** - Kubernetes object metrics (deployment status, pod counts, etc.)

All components are pre-configured to work together and integrated into the Rancher UI.

## Installing Rancher Monitoring

Install the monitoring chart from the Rancher chart catalog:

```bash
helm repo add rancher-charts https://charts.rancher.io
helm repo update
```

Install the monitoring stack:

```bash
helm install rancher-monitoring rancher-charts/rancher-monitoring \
  --namespace cattle-monitoring-system \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.requests.cpu=50m
```

The resource requests are set conservatively for the lab environment. In production, you would increase these based on cluster size.

Wait for all pods to start:

```bash
kubectl -n cattle-monitoring-system get pods -w
```

This takes a few minutes as Prometheus, Grafana, Alertmanager, and the exporters all start up.

## Verifying the Installation

Check that all monitoring components are running:

```bash
kubectl -n cattle-monitoring-system get deployments
kubectl -n cattle-monitoring-system get statefulsets
kubectl -n cattle-monitoring-system get daemonsets
```

You should see:
- `rancher-monitoring-grafana` (Deployment)
- `prometheus-rancher-monitoring-prometheus` (StatefulSet)
- `alertmanager-rancher-monitoring-alertmanager` (StatefulSet)
- `rancher-monitoring-prometheus-node-exporter` (DaemonSet)

## Accessing Grafana

Grafana is accessible through the Rancher UI under **Monitoring > Grafana**. You can also port-forward to access it directly:

```bash
kubectl -n cattle-monitoring-system port-forward svc/rancher-monitoring-grafana 3000:80 &
```

Default credentials are `admin` / `prom-operator` (configured in the Helm values).

Grafana comes pre-loaded with dashboards for:
- Kubernetes cluster overview
- Node resource usage
- Pod and container metrics
- Networking
- Persistent volumes

## Querying Metrics with PromQL

Prometheus stores metrics as time series. You can query them using PromQL.

Access the Prometheus UI:

```bash
kubectl -n cattle-monitoring-system port-forward svc/rancher-monitoring-prometheus 9090:9090 &
```

Example queries:

Total CPU usage across all nodes:

```promql
sum(rate(node_cpu_seconds_total{mode!="idle"}[5m]))
```

Memory usage percentage per node:

```promql
100 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100)
```

Pod restart count:

```promql
sum(kube_pod_container_status_restarts_total) by (namespace, pod)
```

Running pod count per namespace:

```promql
count(kube_pod_status_phase{phase="Running"}) by (namespace)
```

## Configuring Alerts

Alerts in the Rancher monitoring stack are defined as PrometheusRule resources. They fire when a PromQL expression evaluates to true for a specified duration.

Create a custom alert for high memory usage:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: cattle-monitoring-system
  labels:
    app: rancher-monitoring
    release: rancher-monitoring
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
        description: "Node {{ \$labels.instance }} memory usage is above 85% for 5 minutes."
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod crash looping"
        description: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} is restarting frequently."
EOF
```

Verify the alert rules are loaded:

```bash
kubectl -n cattle-monitoring-system get prometheusrules
```

## Alertmanager Configuration

Alertmanager routes alerts to notification channels (email, Slack, PagerDuty, webhooks). The default configuration groups alerts and sends them to a default receiver.

Check the current Alertmanager configuration:

```bash
kubectl -n cattle-monitoring-system get secret alertmanager-rancher-monitoring-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
```

To add a webhook receiver, update the Alertmanager configuration via a Secret or through the Rancher UI under **Monitoring > Alertmanager Configs**.

## Centralized Logging

While Prometheus handles metrics, logs require a separate pipeline. The common approach in Rancher environments is:

**Log collection** - a DaemonSet (Fluentd, Fluent Bit, or Promtail) runs on every node and tails container logs from `/var/log/containers/`.

**Log aggregation** - logs are forwarded to a central store (Elasticsearch, Loki, or a cloud logging service).

**Log visualization** - Grafana (with Loki) or Kibana (with Elasticsearch) provides search and analysis.

### Installing Logging with Rancher

Rancher provides a logging chart that deploys Fluent Bit for collection:

```bash
helm install rancher-logging rancher-charts/rancher-logging \
  --namespace cattle-logging-system \
  --create-namespace
```

Once installed, you define **ClusterFlow** and **ClusterOutput** resources to route logs:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: logging.banzaicloud.io/v1beta1
kind: ClusterOutput
metadata:
  name: stdout-output
  namespace: cattle-logging-system
spec:
  stdout: {}
---
apiVersion: logging.banzaicloud.io/v1beta1
kind: ClusterFlow
metadata:
  name: all-logs
  namespace: cattle-logging-system
spec:
  match:
  - select: {}
  globalOutputRefs:
  - stdout-output
EOF
```

This basic configuration captures all cluster logs. In production, you would route them to Elasticsearch or Loki.

## Viewing Logs from the CLI

Even without a centralized logging stack, you can inspect logs directly:

Pod logs:

```bash
kubectl logs -n cattle-system deployment/rancher --tail=50
```

Logs from all pods in a namespace:

```bash
kubectl -n cattle-system logs --all-containers -l app=rancher --tail=20
```

Previous container logs (useful for crash loops):

```bash
kubectl logs -n default <pod-name> --previous
```

## Troubleshooting Common Issues

### Pod Stuck in Pending

Check events and node resources:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl top nodes
```

Common causes: insufficient CPU/memory, unschedulable nodes, or missing PersistentVolumes.

### Pod in CrashLoopBackOff

Check container logs and exit codes:

```bash
kubectl logs <pod-name> -n <namespace>
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Last State"
```

Common causes: misconfigured environment variables, missing secrets, or application errors.

### High Resource Usage

Identify resource-hungry pods:

```bash
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu
```

Compare actual usage against requests and limits:

```bash
kubectl describe node | grep -A5 "Allocated resources"
```

### Rancher Components Unhealthy

Check the health of Rancher's own components:

```bash
kubectl -n cattle-system get pods
kubectl -n cattle-fleet-system get pods
kubectl -n cattle-monitoring-system get pods
```

View Rancher server logs for errors:

```bash
kubectl -n cattle-system logs deployment/rancher --tail=100 | grep -i error
```

## Summary

You have deployed the full Rancher observability stack - Prometheus for metrics, Grafana for visualization, Alertmanager for notifications, and logging for event history. You also learned practical troubleshooting techniques for common Kubernetes issues. These tools give you visibility into cluster health, workload performance, and application behavior - completing the operational picture for managing Kubernetes with Rancher.
