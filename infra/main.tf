terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# ----------------------------
# Resource Group (data source)
# ----------------------------
data "azurerm_resource_group" "rg" {
  name = "rg-devops-task"
}

data "azurerm_virtual_network" "vnet" {
  name                = "vnet-devops-task"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_public_ip" "lb_pip" {
  name                = "pip-lb"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# ----------------------------
# Subnet
# ----------------------------
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ----------------------------
# Load Balancer
# ----------------------------
resource "azurerm_lb" "lb" {
  name                = "${var.prefix}-lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = data.azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "bepool" {
  name            = "BackendPool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "http_probe" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "http_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bepool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
}

# NAT rules for RDP
resource "azurerm_lb_nat_rule" "rdp_nat" {
  count                          = 2
  name                           = "rdp-nat-${count.index}"
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "PublicIPAddress"
  frontend_port                  = 50001 + count.index
  backend_port                   = 3389
}

# ----------------------------
# NICs
# ----------------------------
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "nic-${count.index}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_bepool" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "ipconfig-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bepool.id
}

resource "azurerm_network_interface_nat_rule_association" "nic_nat" {
  count                 = 2
  network_interface_id  = azurerm_network_interface.nic[count.index].id
  ip_configuration_name = "ipconfig-${count.index}"
  nat_rule_id           = azurerm_lb_nat_rule.rdp_nat[count.index].id
}

# ----------------------------
# Windows VMs + IIS
# ----------------------------
resource "random_password" "admin" {
  length  = 16
  special = true
}

resource "azurerm_windows_virtual_machine" "vm" {
  count                = 2
  name                 = "winvm-${count.index}"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  size                 = var.vm_size
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "iis" {
  count                = 2
  name                 = "iis-install-${count.index}"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
{
  "commandToExecute": "powershell Install-WindowsFeature Web-Server; powershell New-NetFirewallRule -DisplayName 'Allow HTTP' -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow; powershell Set-Content -Path 'C:\\\\inetpub\\\\wwwroot\\\\index.html' -Value 'Hello from VM ${count.index}'"
}
SETTINGS
}

# ----------------------------
# Outputs
# ----------------------------
output "lb_public_ip" {
  value = data.azurerm_public_ip.lb_pip.ip_address
}

output "rdp_endpoints" {
  value = {
    vm0 = "RDP -> ${data.azurerm_public_ip.lb_pip.ip_address}:50001"
    vm1 = "RDP -> ${data.azurerm_public_ip.lb_pip.ip_address}:50002"
  }
}

output "admin_credentials" {
  value     = { username = var.admin_username, password = random_password.admin.result }
  sensitive = true
}
