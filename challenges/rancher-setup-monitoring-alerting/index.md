---
kind: challenge

title: 'Deploy a Monitoring Stack and Define an Alert'

description: |
  Install the Prometheus and Grafana stack that Rancher Monitoring is built on,
  then define a PrometheusRule alert of your own. You work from a workstation
  against a cluster that already runs Rancher, and install the same
  kube-prometheus-stack that Rancher Monitoring packages - so you see exactly
  what it deploys and where alerts live.

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

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# TODO(publish): replace with the live suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

tasks:
  # Wait until the workstation can reach the cluster before the student starts.
  init_wait_cluster:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 180
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 45); do
        if kubectl get nodes 2>/dev/null | grep -q " Ready"; then
          exit 0
        fi
        sleep 4
      done
      echo "Cluster not reachable from the workstation in time"
      exit 1

  verify_prometheus_operator:
    machine: dev-machine
    user: laborant
    needs:
      - init_wait_cluster
    run: |
      rm -f /tmp/verify_prom_operator_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      # The kube-prometheus-stack installs the Prometheus operator, which
      # registers the monitoring.coreos.com CRDs. Without them, no alert exists.
      if ! kubectl get crd prometheuses.monitoring.coreos.com >/dev/null 2>&1 \
        || ! kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1; then
        echo "The Prometheus operator CRDs are not installed yet. Install kube-prometheus-stack." \
          | tee /tmp/verify_prom_operator_hint.txt
        exit 1
      fi
      echo "Prometheus operator CRDs are present"
    hintcheck: |
      if [ -f /tmp/verify_prom_operator_hint.txt ]; then
        cat /tmp/verify_prom_operator_hint.txt
        rm -f /tmp/verify_prom_operator_hint.txt
      fi

  verify_prometheus_running:
    machine: dev-machine
    user: laborant
    needs:
      - verify_prometheus_operator
    timeout_seconds: 300
    run: |
      rm -f /tmp/verify_prom_run_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl get pods -A -l app.kubernetes.io/name=prometheus \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Prometheus pod found. The stack may still be starting." \
          | tee /tmp/verify_prom_run_hint.txt
        exit 1
      fi
      echo "Prometheus is running"
    hintcheck: |
      if [ -f /tmp/verify_prom_run_hint.txt ]; then
        cat /tmp/verify_prom_run_hint.txt
        rm -f /tmp/verify_prom_run_hint.txt
      fi

  verify_grafana_running:
    machine: dev-machine
    user: laborant
    needs:
      - verify_prometheus_operator
    timeout_seconds: 300
    run: |
      rm -f /tmp/verify_grafana_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl get pods -A -l app.kubernetes.io/name=grafana \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Grafana pod found. The stack may still be starting." \
          | tee /tmp/verify_grafana_hint.txt
        exit 1
      fi
      echo "Grafana is running"
    hintcheck: |
      if [ -f /tmp/verify_grafana_hint.txt ]; then
        cat /tmp/verify_grafana_hint.txt
        rm -f /tmp/verify_grafana_hint.txt
      fi

  verify_custom_rule:
    machine: dev-machine
    user: laborant
    needs:
      - verify_prometheus_running
    run: |
      rm -f /tmp/verify_rule_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      # A user-defined PrometheusRule beyond whatever the stack ships. The
      # stack's rules are all named monitoring-kube-prometheus-*, so excluding
      # "kube-prometheus" isolates the student's own rule.
      RULE=$(kubectl get prometheusrules.monitoring.coreos.com -A \
        -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null \
        | grep -v "kube-prometheus" | head -n1)
      if [ -z "${RULE}" ]; then
        echo "No custom PrometheusRule found. Add your own alerting rule (with the release label so Prometheus adopts it)." \
          | tee /tmp/verify_rule_hint.txt
        exit 1
      fi
      echo "Custom PrometheusRule found: ${RULE}"
    hintcheck: |
      if [ -f /tmp/verify_rule_hint.txt ]; then
        cat /tmp/verify_rule_hint.txt
        rm -f /tmp/verify_rule_hint.txt
      fi

  verify_alert_firing:
    machine: dev-machine
    user: laborant
    needs:
      - verify_custom_rule
    timeout_seconds: 480
    run: |
      rm -f /tmp/verify_firing_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      # The alert must actually be FIRING, not just defined - proof a real
      # condition tripped it. The Prometheus container is distroless (no shell,
      # no wget/curl), so we port-forward its service to the workstation and
      # curl the API. A fresh high local port avoids colliding with any
      # port-forward the learner left running; the retry loop absorbs both the
      # forward's startup and the crash-loop + scrape + for: window.
      for i in $(seq 1 30); do
        pkill -f "port-forward.*19490:9090" 2>/dev/null || true
        kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 19490:9090 >/tmp/pf_gate.log 2>&1 &
        PF=$!
        sleep 8
        FIRING=$(curl -sf -G 'http://127.0.0.1:19490/api/v1/query' \
          --data-urlencode 'query=ALERTS{alertstate="firing"}' 2>/dev/null \
          | grep -o '"alertstate":"firing"' | head -1)
        kill $PF 2>/dev/null || true
        if [ -n "${FIRING}" ]; then
          echo "An alert is firing"
          exit 0
        fi
        sleep 8
      done
      echo "No alert is firing yet. Ensure a pod is crash-looping and your rule's condition is met." \
        | tee /tmp/verify_firing_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_firing_hint.txt ]; then
        cat /tmp/verify_firing_hint.txt
        rm -f /tmp/verify_firing_hint.txt
      fi
---

Rancher Monitoring is a packaged, UI-integrated build of the community `kube-prometheus-stack`. Installing that chart directly - the way you do here - shows you exactly what gets deployed and where the alerting rules live, knowledge that transfers straight to the Rancher UI.

This playground already runs Rancher. You work from the :tab{text='dev-machine' machine='dev-machine'} workstation, where `kubectl` and `helm` are configured. Your job is to stand up Prometheus and Grafana, then define an alert of your own.

## Step 1: Install the Monitoring Stack

Install a Prometheus operator based stack (for example, `kube-prometheus-stack`) from the workstation. Trim its resource requests so it fits alongside Rancher on this node.

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
:summary: Hint 1 - the chart to use
---
The `kube-prometheus-stack` chart from the `prometheus-community` Helm repository installs the operator, Prometheus, Grafana, and Alertmanager together. Because this node also runs Rancher, pass small resource requests (for CPU and memory) via `--set` so the pods schedule rather than sit Pending.
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
:summary: Hint 2 - give it time
---
The stack takes a couple of minutes to pull images and start. Prometheus pods carry the label `app.kubernetes.io/name=prometheus` and Grafana pods carry `app.kubernetes.io/name=grafana`. Watch them with `kubectl -n monitoring get pods -w`.
::

## Step 3: Cause a Failure and Alert on It

Defining an alert is only convincing if you see it fire. Deploy a pod that crash-loops, then create a `PrometheusRule` that alerts on it. Your rule must be adopted by Prometheus and must actually reach the **firing** state.

::simple-task
---
:tasks: tasks
:name: verify_custom_rule
---
#active
Waiting for your custom alerting rule...

#completed
Your rule exists and Prometheus adopted it.
::

::simple-task
---
:tasks: tasks
:name: verify_alert_firing
---
#active
Waiting for your alert to reach the firing state (this takes a few minutes)...

#completed
Your alert is firing. You caused a real failure and Prometheus caught it. Well done.
::

::hint-box
---
:summary: Hint 3 - getting the rule adopted
---
The operator only adopts rules whose labels match its ruleSelector - the chart's `release` label is the key, so set `release` to the name you gave the Helm install. Without it, your rule is a valid object Prometheus simply ignores.
::

::hint-box
---
:summary: Hint 4 - making the alert actually fire
---
Deploy a crash-looping pod (for example, `kubectl run crasher --image=busybox --restart=Always -- /bin/sh -c "exit 1"`), then alert on its restart count. Use a monotonic counter like `kube_pod_container_status_restarts_total{...} > 3` rather than a sliding-window `increase(...)`, which can dip below the threshold between scrapes and never complete the `for:` window. Give it a few minutes: crash-loop backoff, a scrape, and the `for:` duration all have to elapse before the alert fires.
::
