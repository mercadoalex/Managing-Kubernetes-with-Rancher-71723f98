---
title: Prometheus, Grafana, and a Custom Alert
---

Rancher Monitoring repackages the community `kube-prometheus-stack`, so installing that chart directly gives you the same Prometheus, Grafana, and Alertmanager - and the same place to hang your own alerts. You do all of this from the dev-machine workstation.

<!--more-->

## Install the Stack

Add the community repository and install the chart with modest resource requests so it fits alongside Rancher on this node:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=2h \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.requests.cpu=50m \
  --set alertmanager.alertmanagerSpec.resources.requests.cpu=25m \
  --set alertmanager.alertmanagerSpec.resources.requests.memory=64Mi
```

The chart installs the Prometheus operator, which registers the `monitoring.coreos.com` CRDs.

## Wait for the Components

Give the operator a moment, then watch the pods come up:

```bash
kubectl -n monitoring get pods -w
```

Prometheus pods carry `app.kubernetes.io/name=prometheus` and Grafana pods carry `app.kubernetes.io/name=grafana`. Once both show `Running`, the core stack is live.

## Cause a Failure

Give the alert something real to catch. Deploy a pod that crashes on start, so it enters a crash loop:

```bash
kubectl create namespace demo
kubectl -n demo run crasher --image=busybox --restart=Always -- /bin/sh -c "exit 1"
```

Within a minute it is in `CrashLoopBackOff` with a climbing restart count.

## Add an Alert on the Crash Loop

Create a `PrometheusRule` that alerts when the crasher's restart count crosses a threshold. The `release: monitoring` label matches the operator's ruleSelector so it gets adopted. The metric is a monotonic counter, so once it passes the threshold the alert stays true and reliably fires:

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
    - alert: PodCrashLooping
      expr: kube_pod_container_status_restarts_total{namespace="demo", pod=~"crasher.*"} > 3
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "The crasher pod is crash-looping"
EOF
```

## Watch It Fire

The alert moves from inactive to pending to firing. Crash-loop backoff, a scrape, and the one-minute `for:` window mean it takes a few minutes. Port-forward Prometheus and watch the Alerts page:

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

`PodCrashLooping` shows as Pending, then Firing. In a Rancher install the same rule would appear under Monitoring in the UI, and Alertmanager would route the firing alert to whichever receiver you configured. Avoid a sliding-window expression like `increase(...)` for this - it can dip under the threshold between scrapes and never complete the `for:` window; a monotonic counter threshold is dependable.
