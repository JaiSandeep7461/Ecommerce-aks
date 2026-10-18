# Azure Terraform deployment

This Terraform root provisions the Azure foundation: Resource Group, VNet/subnet, Azure Container Registry (ACR), Log Analytics Workspace, Azure Kubernetes Service (AKS), Azure CNI Overlay networking, AKS OIDC/workload identity, and ACR pull permissions. Kubernetes add-ons are installed in a separate step so Terraform does not try to configure Kubernetes providers before a new AKS cluster exists.

## Prerequisites

- Azure subscription with permission to create resource groups, networking, AKS, ACR, role assignments, Log Analytics and AKS workloads.
- Azure CLI logged in with `az login`; Terraform >= 1.7; kubectl, Helm, Docker and OpenSSL for add-on installation.
- The Terraform examples are preconfigured for the `AzureDevops` subscription shown in your screenshot. Verify it with `az account show --output table`; if the subscription differs, update `subscription_id` in both `terraform.tfvars` files. You can also select it in the CLI with `az account set --subscription <SUBSCRIPTION_ID>`.

## Deploy

### 1. Create Azure Storage for Terraform state (one time)

The bootstrap root uses local state because the storage account does not exist yet. Keep its local state file backed up securely; do not destroy this resource group while the main Terraform state is stored there.

```bash
cd terraform/state-bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out state.tfplan
terraform apply state.tfplan
terraform output -raw backend_config_example
```

Copy the output into `terraform/azure/backend.hcl` (or start from `backend.hcl.example` and replace the storage account name). The storage account has private blob access, blob versioning and soft-delete retention; state access uses Microsoft Entra ID rather than storage account keys.

### 2. Deploy Azure infrastructure

```bash
cd ../azure
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Edit backend.hcl with the storage account name output by state-bootstrap.
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan -out main.tfplan
terraform apply main.tfplan
az aks get-credentials --resource-group "$(terraform output -raw resource_group_name)" --name "$(terraform output -raw aks_name)" --overwrite-existing
kubectl get nodes
terraform output -raw acr_login_server
cd ../..
./scripts/deploy-aks-addons.sh
```

ACR uses the Basic tier to reduce development cost; choose Standard/Premium for production requirements. AKS and supporting resources incur charges while running. Review the plan and your subscription pricing before applying. The default configuration uses one `Standard_D2s_v5` node to reduce lab cost; the add-on script enables observability, which can still consume noticeable resources. Increase node count only if required. The optional SonarQube VM is disabled by default; enable it only if needed. For a cheaper infrastructure-only lab, skip the add-ons with `./scripts/deploy-aks-addons.sh --skip-observability --skip-argocd`.

## Optional SonarQube VM

Set `deploy_sonarqube = true` in `terraform.tfvars` and change `sonarqube_ingress_cidr` from `127.0.0.1/32` to a trusted source CIDR before applying. The VM runs SonarQube Community and PostgreSQL in Docker Compose, stores data in managed OS-disk-backed Docker volumes, and exposes only TCP/9000 from the configured CIDR; SSH/22 is not opened. Retrieve its URL with `terraform output -raw sonarqube_url` and set GitHub secrets `SONAR_HOST_URL` and `SONAR_TOKEN` after configuring SonarQube. The generated DB/admin password is stored in Terraform state, so protect the Azure Blob backend. For production, prefer a hardened private deployment and managed database.

## State and safety

The main infrastructure root uses an Azure Storage backend with Microsoft Entra authentication and built-in blob lease locking. The state-bootstrap root uses local state only for the initial bootstrap cycle; back up that state file securely. Keep `backend.hcl`, `terraform.tfvars`, and state files out of Git. The Terraform root is not applied automatically by GitHub Actions.

## Deploy app with Argo CD

1. Set the registry in `deploy/helm/ztd-capstone/values.yaml` to the `acr_login_server` output, or run the CI workflow once to write it from the `ACR_NAME` repository variable.
2. Ensure the GitHub repo URL in `deploy/argocd/root-app.yaml` matches this repository.
3. After `./scripts/deploy-aks-addons.sh` installs Argo CD, use `kubectl -n argocd port-forward svc/argocd-server 8080:443` and open `https://localhost:8080`; retrieve the initial admin password from the `argocd-initial-admin-secret` Kubernetes Secret and rotate it immediately.
4. Apply the root application: `kubectl apply -f deploy/argocd/root-app.yaml`.
5. The dev Application syncs `deploy/helm/ztd-capstone` into the `dev` namespace. Ensure the image tag exists in ACR before sync.

For a direct Helm install instead of Argo CD, run `ACR_NAME=<acr-name> IMAGE_TAG=<published-tag> ./scripts/deploy-aks-addons.sh --skip-argocd --with-app`; do not let both Argo CD and Helm own the same app resources.

## GitHub Actions OIDC

Create a Microsoft Entra app/service principal and federated identity credential for this repository and the `main` branch (and GitHub Environments if used). Grant the principal `AcrPush` on the ACR and the least privileges needed for the actions it runs. Set repository **Variables** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, and `ACR_NAME`. The workflows use `azure/login@v2` with OIDC; no client secret is required. Do not give the CI principal Owner/Contributor on the entire subscription merely to push images.
