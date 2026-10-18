# Zero to Prod — Azure AKS Edition

A polyglot e-commerce microservices capstone with Docker, Kubernetes, Helm, GitHub Actions, Terraform, GitOps, and observability. The infrastructure and delivery path in this repository targets **Microsoft Azure**.

## Architecture

- **Compute:** Azure Kubernetes Service (AKS), Azure CNI Overlay networking, Azure RBAC, OIDC issuer and Microsoft Entra Workload Identity.
- **Container registry:** Azure Container Registry (ACR), AKS kubelet identity with `AcrPull`, registry admin account disabled.
- **Infrastructure as code:** Terraform in `terraform/state-bootstrap` and `terraform/azure` provisions Azure Blob remote state, the resource group, VNet/subnet, AKS, ACR, and Log Analytics. `scripts/deploy-aks-addons.sh` installs ingress-nginx, optional Argo CD, and Prometheus/Grafana, Loki/Promtail, Tempo, and OpenTelemetry Collector.
- **Applications:** React/Vite frontend, Node/TypeScript API gateway, Python/FastAPI orders service, Go catalog service, and PostgreSQL demo database packaged by the Helm chart.
- **CI/CD:** GitHub Actions uses Microsoft Entra federated credentials (OIDC) to authenticate to Azure, scans images with Trivy, pushes to ACR, signs images with Cosign, and updates Helm values for Argo CD GitOps.
- **Monitoring:** Azure Monitor/Log Analytics for AKS platform logs plus the portable in-cluster Prometheus/Grafana and Loki/Tempo stack. Optional SonarQube Community + PostgreSQL runs on an Azure Linux VM with a restricted network security group.

## Quick start

1. Install Azure CLI, Terraform >= 1.7, kubectl, Helm and Docker.
2. Sign in and choose a subscription: `az login` then `az account set --subscription <SUBSCRIPTION_ID>`.
3. Deploy Azure infrastructure and configure the Azure Blob state backend using [terraform/azure/README.md](terraform/azure/README.md).
4. Configure GitHub repository variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, and `ACR_NAME`. Create a Microsoft Entra federated identity credential for the repository's `main` branch and grant it least-privilege `AcrPush` on ACR.
5. Set `deploy/helm/ztd-capstone/values.yaml` registry to `<ACR_NAME>.azurecr.io` or let the CI workflow update it when it pushes an image.
6. Run `./scripts/deploy-aks-addons.sh` to install add-ons. For GitOps, verify and apply `deploy/argocd/root-app.yaml`; for a direct Helm install, use `ACR_NAME=<acr-name> IMAGE_TAG=<published-tag> ./scripts/deploy-aks-addons.sh --skip-argocd --with-app` (choose one owner, not both).

## Important notes

- The main Terraform state uses Azure Blob Storage with Microsoft Entra authentication and blob-lease locking; the initial state-bootstrap root uses local state to create that storage account.
- Terraform has **not** been applied automatically. Review `terraform plan` and cost estimates before creating resources.
- `terraform.tfvars`, state files, credentials, and secrets must not be committed.
- The in-cluster PostgreSQL StatefulSet is for learning/demo use. Use Azure Database for PostgreSQL for production workloads.
- Configure GitHub Environments with required reviewers for production promotions.
- The migration checklist is in [docs/azure-migration.md](docs/azure-migration.md).
# Ecommerce-aks
