resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

data "azurerm_client_config" "current" {}

locals {
  acr_name = var.acr_name != "" ? var.acr_name : "ztdacr${random_string.suffix.result}"
  common_tags = {
    project     = var.project
    managed_by  = "terraform"
    environment = "dev"
  }
}

resource "azurerm_resource_group" "platform" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "platform" {
  name                = "${var.project}-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.platform.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space[0], 8, 1)]
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.project}-aks-identity-${random_string.suffix.result}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_log_analytics_workspace" "platform" {
  name                = "${var.project}-law-${random_string.suffix.result}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_container_registry" "platform" {
  name                          = local.acr_name
  resource_group_name           = azurerm_resource_group.platform.name
  location                      = azurerm_resource_group.platform.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = local.common_tags
}

resource "azurerm_kubernetes_cluster" "platform" {
  name                = "${var.project}-aks-${random_string.suffix.result}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  dns_prefix          = "${var.project}-aks-${random_string.suffix.result}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  # Restrict public Kubernetes API access to explicitly trusted source CIDRs.
  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true
  local_account_disabled            = true


  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.system_node_vm_size
    node_count                  = var.system_node_count
    type                        = "VirtualMachineScaleSets"
    os_sku                      = "AzureLinux"
    vnet_subnet_id              = azurerm_subnet.aks.id
    temporary_name_for_rotation = "systemtmp"
    node_labels                 = { workload = "platform" }
    upgrade_settings {
      max_surge = "10%"
    }
    tags = local.common_tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "azure"
    network_policy      = "azure"
    pod_cidr            = var.pod_cidr
    load_balancer_sku   = "standard"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    outbound_type       = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id
  }

  tags       = local.common_tags
  depends_on = [azurerm_role_assignment.aks_network_contributor]
}

resource "azurerm_role_assignment" "cluster_admin" {
  scope                = azurerm_kubernetes_cluster.platform.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.platform.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.platform.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"
}

# Optional Azure VM equivalent of the original self-hosted SonarQube host.
# Disabled by default to avoid additional VM and public-IP costs.
resource "random_password" "sonarqube_db" {
  count   = var.deploy_sonarqube ? 1 : 0
  length  = 32
  special = false
}

resource "azurerm_public_ip" "sonarqube" {
  count               = var.deploy_sonarqube ? 1 : 0
  name                = "${var.project}-sonarqube-pip"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "sonarqube" {
  count               = var.deploy_sonarqube ? 1 : 0
  name                = "${var.project}-sonarqube-nsg"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowSonarQubeFromTrustedCIDR"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = var.sonarqube_ingress_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "sonarqube" {
  count               = var.deploy_sonarqube ? 1 : 0
  name                = "${var.project}-sonarqube-nic"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aks.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sonarqube[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "sonarqube" {
  count                     = var.deploy_sonarqube ? 1 : 0
  network_interface_id      = azurerm_network_interface.sonarqube[count.index].id
  network_security_group_id = azurerm_network_security_group.sonarqube[count.index].id
}

resource "azurerm_linux_virtual_machine" "sonarqube" {
  count                           = var.deploy_sonarqube ? 1 : 0
  name                            = "${var.project}-sonarqube-vm"
  location                        = azurerm_resource_group.platform.location
  resource_group_name             = azurerm_resource_group.platform.name
  size                            = var.sonarqube_vm_size
  admin_username                  = "azureuser"
  admin_password                  = random_password.sonarqube_db[count.index].result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.sonarqube[count.index].id]
  custom_data = base64encode(templatefile("${path.module}/templates/sonarqube-cloud-init.sh.tftpl", {
    sonar_db_password = random_password.sonarqube_db[count.index].result
  }))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags       = local.common_tags
  depends_on = [azurerm_network_interface_security_group_association.sonarqube]
}
