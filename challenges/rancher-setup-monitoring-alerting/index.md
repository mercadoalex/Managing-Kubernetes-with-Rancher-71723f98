---
kind: challenge

title: 'Deploy a Monitoring Stack and Define an Alert'

description: |
  Install a Prometheus and Grafana monitoring stack on a Kubernetes cluster, then define a PrometheusRule alert.
  This is the same kube-prometheus-stack that Rancher Monitoring is built on, exercised directly so you understand what it deploys.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Monitoring
  - Prometheus
  - Grafana
  - Alerting

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare

tasks:
  init_wait_k3s:
    init: true
    run: |
      for i in $(seq 1 30); do
        if kubectl get nodes | grep -q " Ready"; then
          exit 0
        fi
        sleep 2
      done
      echo "K3s did not become ready in time"
      exit 1

  verify_prometheus_operator:
    run: |
      rm -f /tmp/verify_prom_operator_hint.txt

      # The kube-prometheus-stack installs the Prometheus operator, which
      # registers the monitoring.coreos.com CRDs. Without them, no alert can exist.
      if ! kubectl get crd prometheuses.monitoring.coreos.com >/dev/null 2>&1; then
        echo "The Prometheus operator CRDs are not installed yet" | tee /tmp/verify_prom_operator_hint.txt
        exit 1
      fi
      if ! kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1; then
        echo "The PrometheusRule CRD is not installed yet" | tee /tmp/verify_prom_operator_hint.txt
        exit 1
      fi

      echo "Prometheus operator CRDs are present"
    hintcheck: |
      if [ -f /tmp/verify_prom_operator_hint.txt ]; then
        cat /tmp/verify_prom_operator_hint.txt
        rm -f /tmp/verify_prom_operator_hint.txt
      fi

  verify_prometheus_running:
    needs:
      - verify_prometheus_operator
    run: |
      rm -f /tmp/verify_prom_run_hint.txt

      # A Prometheus custom resource managed by the operator produces a
      # prometheus-* pod. Look for a running Prometheus pod in any namespace.
      READY=$(kubectl get pods -A -l app.kubernetes.io/name=prometheus \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Prometheus pod found. The monitoring stack may still be starting." | tee /tmp/verify_prom_run_hint.txt
        exit 1
      fi

      echo "Prometheus is running"
    hintcheck: |
      if [ -f /tmp/verify_prom_run_hint.txt ]; then
        cat /tmp/verify_prom_run_hint.txt
        rm -f /tmp/verify_prom_run_hint.txt
      fi

  verify_grafana_running:
    needs:
      - verify_prometheus_operator
    run: |
      rm -f /tmp/verify_grafana_hint.txt

      READY=$(kubectl get pods -A -l app.kubernetes.io/name=grafana \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Grafana pod found. The monitoring stack may still be starting." | tee /tmp/verify_grafana_hint.txt
        exit 1
      fi

      echo "Grafana is running"
    hintcheck: |
      if [ -f /tmp/verify_grafana_hint.txt ]; then
        cat /tmp/verify_grafana_hint.txt
        rm -f /tmp/verify_grafana_hint.txt
      fi

  verify_alert_rule:
    needs:
      - verify_prometheus_running
    run: |
      rm -f /tmp/verify_alert_hint.txt

      # There must be a user-defined PrometheusRule beyond whatever the stack
      # ships. Look for at least one alerting rule (has an 'alert' field).
      RULE=$(kubectl get prometheusrules.monitoring.coreos.com -A \
        -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null \
        | grep -v "kube-prometheus-stack" | head -n1)
      if [ -z "${RULE}" ]; then
        echo "No custom PrometheusRule found. Add your own alerting rule." | tee /tmp/verify_alert_hint.txt
        exit 1
      fi

      NS=$(echo "${RULE}" | cut -d/ -f1)
      NAME=$(echo "${RULE}" | cut -d/ -f2)
      ALERTS=$(kubectl -n "${NS}" get prometheusrule "${NAME}" \
        -o jsonpath='{range .spec.groups[*].rules[*]}{.alert}{"\n"}{end}' 2>/dev/null | grep -c '[a-zA-Z]')
      if [ "${ALERTS:-0}" -lt 1 ]; then
        echo "PrometheusRule '${RULE}' has no alerting rules (a rule with an 'alert' field and 'expr')" | tee /tmp/verify_alert_hint.txt
        exit 1
      fi

      echo "Custom alerting rule found in ${RULE}"
    hintcheck: |
      if [ -f /tmp/verify_alert_hint.txt ]; then
        cat /tmp/verify_alert_hint.txt
        rm -f /tmp/verify_alert_hint.txt
      fi
---

Rancher Monitoring is a packaged, UI-integrated build of the community `kube-prometheus-stack`. Working with that stack directly, without the Rancher wrapper, shows you exactly what gets deployed and where the alerting rules live - knowledge that transfers straight to the Rancher UI.

The playground is a single-node K3s cluster with Helm available. Your job is to stand up Prometheus and Grafana, then define an alert of your own.

## Step 1: Install the Monitoring Stack

Install a Prometheus operator based stack (for example, `kube-prometheus-stack`). The install registers the `monitoring.coreos.com` CRDs.

::simple-task
---
:tasks: tasks
:name: verify_prometheus_operator
---
#active
Waiting for the Prometheus operator CRDs...

#completed
The Prometheus operator and its CRDs are installed.
::

::hint-box
---
:summary: Hint 1
---
The `kube-prometheus-stack` chart from the `prometheus-community` Helm repository installs the operator, Prometheus, Grafana, and Alertmanager together. Give the pods conservative resource requests so they fit the lab VM.
::

## Step 2: Confirm Prometheus and Grafana Are Running

Both Prometheus and Grafana should come up as running pods.

::simple-task
---
:tasks: tasks
:name: verify_prometheus_running
---
#active
Waiting for a running Prometheus pod...

#completed
Prometheus is running.
::

::simple-task
---
:tasks: tasks
:name: verify_grafana_running
---
#active
Waiting for a running Grafana pod...

#completed
Grafana is running.
::

::hint-box
---
:summary: Hint 2
---
The stack takes a couple of minutes to fully start. Prometheus pods carry the label `app.kubernetes.io/name=prometheus` and Grafana pods carry `app.kubernetes.io/name=grafana`. Watch them with `kubectl get pods -A -w`.
::

## Step 3: Define an Alert

Create your own `PrometheusRule` containing at least one alerting rule (a rule with an `alert` name and an `expr`). Label it so the stack's Prometheus picks it up.

::simple-task
---
:tasks: tasks
:name: verify_alert_rule
---
#active
Waiting for a custom alerting rule...

#completed
Your alerting rule is defined. Well done.
::

::hint-box
---
:summary: Hint 3
---
A `PrometheusRule` groups rules under `spec.groups[].rules[]`. Each alerting rule needs an `alert` name and a PromQL `expr`. The operator only adopts rules whose labels match its ruleSelector - the chart's `release` label is the usual key.
::
