output "lb_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "rdp_endpoints" {
  value = {
    vm0 = "RDP -> ${azurerm_public_ip.pip.ip_address}:50001"
    vm1 = "RDP -> ${azurerm_public_ip.pip.ip_address}:50002"
  }
}

output "admin_username" {
  value = var.admin_username
}
