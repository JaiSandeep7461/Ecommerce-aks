#!/usr/bin/env bash
# Install Kubernetes add-ons after Terraform has created AKS.
# Usage: ./scripts/deploy-aks-addons.sh [--skip-observability] [--skip-argocd] [--with-app]
set -euo pipefail
SKIP_OBS=false
SKIP_ARGO=false
WITH_APP=false
for arg in "$@"; do
  case "$arg" in
    --skip-observability) SKIP_OBS=true ;;
    --skip-argocd) SKIP_ARGO=true ;;
    --with-app) WITH_APP=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v helm >/dev/null || { echo "helm is required" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
kubectl get nodes
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
# Create the demo PostgreSQL Secret only when missing; preserve credentials on reruns.
PG_PASSWORD="$(openssl rand -hex 20)"
for ns in dev staging prod; do
  if ! kubectl get secret ztd-capstone-postgres -n "$ns" >/dev/null 2>&1; then
    kubectl create secret generic ztd-capstone-postgres -n "$ns" \
      --from-literal=postgres-password="$PG_PASSWORD" \
      --from-literal=database-url="postgresql://ztd:${PG_PASSWORD}@postgres:5432/ztd"
  fi
done
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
# Do not create a ServiceMonitor until Prometheus Operator CRDs are installed.
# This script permits --skip-observability, so the CRD may not exist.
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=false
if [[ "$SKIP_OBS" != true ]]; then
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
  helm repo update
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n observability -f "$ROOT/deploy/observability/kube-prometheus-stack.values.yaml"
  helm upgrade --install loki grafana/loki -n observability -f "$ROOT/deploy/observability/loki.values.yaml"
  helm upgrade --install promtail grafana/promtail -n observability -f "$ROOT/deploy/observability/promtail.values.yaml"
  helm upgrade --install tempo grafana/tempo -n observability -f "$ROOT/deploy/observability/tempo.values.yaml"
  helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector -n observability -f "$ROOT/deploy/observability/opentelemetry-collector.values.yaml"
fi
if [[ "$SKIP_ARGO" != true ]]; then
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f "$ROOT/deploy/argocd/argocd-values.yaml"
fi
if [[ "$WITH_APP" == true ]]; then
  : "${ACR_NAME:?Set ACR_NAME when using --with-app}"
  helm upgrade --install ztd-capstone "$ROOT/deploy/helm/ztd-capstone" -n dev \
    -f "$ROOT/deploy/helm/ztd-capstone/values.yaml" -f "$ROOT/deploy/helm/ztd-capstone/values-dev.yaml" \
    --set image.registry="${ACR_NAME}.azurecr.io" --set image.tag="${IMAGE_TAG:-dev}"
fi
echo "Add-ons installed. Check ingress IP with: kubectl get svc -n ingress-nginx ingress-nginx-controller"
if [[ "$SKIP_ARGO" != true ]]; then echo "Argo CD installed. Apply root app after verifying deploy/argocd/root-app.yaml."; fi
