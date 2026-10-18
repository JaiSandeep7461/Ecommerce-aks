# Zero to Prod — Azure AKS design

## Goal
Deploy the existing polyglot e-commerce demo to AKS using Azure-native identity, registry, networking, and monitoring integrations while retaining portable Kubernetes tooling.

## Target architecture
- Azure Resource Group and VNet/subnet managed by Terraform.
- AKS with Azure CNI Overlay, Azure RBAC, OIDC issuer and Microsoft Entra Workload Identity.
- Azure Container Registry with admin access disabled and AKS kubelet `AcrPull` role assignment.
- Azure Monitor / Log Analytics for AKS platform logs.
- ingress-nginx LoadBalancer for HTTP ingress.
- Optional Argo CD GitOps and Prometheus/Grafana, Loki/Promtail, Tempo, and OpenTelemetry Collector.
- GitHub Actions authenticated to Azure through Microsoft Entra federated identity credentials; no static cloud credentials.

## Service layout
- `frontend`: React/Vite application served by Nginx.
- `api-gateway`: Node.js/TypeScript.
- `orders`: Python/FastAPI.
- `catalog`: Go.
- PostgreSQL StatefulSet is demo-only; production should use Azure Database for PostgreSQL.

## Deployment boundary
Terraform provisions Azure infrastructure only. `scripts/deploy-aks-addons.sh` installs Kubernetes add-ons after AKS is ready. This separation avoids configuring Kubernetes/Helm providers from a cluster endpoint that does not exist until the same Terraform apply finishes.
