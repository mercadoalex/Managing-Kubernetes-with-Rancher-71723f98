---
kind: challenge

title: 'Aggregate Cluster Logs with Loki and Alloy'

description: |
  Build the logging pillar on a Rancher cluster: install Grafana Loki to store
  logs and Grafana Alloy to ship them from every node, then wire Loki into the
  Grafana you already run for metrics and prove a LogQL query returns your
  cluster's logs. This is the same pipeline Rancher's Logging app packages.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Logging
  - Loki
  - Grafana
  - Alloy

difficulty: medium

createdAt: 2026-09-01
updatedAt: 2026-09-01

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# The init task installs the monitoring stack so a Grafana exists to reuse -
# the same premise as the lesson (one Grafana over metrics and logs).
# TODO(publish): replace with the live suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

tasks:
  # Install the monitoring stack (for the Grafana the student will reuse) and
  # wait until the workstation can reach the cluster. This mirrors the state a
  # student reaches after the observability lesson.
  init_monitoring:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 420
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 45); do
        kubectl get nodes 2>/dev/null | grep -q " Ready" && break
        sleep 4
      done
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
      helm repo update >/dev/null 2>&1 || true
      if ! helm status monitoring -n monitoring >/dev/null 2>&1; then
        helm install monitoring prometheus-community/kube-prometheus-stack \
          --namespace monitoring --create-namespace \
          --set grafana.service.type=NodePort \
          --set grafana.service.nodePort=30300 \
          --set prometheus.prometheusSpec.retention=2h \
          --set prometheus.prometheusSpec.resources.requests.cpu=100m \
          --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
          --set grafana.resources.requests.cpu=50m \
          --set grafana.resources.requests.memory=128Mi \
          --set alertmanager.alertmanagerSpec.resources.requests.cpu=25m \
          --set alertmanager.alertmanagerSpec.resources.requests.memory=64Mi
      fi
      kubectl -n monitoring rollout status deployment/monitoring-grafana --timeout=300s

  verify_loki_running:
    machine: dev-machine
    user: laborant
    needs:
      - init_monitoring
    timeout_seconds: 300
    run: |
      rm -f /tmp/verify_loki_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl -n loki get pods -l app.kubernetes.io/name=loki \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Loki pod in the loki namespace. Install Loki (grafana-community/loki) in single-binary mode." \
          | tee /tmp/verify_loki_hint.txt
        exit 1
      fi
      echo "Loki is running"
    hintcheck: |
      if [ -f /tmp/verify_loki_hint.txt ]; then
        cat /tmp/verify_loki_hint.txt
        rm -f /tmp/verify_loki_hint.txt
      fi

  verify_alloy_shipping:
    machine: dev-machine
    user: laborant
    needs:
      - verify_loki_running
    timeout_seconds: 240
    run: |
      rm -f /tmp/verify_alloy_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl -n alloy get daemonset alloy \
        -o jsonpath='{.status.numberReady}' 2>/dev/null)
      if [ -z "${READY}" ] || [ "${READY}" -lt 1 ]; then
        echo "The Alloy DaemonSet has no ready pods. Install Alloy (grafana/alloy) as a DaemonSet pointing at Loki." \
          | tee /tmp/verify_alloy_hint.txt
        exit 1
      fi
      echo "Alloy is running on ${READY} node(s)"
    hintcheck: |
      if [ -f /tmp/verify_alloy_hint.txt ]; then
        cat /tmp/verify_alloy_hint.txt
        rm -f /tmp/verify_alloy_hint.txt
      fi

  # A Loki datasource exists in Grafana AND a LogQL query through it returns at
  # least one log line - proof the whole path works, not just that the pieces
  # are installed. Name-agnostic: matches any datasource of type "loki".
  verify_logs_queryable:
    machine: dev-machine
    user: laborant
    needs:
      - verify_alloy_shipping
    timeout_seconds: 300
    run: |
      rm -f /tmp/verify_query_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      GPASS=$(kubectl -n monitoring get secret monitoring-grafana \
        -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || true)
      if [ -z "${GPASS}" ]; then
        echo "Could not read the Grafana admin password. Is the monitoring stack installed?" \
          | tee /tmp/verify_query_hint.txt
        exit 1
      fi
      for i in $(seq 1 25); do
        pkill -f "port-forward.*34301:80" 2>/dev/null || true
        kubectl -n monitoring port-forward svc/monitoring-grafana 34301:80 >/tmp/pf_query_gate.log 2>&1 &
        PF=$!
        sleep 6
        LOKI_UID=$(curl -sf -u "admin:${GPASS}" 'http://127.0.0.1:34301/api/datasources' 2>/dev/null \
          | tr '}' '\n' | grep '"type":"loki"' | grep -o '"uid":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
        if [ -n "${LOKI_UID}" ]; then
          NOW=$(date +%s)000
          FROM=$(( $(date +%s) - 600 ))000
          HIT=$(curl -sf -u "admin:${GPASS}" -G \
            "http://127.0.0.1:34301/api/datasources/proxy/uid/${LOKI_UID}/loki/api/v1/query_range" \
            --data-urlencode 'query={namespace=~".+"}' \
            --data-urlencode "start=${FROM}000000" \
            --data-urlencode "end=${NOW}000000" \
            --data-urlencode 'limit=1' 2>/dev/null \
            | grep -o '"values":\[\[' | head -1 || true)
          kill $PF 2>/dev/null || true
          if [ -n "${HIT}" ]; then
            echo "A Loki datasource in Grafana returns log lines"
            exit 0
          fi
        else
          kill $PF 2>/dev/null || true
        fi
        sleep 6
      done
      echo "No Loki datasource in Grafana returned log lines. Add a Loki datasource (URL http://loki.loki.svc.cluster.local:3100) and confirm a LogQL query returns data." \
        | tee /tmp/verify_query_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_query_hint.txt ]; then
        cat /tmp/verify_query_hint.txt
        rm -f /tmp/verify_query_hint.txt
      fi
---

Metrics tell you that something is wrong; logs tell you why. In this challenge you add the logs pillar to a Rancher cluster that already has the metrics stack running. You install **Grafana Loki** to store logs and **Grafana Alloy** to collect them from every node, then wire Loki into the existing Grafana and prove you can query your cluster's logs with LogQL.

You work from the :tab{text='dev-machine' machine='dev-machine'} workstation, where `kubectl` and `helm` are configured. The monitoring stack (including Grafana) is already installed, exactly as it would be after setting up observability - your job is the logging pipeline on top of it.

## Step 1: Install Loki

Install Loki in a small, single-binary shape with filesystem storage so it fits alongside Rancher and the monitoring stack on this node. A single `loki` pod in a `loki` namespace is enough.

::simple-task
---
:tasks: tasks
:name: verify_loki_running
---
#active
Waiting for a running Loki pod...

#completed
Loki is running.
::

::hint-box
---
:summary: Hint 1 - the Loki chart
---
The Loki chart now lives in the `grafana-community` Helm repository (`grafana-community/loki`). For a lab, deploy it in single-binary mode with filesystem storage and the other scaling components turned off, so only one Loki pod runs. A values file is the cleanest way to pass all those settings.
::

## Step 2: Ship Logs with Alloy

Install a log collector that runs on every node, discovers pods, and pushes their logs to Loki. Grafana Alloy is the current collector for this (it replaced the end-of-life Promtail).

::simple-task
---
:tasks: tasks
:name: verify_alloy_shipping
---
#active
Waiting for the Alloy DaemonSet to be ready...

#completed
Alloy is shipping logs from every node.
::

::hint-box
---
:summary: Hint 2 - Alloy as a DaemonSet
---
The Alloy chart is `grafana/alloy` (the classic `grafana` repo, not `grafana-community`). Run it as a DaemonSet so one agent lands on each node. Its config needs a Kubernetes pod discovery, a step that relabels pod metadata into log labels, a source that tails the pods' logs, and a write step pointing at Loki's push endpoint: `http://loki.loki.svc.cluster.local:3100/loki/api/v1/push`.
::

## Step 3: Query Logs in Grafana

Add Loki as a data source in the Grafana that is already running, then confirm a LogQL query returns log lines. Do not stand up a second Grafana - reuse the one from the monitoring stack.

::simple-task
---
:tasks: tasks
:name: verify_logs_queryable
---
#active
Waiting for a Loki data source in Grafana that returns log lines...

#completed
You can query your cluster's logs in Grafana. The logging pillar is complete.
::

::hint-box
---
:summary: Hint 3 - wire Loki into Grafana
---
Grafana's admin password is in the `monitoring-grafana` secret. Add a data source of type **Loki** with the URL `http://loki.loki.svc.cluster.local:3100`, then query a broad selector like `{namespace="kube-system"}` in **Explore**. If the query returns nothing, give Alloy a moment to ship the first lines, and check that its DaemonSet pods are running.
::
