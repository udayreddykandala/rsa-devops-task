output "lb_public_ip" {
  description = "The public IP of the load balancer"
  value       = data.azurerm_public_ip.lb_pip.ip_address
}

output "rdp_endpoints" {
  description = "RDP connection endpoints for the VMs"
  value = {
    vm0 = "RDP -> ${data.azurerm_public_ip.lb_pip.ip_address}:50001"
    vm1 = "RDP -> ${data.azurerm_public_ip.lb_pip.ip_address}:50002"
  }
}

output "admin_credentials" {
  description = "VM admin credentials"
  value = {
    username = var.admin_username
    password = random_password.admin.result
  }
  sensitive = true
}
