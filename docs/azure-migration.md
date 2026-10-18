# AWS-to-Azure migration record

This repository contains the Azure/AKS edition of the Zero to Prod e-commerce capstone. The workload code remains polyglot and mostly cloud-neutral; infrastructure, container publishing, and GitOps configuration target Azure.

## Migration mapping

- **EKS to AKS:** Terraform configures AKS, Azure CNI Overlay, Azure RBAC, OIDC issuer, and Microsoft Entra Workload Identity.
- **ECR to ACR:** ACR admin access is disabled; the AKS kubelet identity receives `AcrPull`, and the GitHub Actions service principal receives `AcrPush` on the registry.
- **AWS IAM/GitHub OIDC to Microsoft Entra federation:** `azure/login@v2` uses a federated credential; no long-lived Azure client secret is needed.
- **S3/DynamoDB Terraform state to Azure Blob state:** `terraform/state-bootstrap` creates the storage account and container; the `azurerm` backend uses Entra authentication and blob-lease locking.
- **EC2 SonarQube host to optional Azure VM:** the optional SonarQube VM is disabled by default and restricted by an NSG source CIDR.
- **Image build and release:** `scripts/build-push-images.sh` publishes the service images to ACR; GitHub Actions scans, pushes, signs, and generates SBOM attestations; the release workflow updates staging/production Helm values.
- **GitOps:** Argo CD root and environment Applications reference this repository: `JaiSandeep7461/Ecommerce-aks`.
- **Kubernetes storage:** Helm values use AKS managed disks with the `managed-csi` StorageClass.

## Main Azure-specific paths

- `terraform/state-bootstrap/` — initial Azure Blob state storage.
- `terraform/azure/` — resource group, VNet/subnet, AKS, ACR, Log Analytics, identities, RBAC, and optional SonarQube VM.
- `.github/workflows/ci.yml` — service tests, image build, Trivy scan, ACR push, SBOM, Cosign signing/attestation, and dev image-tag update.
- `.github/workflows/pr-checks.yml` — service tests and filesystem/config security scan; SonarQube is optional and activated with the repository variable `ENABLE_SONAR=true` plus the `SONAR_TOKEN` and `SONAR_HOST_URL` secrets.
- `.github/workflows/release.yml` — staging/production image-tag promotion in GitOps values.
- `.github/workflows/terraform.yml` — formatting checks, validation, and TFLint.
- `scripts/deploy-aks-addons.sh` — ingress-nginx, optional observability stack, optional Argo CD, and demo database secrets.
- `deploy/helm/ztd-capstone/` — frontend, API gateway, orders, catalog, PostgreSQL demo database, network policies, probes, autoscaling, ServiceMonitors, and ingress.
- `deploy/argocd/` — root and per-environment Argo CD Applications.

## Deployment and validation status

The Azure lab infrastructure and application have been created and the workloads were previously verified running on AKS. That manual deployment does not by itself prove the current CI pipeline or every new dependency update has passed. Treat the latest GitHub Actions results as the source of truth for pipeline validation. Before applying Terraform changes, run `terraform init`, `terraform fmt -check -recursive`, `terraform validate`, and review `terraform plan`; changes to existing AKS resources can cause replacement or downtime.

Configure GitHub repository Variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, and `ACR_NAME`. Configure the Microsoft Entra federated credential for the repository's `main` branch and grant the workflow identity only the permissions it needs.

For cost control, the development Terraform defaults to one `Standard_D2s_v3` AKS system node. Check regional vCPU quota and cost before scaling or enabling optional monitoring and SonarQube resources.

## Security and production limitations

- `.trivyignore` contains only explicitly documented Debian base-image findings for which Trivy reported no fixed version during the recorded scan. Recheck these exceptions whenever the base image or vulnerability database changes. Fixable application vulnerabilities must be upgraded rather than ignored.
- Terraform state, backend configuration, variables, and generated plan files must not be committed. Use Azure Blob remote state for collaboration.
- The in-cluster PostgreSQL StatefulSet is for lab/demo use. For production durability, use Azure Database for PostgreSQL, managed secrets, backups, ingress TLS, reviewed production approvals, and appropriate private networking.
- The example ingress hosts use `example.com` placeholders and require DNS/TLS configuration before use as a production endpoint.
