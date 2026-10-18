#!/usr/bin/env bash
# Build and push all four service images to Azure Container Registry.
# Usage: ACR_NAME=<your-acr-name> az login && ./scripts/build-push-images.sh [TAG]
set -euo pipefail
: "${ACR_NAME:?Set ACR_NAME to the Azure Container Registry resource name}"
SERVICES=(frontend api-gateway orders catalog)
TAG="${1:-sha-$(git rev-parse --short HEAD)}"
REGISTRY="${ACR_NAME}.azurecr.io"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
echo "==> Registry: ${REGISTRY}; tag: ${TAG}"
az acr login --name "${ACR_NAME}"
BUILDER_NAME="ztd-capstone-builder"
if ! docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then docker buildx create --name "${BUILDER_NAME}" --use; else docker buildx use "${BUILDER_NAME}"; fi
for svc in "${SERVICES[@]}"; do
  image="${REGISTRY}/ztd-capstone/${svc}:${TAG}"
  echo "==> Building + pushing ${image}"
  docker buildx build --platform linux/amd64 -t "${image}" --push "${REPO_ROOT}/services/${svc}"
done
echo "Done. Pushed all images with tag ${TAG}."
