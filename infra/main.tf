terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.0.0" }
  }
}

provider "azurerm" {
   features {} 
   }

# ------------------ Resource Group ------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# ------------------ Networking ------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-http-80"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "rdp-myip"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_rdp_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ------------------ Public Load Balancer ------------------
resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2"]
}

resource "azurerm_lb" "lb" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "bepool" {
  name            = "webpool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "probe" {
  name            = "http"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "http_rule" {
  name                           = "http80"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bepool.id]
  probe_id                       = azurerm_lb_probe.probe.id
}

# NAT rules for RDP
resource "azurerm_lb_nat_rule" "rdp_nat" {
  count                          = 2
  name                           = "rdp-${count.index}"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "public"
  frontend_port                  = 50001 + count.index
  backend_port                   = 3389
}

# ------------------ NICs ------------------
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "${var.prefix}-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    load_balancer_backend_address_pool_ids = [
      azurerm_lb_backend_address_pool.bepool.id
    ]
  }
}

resource "azurerm_network_interface_nat_rule_association" "nic_nat" {
  count                 = 2
  network_interface_id  = azurerm_network_interface.nic[count.index].id
  ip_configuration_name = "ipcfg"
  nat_rule_id           = azurerm_lb_nat_rule.rdp_nat[count.index].id
}

# ------------------ Windows VMs ------------------
resource "azurerm_windows_virtual_machine" "vm" {
  count                 = 2
  name                  = "${var.prefix}-vm-${count.index}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  zone                  = count.index == 0 ? "1" : "2"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# ------------------ Bootstrap: IIS + Tentacle ------------------
resource "azurerm_virtual_machine_extension" "cse" {
  count                = 2
  name                 = "octopus-bootstrap"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -File install_tentacle.ps1 -OctopusUrl '${var.octopus_url}' -ApiKey '${var.octopus_api_key}' -Space '${var.octopus_space}' -Environment '${var.octopus_environment}' -Roles '${var.octopus_roles}'"
    fileUris = [
      "https://raw.githubusercontent.com/${var.github_owner}/${var.github_repo}/${var.github_branch}/infra/scripts/install_tentacle.ps1"
    ]
  })
}

# ------------------ Monitoring ------------------
resource "azurerm_application_insights" "appi" {
  name                = "${var.prefix}-appi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_monitor_action_group" "ag" {
  name                = "${var.prefix}-ag"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "alert"

  email_receiver {
    name          = "ops"
    email_address = var.alert_email
  }
}

resource "azurerm_application_insights_web_test" "webtest" {
  name                    = "${var.prefix}-ping"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  application_insights_id = azurerm_application_insights.appi.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["emea-nl-ams-azr", "emea-ru-msa-edge"]

  configuration = <<XML
<WebTest Name="ping" Id="00000000-0000-0000-0000-000000000000" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="30" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Items>
    <Request Method="GET" Guid="11111111-1111-1111-1111-111111111111" Version="1.1" Url="http://${azurerm_public_ip.pip.ip_address}/" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML

  tags = {
    "hidden-link:${azurerm_application_insights.appi.id}" = "Resource"
  }
}

resource "azurerm_monitor_metric_alert" "avail_alert" {
  name                = "${var.prefix}-avail-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_application_insights.appi.id]
  description         = "Availability under 99%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action { action_group_id = azurerm_monitor_action_group.ag.id }
}
