---
title: Aggregate Cluster Logs with Loki and Alloy
---

The cluster already has metrics through Grafana. This challenge adds logs to the same Grafana in three moves: stand up Loki to store logs, run Alloy to ship them, and connect Loki as a Grafana data source.

<!--more-->

## Install Loki

The Loki chart lives in the `grafana-community` repository. For a lab node that already runs Rancher and the monitoring stack, run Loki as a single binary with filesystem storage and every other scaling component turned off, so only one Loki pod starts. A values file keeps all those settings in one place:

```bash
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update

cat > loki-values.yaml <<'EOF'
deploymentMode: SingleBinary
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  useTestSchema: true
  auth_enabled: false
singleBinary:
  replicas: 1
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
gateway:
  enabled: false
lokiCanary:
  enabled: false
chunksCache:
  enabled: false
resultsCache:
  enabled: false
minio:
  enabled: false
EOF

helm install loki grafana-community/loki -n loki --create-namespace -f loki-values.yaml
kubectl -n loki rollout status statefulset/loki --timeout=300s
```

## Ship Logs with Alloy

Loki is waiting for data, so install Alloy to send it. Alloy runs as a DaemonSet - one agent per node - discovers pods, labels their log streams, and pushes them to Loki. Its chart is `grafana/alloy` (the classic `grafana` repo):

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

cat > alloy-values.yaml <<'EOF'
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
controller:
  type: daemonset
EOF

helm install alloy grafana/alloy -n alloy --create-namespace -f alloy-values.yaml
kubectl -n alloy rollout status daemonset/alloy --timeout=300s
```

## Query Logs in the Existing Grafana

The last move connects Loki to the Grafana you already run. Open the :tab{text='Grafana' name='Grafana'} tab, log in as `admin` (the password is in the `monitoring-grafana` secret), and under **Connections > Data sources** add a **Loki** source with the URL `http://loki.loki.svc.cluster.local:3100`. Save and test, then open **Explore**, select Loki, and run a query such as `{namespace="kube-system"}`. Log lines from across the cluster appear, all in the same Grafana that shows your metrics.

```bash
kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## Why One Grafana for Both

Loki was designed to sit next to Prometheus and share its labels, so a single Grafana can query metrics from Prometheus and logs from Loki using the same `namespace`, `pod`, and `container` labels. That is why the challenge has you reuse the monitoring Grafana rather than deploy a second one - it mirrors how a real cluster is run, where one Grafana is the single window onto both pillars.
