---
kind: lesson

title: Observability and Monitoring
description: |
  Install the Prometheus and Grafana stack that Rancher Monitoring is built on, then define an alert.

name: observability-monitoring
slug: observability-monitoring

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- monitoring
- grafana

# cover: __static__/cover.png

# Single-cluster playground with Rancher pre-installed (dev-machine workstation
# model). The monitoring stack is installed from the workstation with Helm.
# TODO(publish): confirm/replace the suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

challenges:
  rancher-setup-monitoring-alerting-b06f9359: {}

tasks:
  # Verification runs on the dev-machine workstation as laborant, against the
  # cluster via the pre-provisioned kubeconfig.
  verify_prometheus_running:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl get pods -A -l app.kubernetes.io/name=prometheus \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Prometheus pod yet"
        exit 1
      fi
      echo "Prometheus is running"

  verify_grafana_running:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl get pods -A -l app.kubernetes.io/name=grafana \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Grafana pod yet"
        exit 1
      fi
      echo "Grafana is running"

  # First, a custom PrometheusRule (beyond the ones the stack ships) exists and
  # was adopted. The stack's own rules are all named monitoring-kube-prometheus-*,
  # so excluding "kube-prometheus" isolates the student's rule.
  verify_custom_rule:
    machine: dev-machine
    user: laborant
    needs:
      - verify_prometheus_running
    run: |
      export KUBECONFIG=$HOME/.kube/config
      RULE=$(kubectl get prometheusrules.monitoring.coreos.com -A \
        -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null \
        | grep -v "kube-prometheus" | head -n1)
      if [ -z "${RULE}" ]; then
        echo "No custom PrometheusRule found yet"
        exit 1
      fi
      echo "Custom PrometheusRule found: ${RULE}"

  # Then, the alert must actually be FIRING - proof that a real condition (the
  # crash-looping pod) tripped it. We query Prometheus's API for an alert in the
  # firing state. Crash-loop backoff + scrape + the rule's for: window take a few
  # minutes, hence the generous timeout.
  verify_alert_firing:
    machine: dev-machine
    user: laborant
    needs:
      - verify_custom_rule
    timeout_seconds: 480
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 40); do
        FIRING=$(kubectl -n monitoring exec \
          prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus -- \
          wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=ALERTS{alertstate="firing"}' 2>/dev/null \
          | grep -o '"alertstate":"firing"' | head -1)
        if [ -n "${FIRING}" ]; then
          echo "An alert is firing"
          exit 0
        fi
        sleep 10
      done
      echo "No alert is firing yet. Make sure your crash-looping pod is restarting and your rule's condition is met."
      exit 1
---
