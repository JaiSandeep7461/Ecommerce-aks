variable "subscription_id" {
  description = "Azure subscription ID for the AzuerDevops subscription"
  type        = string
  default     = "cc9bc945-4e68-4631-a463-3bf91022981b"

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID-shaped Azure subscription ID."
  }
}

variable "storage_allowed_ip_rules" {
  description = "Trusted public IPv4 addresses allowed to reach the Terraform state storage account (bare IPs, not CIDR)"
  type        = list(string)

  validation {
    condition = length(var.storage_allowed_ip_rules) > 0 && alltrue([
      for ip in var.storage_allowed_ip_rules :
      can(cidrhost("${ip}/32", 0)) &&
      !startswith(ip, "10.") &&
      !startswith(ip, "192.168.") &&
      !can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", ip)) &&
      !startswith(ip, "127.") &&
      !startswith(ip, "169.254.")
    ])
    error_message = "Provide at least one valid public IPv4 address (without /32). Private, loopback, and link-local addresses are not allowed."
  }
}

variable "location" {
  description = "Azure region for the state resource group and storage account"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Dedicated resource group for Terraform state storage"
  type        = string
  default     = "rg-zero-to-prod-tfstate"
}

variable "storage_account_name" {
  description = "Optional globally unique lowercase storage account name"
  type        = string
  default     = ""
}
