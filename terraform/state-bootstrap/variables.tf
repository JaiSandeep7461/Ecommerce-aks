variable "subscription_id" {
  description = "Azure subscription ID for the AzureDevops subscription"
  type        = string
  default     = "cc9bc945-4e68-4631-a463-3bf91022981b"

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID-shaped Azure subscription ID."
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
