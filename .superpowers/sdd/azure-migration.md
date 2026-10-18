# Azure migration status

- The source tree was migrated from AWS-specific Terraform and workflows to AzureRM Terraform, AKS, ACR, Azure Monitor / Log Analytics, Azure CNI Overlay, and Microsoft Entra OIDC federation.
- GitHub Actions uses `azure/login@v2`; CI pushes images to ACR and updates GitOps values.
- Portable application source, Dockerfiles, Helm chart, observability configurations, tests, and dashboards were retained.
- This archive has not been applied to an Azure subscription and was not end-to-end tested against live Azure resources. Run Terraform validation and plan before applying; chart compatibility, identity federation, network policy and observability resource sizing must be verified in the target subscription.
