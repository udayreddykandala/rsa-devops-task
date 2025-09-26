variable "prefix" {
  type    = string
  default = "rsadevops"
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "vm_size" {
  type    = string
  default = "Standard_B1ms"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "allowed_rdp_cidr" {
  type    = string
  default = "0.0.0.0/32"
}

variable "octopus_url" {
  type = string
}

variable "octopus_api_key" {
  type      = string
  sensitive = true
}

variable "octopus_space" {
  type    = string
  default = "Demo"
}

variable "octopus_environment" {
  type    = string
  default = "Prod"
}

variable "octopus_roles" {
  type    = string
  default = "web"
}

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "alert_email" {
  type = string
}

# ✅ Add this missing variable
variable "azure_subscription_id" {
  type = string
}
