variable "prefix" {
  type    = string
  default = "rsadevops"
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
