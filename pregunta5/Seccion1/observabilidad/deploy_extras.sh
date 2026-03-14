#!/bin/bash
set -euo pipefail

NS=observability

echo "Applying PrometheusRule for alerts..."
kubectl apply -f "$(dirname "$0")/prometheus-rules.yaml" -n ${NS}

echo "Creating Grafana dashboard ConfigMap..."
kubectl create configmap grafana-dashboard-sre-challenge --from-file=grafana-dashboard.json="$(dirname "$0")/grafana-dashboard.json" -n ${NS} --dry-run=client -o yaml | kubectl apply -f -

echo "Applying nginx ServiceMonitor (if present)..."
kubectl apply -f "$(dirname "$0")/nginx-servicemonitor.yaml" -n ${NS} || true

echo "Applying OTel Collector Service + ServiceMonitor..."
kubectl apply -f "$(dirname "$0")/otel-servicemonitor.yaml" -n ${NS} || true

echo "Extras applied. You can import the ConfigMap into Grafana or use a sidecar to auto-provision dashboards."
