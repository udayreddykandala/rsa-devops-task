variable "prefix"            { 
    type = string  default = "rsadevops" 
    }
variable "location"          { 
    type = string  default = "northeurope"
     } # zonal region
variable "vm_size"           { 
    type = string  default = "Standard_B1ms" 
    }
variable "admin_username"    {
     type = string  default = "azureadmin" 
     }
variable "admin_password"    {
     type = string  sensitive = true
      }        # set via TF_VAR_admin_password
variable "allowed_rdp_cidr"  { 
    type = string  default = "0.0.0.0/32" 
    }  # set to your_ip/32

# Octopus
variable "octopus_url"         { 
    type = string 
    }
variable "octopus_api_key"     {
     type = string  sensitive = true 
     }
variable "octopus_space"       { 
    type = string  default = "Demo" 
    }
variable "octopus_environment" { 
    type = string  default = "Prod" 
    }
variable "octopus_roles"       { 
    type = string  default = "web" 
    }

# Raw GitHub path for the bootstrap script (public repo)
variable "github_owner"  { 
    type = string 
    }           # e.g., "udayreddy"
variable "github_repo"   { 
    type = string 
    }           # e.g., "rsa-devops-task"
variable "github_branch" { 
    type = string default = "main" 
    }

# Alerting
variable "alert_email" {
     type = string 
     }
