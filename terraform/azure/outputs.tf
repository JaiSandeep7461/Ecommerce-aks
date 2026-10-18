output "resource_group_name" {
  value = azurerm_resource_group.platform.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.platform.name
}

output "aks_fqdn" {
  value = azurerm_kubernetes_cluster.platform.fqdn
}

output "acr_name" {
  value = azurerm_container_registry.platform.name
}

output "acr_login_server" {
  value = azurerm_container_registry.platform.login_server
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.platform.id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.platform.oidc_issuer_url
}

output "sonarqube_url" {
  description = "URL for optional SonarQube VM; null when deploy_sonarqube is false"
  value       = var.deploy_sonarqube ? "http://${azurerm_public_ip.sonarqube[0].ip_address}:9000" : null
}
