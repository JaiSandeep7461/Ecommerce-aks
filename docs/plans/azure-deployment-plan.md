# Azure deployment plan

1. **Prerequisites:** Install Azure CLI, Terraform, kubectl, Helm and Docker; select the intended Azure subscription.
2. **Infrastructure:** Run `terraform init`, `fmt`, `validate`, `plan`, and `apply` from `terraform/azure` after reviewing cost and permissions.
3. **Cluster access:** Run `az aks get-credentials` using Terraform outputs and verify `kubectl get nodes`.
4. **Registry:** Log in with `az acr login`; set GitHub variables for Azure OIDC and ACR. Configure Microsoft Entra federated credentials and grant the CI principal `AcrPush` on the registry.
5. **CI:** Push to `main`; GitHub Actions builds the four images, scans them with Trivy, pushes to ACR, signs them with Cosign, and updates dev Helm values.
6. **Add-ons:** Run `scripts/deploy-aks-addons.sh`. Skip observability or Argo CD if not needed for a lower-cost lab.
7. **GitOps:** Verify the repository URL in `deploy/argocd/root-app.yaml`, then apply it. Argo CD syncs the app from Helm values. Use direct Helm deployment instead only when Argo CD is not managing that app.
8. **Verification:** Check pods, services, ingress LoadBalancer IP, logs, Prometheus targets, Grafana dashboards, and a sample order flow.
9. **Production hardening:** Configure Azure Storage remote Terraform state, private ACR/AKS networking as needed, ingress TLS, secret management, resource requests/limits, backups, Azure Database for PostgreSQL, and GitHub production environment approvals.
