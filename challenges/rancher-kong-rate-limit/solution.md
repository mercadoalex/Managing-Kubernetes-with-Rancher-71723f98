---
title: Attach a Rate-Limiting Plugin to the Route
---

Kong is already routing the `web` workload, so the whole task is two objects: a plugin that defines the limit, and an annotation that attaches it to the route.

<!--more-->

## Define the Rate Limit

A Kong plugin is a Kubernetes resource. Create a `KongPlugin` in the `demo` namespace that allows five requests per minute. For this DB-less Kong, `policy: local` keeps the counter in the gateway pod - no external datastore needed:

```bash
kubectl apply -f - <<'EOF'
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-5
  namespace: demo
plugin: rate-limiting
config:
  minute: 5
  policy: local
EOF
```

On its own this object does nothing - a plugin has to be attached to a route.

## Attach It to the Route

Point the `web` Ingress at the plugin with the `konghq.com/plugins` annotation:

```bash
kubectl -n demo annotate ingress web konghq.com/plugins=rate-limit-5 --overwrite
```

Kong's controller sees the annotation and programs the limit into the gateway within a few seconds.

## Watch It Enforce

Send more requests than the limit allows. The first five return `200`; the rest are rejected with `429`:

```bash
for i in $(seq 1 8); do
  curl -sS -o /dev/null -w "request $i -> HTTP %{http_code}\n" http://172.16.0.2:30081/
done
```

Once the gateway returns `429` past the limit, the rate limit is enforcing and the challenge is solved. The limit is a rolling one-minute window, so after a minute the counter frees up and requests succeed again - that is normal throttling, not a permanent block.
