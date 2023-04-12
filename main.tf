resource "azurerm_resource_group" "res-0" {
  location = var.location
  name     = var.app_name
}
resource "azurerm_private_dns_zone" "res-9" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.res-0.name
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_private_dns_a_record" "res-10" {
  name                = var.app_name
  records             = ["10.0.1.4"]
  resource_group_name = azurerm_resource_group.res-0.name
  ttl       = 10
  zone_name = "privatelink.azurewebsites.net"
  depends_on = [
    azurerm_private_dns_zone.res-9,
  ]
}

resource "azurerm_private_dns_a_record" "res-11" {
  name                  = "${var.app_name}.scm"
  records             = ["10.0.1.4"]
  resource_group_name = azurerm_resource_group.res-0.name
  ttl       = 10
  zone_name = "privatelink.azurewebsites.net"
  depends_on = [
    azurerm_private_dns_zone.res-9,
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "res-13" {
  name                  = "${var.app_name}-link"
  private_dns_zone_name = "privatelink.azurewebsites.net"
  resource_group_name   = azurerm_resource_group.res-0.name
  virtual_network_id = azurerm_virtual_network.res-18.id
  depends_on = [
    azurerm_private_dns_zone.res-9,
    azurerm_virtual_network.res-18,
  ]
}

resource "azurerm_private_endpoint" "res-14" {
  location            = var.location
  name                = "h-private-endpoint"
  resource_group_name = azurerm_resource_group.res-0.name
  subnet_id  = azurerm_subnet.res-20.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.res-9.id]
  
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = "h-private-endpoint"
    private_connection_resource_id = azurerm_linux_web_app.res-23.id
    subresource_names              = ["sites"]
  }
  depends_on = [
    azurerm_private_dns_zone.res-9,
    azurerm_subnet.res-20,
  ]
}

resource "azurerm_public_ip" "res-16" {
  allocation_method   = "Static"
  location            = var.location
  name                = "h-vnet-ip"
  resource_group_name = azurerm_resource_group.res-0.name
  sku                 = "Standard"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}

resource "azurerm_public_ip" "res-17" {
  allocation_method   = "Static"
  location            = var.location
  name                = "test-vm-ip"
  resource_group_name = azurerm_resource_group.res-0.name
  sku                 = "Standard"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}

resource "azurerm_virtual_network" "res-18" {
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  name                = var.vnet-name
  resource_group_name = azurerm_resource_group.res-0.name
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_subnet" "res-19" {
  address_prefixes     = ["10.0.2.0/26"]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.res-0.name
  virtual_network_name = var.vnet-name
  depends_on = [
    azurerm_virtual_network.res-18,
  ]
}

resource "azurerm_subnet" "res-20" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "h-subnet-inbound"
  resource_group_name  = azurerm_resource_group.res-0.name
  virtual_network_name = var.vnet-name
  depends_on = [
    azurerm_virtual_network.res-18,
  ]
}
resource "azurerm_subnet" "res-21" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "h-subnet-outbound"
  resource_group_name  = azurerm_resource_group.res-0.name
  service_endpoints    = ["Microsoft.Storage"]
  virtual_network_name = var.vnet-name
  delegation {
    name = "delegation"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      name    = "Microsoft.Web/serverFarms"
    }
  }
  depends_on = [
    azurerm_virtual_network.res-18,
  ]
}

resource "azurerm_service_plan" "res-22" {
  location            = var.location
  name                = "h-service-plan"
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.res-0.name
  sku_name            = "B1"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_linux_web_app" "res-23" {
  app_settings = {
    DOCKER_REGISTRY_SERVER_PASSWORD     = ""
    DOCKER_REGISTRY_SERVER_URL          = "https://index.docker.io"
    DOCKER_REGISTRY_SERVER_USERNAME     = ""
    #DOCKER_IMAGE = "hrvoje/h-consul:latest"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }
  https_only                = true
  location                  = var.location
  name                      = var.app_name
  resource_group_name       = azurerm_resource_group.res-0.name
  service_plan_id           = azurerm_service_plan.res-22.id
  virtual_network_subnet_id = azurerm_subnet.res-21.id
  site_config {
    always_on              = false
    ftps_state             = "FtpsOnly"
    vnet_route_all_enabled = true
    application_stack {
        docker_image  = "hrvoje/h-consul"
        docker_image_tag = "latest" 
      }
  }
  depends_on = [
    azurerm_subnet.res-21,
    azurerm_service_plan.res-22,
  ]
}





######configure VM to access web app in a private network

resource "random_password" "password" {
  length = 16
  special = true
  override_special = "_%@"
}

resource "azurerm_windows_virtual_machine" "res-1" {
  admin_password        = random_password.password.result
  admin_username        = "h"
  location              = var.location
  name                  = "test-vm"
  network_interface_ids = [azurerm_network_interface.res-5.id]
  resource_group_name   = azurerm_resource_group.res-0.name
  secure_boot_enabled   = true
  size                  = "Standard_DS1_v2"
  vtpm_enabled          = true
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  depends_on = [
    azurerm_network_interface.res-5,
  ]
}
resource "azurerm_virtual_machine_extension" "res-2" {
  auto_upgrade_minor_version = true
  name                       = "GuestAttestation"
  publisher                  = "Microsoft.Azure.Security.WindowsAttestation"
  settings                   = "{\"AttestationConfig\":{\"AscSettings\":{\"ascReportingEndpoint\":\"\",\"ascReportingFrequency\":\"\"},\"MaaSettings\":{\"maaEndpoint\":\"\",\"maaTenantName\":\"GuestAttestation\"},\"disableAlerts\":\"false\",\"useCustomToken\":\"false\"}}"
  type                       = "GuestAttestation"
  type_handler_version       = "1.0"
  virtual_machine_id         = azurerm_windows_virtual_machine.res-1.id
  depends_on = [
    azurerm_windows_virtual_machine.res-1,
  ]
}
resource "azurerm_bastion_host" "res-3" {
  location            = var.location
  name                = "h-vnet-bastion"
  resource_group_name = azurerm_resource_group.res-0.name
  ip_configuration {
    name                 = "IpConf"
    public_ip_address_id = azurerm_public_ip.res-16.id
    subnet_id            = azurerm_subnet.res-19.id
  }
  depends_on = [
    azurerm_public_ip.res-16,
    azurerm_subnet.res-19,
  ]
}
resource "azurerm_network_interface" "res-4" {
  location            = var.location
  name                = "h-private-endpoint.nic.0603a61f-aa28-487b-b56c-ed7594fc7e86"
  resource_group_name = azurerm_resource_group.res-0.name
  ip_configuration {
    name                          = "privateEndpointIpConfig.a0e1032d-7123-43c1-8983-2b6cc4bacf2f"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.res-20.id
  }
  depends_on = [
    azurerm_subnet.res-20,
  ]
}
resource "azurerm_network_interface" "res-5" {
  enable_accelerated_networking = true
  location                      = var.location
  name                          = "test-vm998"
  resource_group_name           = azurerm_resource_group.res-0.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"    
    public_ip_address_id          = azurerm_public_ip.res-17.id
    subnet_id                     = azurerm_subnet.res-20.id
  } 
  depends_on = [
    azurerm_public_ip.res-17,
    azurerm_subnet.res-20,
  ]
}
resource "azurerm_network_interface_security_group_association" "res-6" {
  network_interface_id = azurerm_network_interface.res-5.id
  network_security_group_id = azurerm_network_security_group.res-7.id
  depends_on = [
    azurerm_network_interface.res-5,
    azurerm_network_security_group.res-7,
  ]
}
resource "azurerm_network_security_group" "res-7" {
  location            = var.location
  name                = "test-vm-nsg"
  resource_group_name = azurerm_resource_group.res-0.name
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_network_security_rule" "res-8" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "RDP"
  network_security_group_name = "test-vm-nsg"
  priority                    = 300
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.res-0.name
  source_address_prefix       = "*"
  source_port_range           = "*"
  depends_on = [
    azurerm_network_security_group.res-7,
  ]
}



######provider stuff
provider "azurerm" {
  features {}
}

terraform {
  backend "local" {}
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.46.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}



####Ouputs and variables
output "windows_vm_password" {
  value       = random_password.password.result
  description = "password for the windows vm"
  sensitive = true
}


variable "vnet-name" {
  type = string
  default = "h-vnet"
}

variable "location" {
  type = string
  default = "eastus"
}

variable "app_name" {
  type = string
  default = "h-daff7a"
}
