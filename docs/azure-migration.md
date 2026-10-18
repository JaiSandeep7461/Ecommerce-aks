# AWS-to-Azure migration record

The repository has been migrated from AWS/EKS-centric infrastructure to Azure/AKS. Application source code, Dockerfiles, Helm templates, and vendor-neutral observability components are retained where portable.

## Converted

- EKS → AKS, including Azure CNI Overlay networking, Azure RBAC, OIDC issuer, and Microsoft Entra Workload Identity support.
- ECR → Azure Container Registry (ACR), with AKS kubelet `AcrPull` assignment and ACR admin access disabled.
- AWS IAM role / GitHub OIDC setup → Microsoft Entra federated identity + `azure/login@v2` in GitHub Actions.
- S3 + DynamoDB Terraform state → Azure Blob Storage backend (`terraform/state-bootstrap` creates the account/container; the `azurerm` backend uses Entra auth and blob-lease locking).
- EKS nodegroup → AKS node pool; the EC2 SonarQube host → optional Azure Linux VM running SonarQube + PostgreSQL with an NSG CIDR allowlist. The VM is disabled by default to control cost; existing `SONAR_HOST_URL` and `SONAR_TOKEN` secrets point CI at the chosen instance.
- AWS CLI image publishing script → Azure CLI + `az acr login` script.
- ECR registry in Helm values → ACR placeholder, with CI workflow updating it from `ACR_NAME`.
- AWS deployment workflows → Azure OIDC login and ACR image push; release workflow promotes existing image tags through GitOps value files.
- Region/account/profile-specific AWS assumptions → Azure region/resource group variables.
- AWS-specific Trivy ignore entries → removed; application CVE exceptions remain.
- Argo CD repo URL → this `zero-to-prod` repository.

## Main files changed

- Replaced `terraform/bootstrap/` and `terraform/stack/` with `terraform/state-bootstrap/` and `terraform/azure/` (Azure Blob state, AzureRM provider, AKS, ACR, Log Analytics, Azure networking, Entra RBAC/OIDC, outputs, optional SonarQube VM, and example variables).
- Replaced `.github/workflows/ci.yml` with Azure OIDC login, ACR image push, Trivy scan, Cosign signing/SBOM attestation, and GitOps value updates.
- Replaced `.github/workflows/release.yml` with GitOps tag promotion for staging and production.
- Replaced `.github/workflows/terraform.yml` with Azure Terraform formatting/validation.
- Replaced `scripts/build-push-images.sh` with Azure CLI/ACR commands; added `scripts/deploy-aks-addons.sh` for ingress, monitoring, Argo CD, and demo secrets after AKS exists.
- Updated `deploy/helm/ztd-capstone/values.yaml` and observability PVC storage classes for AKS (`managed-csi`).
- Updated `deploy/argocd/` repository URLs to `Infrathrone-Devops-Park/zero-to-prod`.
- Replaced AWS-era design plans/specs and status reports with Azure deployment/design documents; retained the application source, Dockerfiles, tests, Helm templates, dashboards, and portable observability configs.

## Important limitations / actions before production

- This is an infrastructure and delivery migration, not an executed cloud deployment. No Azure resources have been created from this archive, and no live Azure subscription credentials were available for end-to-end verification.
- Review Terraform provider compatibility and run `terraform init`, `fmt`, `validate`, and `plan` in your Azure environment before applying. AKS cluster creation and Helm chart installation may take several minutes and incur cost.
- Configure Azure Storage remote state before collaboration or CI-driven Terraform changes.
- Create the Microsoft Entra federated credential and grant least-privilege `AcrPush` to the workflow principal.
- Set `ACR_NAME` and Azure identity variables in GitHub repository settings.
- If enabling SonarQube, set `deploy_sonarqube=true` and change `sonarqube_ingress_cidr` from its safe loopback default to a trusted source CIDR; port 22 is not opened. Confirm Helm values, ingress host/TLS, storage class, and observability resource requests for the actual AKS cluster. The PostgreSQL StatefulSet is still an in-cluster demo database; use Azure Database for PostgreSQL for production durability.
- Obsolete AWS-specific implementation plans and reports were removed and replaced with `docs/specs/azure-aks-design.md`, `docs/plans/azure-deployment-plan.md`, and the Azure deployment guides. Use these Azure files as the current instructions.


### Subscription-specific Terraform settings

The Azure Terraform roots (`terraform/azure` and `terraform/state-bootstrap`) default to the `AzureDevops` subscription ID supplied in the user's Azure Portal screenshot (`cc9bc945-4e68-4631-a463-3bf91022981b`). The example `terraform.tfvars` files include this ID explicitly. Verify the active account before running Terraform. The AKS system node count defaults to one to limit development-lab costs.
