---
kind: lesson

title: Logging with Loki and Grafana Alloy
description: |
  Install Grafana Loki and the Alloy log shipper, then query your cluster's logs in the same Grafana you already use for metrics.

name: logging-loki-alloy
slug: logging-loki-alloy

createdAt: 2026-09-01
updatedAt: 2026-09-01

categories:
- kubernetes

tagz:
- rancher
- logging
- loki
- grafana

# cover: __static__/cover.png

# Same single-cluster playground as the observability lesson (Rancher pre-installed,
# dev-machine workstation model). This lesson REUSES the Grafana that the
# observability lesson installs (kube-prometheus-stack, release "monitoring",
# NodePort 30300) - it does not deploy a second Grafana. Ordering dependency:
# the monitoring stack must be installed first, so this lesson follows the
# observability lesson and its init installs monitoring.
# TODO(publish): confirm/replace the suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

challenges:
  rancher-logging-loki-alloy-3c95c13a: {}

tasks:
  # Verification runs on the dev-machine workstation as laborant, against the
  # cluster via the pre-provisioned kubeconfig. Mirrors the flow validated live:
  # Loki running -> Alloy shipping -> Loki datasource in Grafana -> LogQL returns lines.
  verify_loki_running:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl -n loki get pods -l app.kubernetes.io/name=loki \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "No running Loki pod in the loki namespace yet"
        exit 1
      fi
      echo "Loki is running"

  verify_alloy_shipping:
    machine: dev-machine
    user: laborant
    needs:
      - verify_loki_running
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Alloy runs as a DaemonSet; at least one pod must be ready to be shipping logs.
      READY=$(kubectl -n alloy get daemonset alloy \
        -o jsonpath='{.status.numberReady}' 2>/dev/null)
      if [ -z "${READY}" ] || [ "${READY}" -lt 1 ]; then
        echo "The Alloy DaemonSet has no ready pods yet"
        exit 1
      fi
      echo "Alloy is running on ${READY} node(s)"

  # A Loki datasource exists in the reused Grafana AND a LogQL query through it
  # returns at least one log line - proof the whole path works, not just that
  # the pieces are installed.
  verify_logs_queryable:
    machine: dev-machine
    user: laborant
    needs:
      - verify_alloy_shipping
    timeout_seconds: 240
    run: |
      rm -f /tmp/verify_logs_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      GPASS=$(kubectl -n monitoring get secret monitoring-grafana \
        -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || true)
      if [ -z "${GPASS}" ]; then
        echo "Could not read the Grafana admin password (is the monitoring stack installed?)" \
          | tee /tmp/verify_logs_hint.txt
        exit 1
      fi
      for i in $(seq 1 20); do
        pkill -f "port-forward.*34300:80" 2>/dev/null || true
        kubectl -n monitoring port-forward svc/monitoring-grafana 34300:80 >/tmp/pf_logs_gate.log 2>&1 &
        PF=$!
        sleep 6
        # Find a Loki datasource by type (name-agnostic so any name the student picks works).
        LOKI_UID=$(curl -sf -u "admin:${GPASS}" 'http://127.0.0.1:34300/api/datasources' 2>/dev/null \
          | tr '}' '\n' | grep '"type":"loki"' | grep -o '"uid":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
        if [ -n "${LOKI_UID}" ]; then
          NOW=$(date +%s)000
          FROM=$(( $(date +%s) - 600 ))000
          LINES=$(curl -sf -u "admin:${GPASS}" -G \
            "http://127.0.0.1:34300/api/datasources/proxy/uid/${LOKI_UID}/loki/api/v1/query_range" \
            --data-urlencode 'query={namespace=~".+"}' \
            --data-urlencode "start=${FROM}000000" \
            --data-urlencode "end=${NOW}000000" \
            --data-urlencode 'limit=1' 2>/dev/null \
            | grep -o '"values":\[\[' | head -1 || true)
          kill $PF 2>/dev/null || true
          if [ -n "${LINES}" ]; then
            echo "A Loki datasource is configured in Grafana and returns log lines"
            exit 0
          fi
        else
          kill $PF 2>/dev/null || true
        fi
        sleep 6
      done
      echo "No Loki datasource in Grafana returned log lines yet. Add a Loki datasource (URL http://loki.loki.svc.cluster.local:3100) and confirm a LogQL query returns data." \
        | tee /tmp/verify_logs_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_logs_hint.txt ]; then
        cat /tmp/verify_logs_hint.txt
        rm -f /tmp/verify_logs_hint.txt
      fi
---
