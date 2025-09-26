variable "prefix" {
  type    = string
  default = "rsadevops"
}
variable "azure_subscription_id" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "allowed_rdp_cidr" {
  type = string
}

variable "octopus_url" {
  type = string
}

variable "octopus_api_key" {
  type      = string
  sensitive = true
}

variable "alert_email" {
  type = string
}

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  type = string
}

variable "octopus_space" {
  type = string
}

variable "octopus_environment" {
  type = string
}

variable "octopus_roles" {
  type = string
}
# VM Size
variable "vm_size" {
  description = "The size of the Azure VM"
  type        = string
  default     = "Standard_B2s" # Small, cost-effective VM size
}

# VM Admin Username
variable "admin_username" {
  description = "The admin username for the VM"
  type        = string
  default     = "azureadmin"
}
