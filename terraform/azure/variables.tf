variable "subscription_id" {
  description = "Azure subscription ID for the AzureDevops subscription"
  type        = string
  default     = "cc9bc945-4e68-4631-a463-3bf91022981b"

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID-shaped Azure subscription ID."
  }
}

variable "project" {
  description = "Resource naming prefix"
  type        = string
  default     = "ztd"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Resource group for the platform"
  type        = string
  default     = "rg-zero-to-prod-dev"
}

variable "acr_name" {
  description = "Optional globally unique ACR name; leave empty to generate one"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version; null uses the region default"
  type        = string
  default     = null
  nullable    = true
}

variable "system_node_count" {
  description = "Initial system node count"
  type        = number
  default     = 2
}

variable "system_node_vm_size" {
  description = "AKS system node VM SKU"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "vnet_address_space" {
  description = "Azure CNI Overlay VNet address space"
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "service_cidr" {
  description = "Kubernetes service CIDR; must not overlap VNet"
  type        = string
  default     = "10.30.0.0/16"
}

variable "dns_service_ip" {
  description = "Kubernetes DNS service IP inside service_cidr"
  type        = string
  default     = "10.30.0.10"
}

variable "pod_cidr" {
  description = "Non-overlapping pod CIDR used by Azure CNI Overlay"
  type        = string
  default     = "192.168.0.0/16"
}

variable "deploy_sonarqube" {
  description = "Create an optional SonarQube Azure Linux VM with local PostgreSQL"
  type        = bool
  default     = false
}

variable "sonarqube_vm_size" {
  description = "VM size for the optional SonarQube host"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "sonarqube_ingress_cidr" {
  description = "Single trusted CIDR allowed to reach SonarQube TCP/9000; change from loopback before enabling access"
  type        = string
  default     = "127.0.0.1/32"
}
