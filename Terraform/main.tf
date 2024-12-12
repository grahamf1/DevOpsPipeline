terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"  
    }
  }
  required_version = ">= 1.0.0" 
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

data "azurerm_resource_group" "rg" {
  name = "1-b90f4d80-playground-sandbox"
}

resource "azurerm_virtual_network" "main_vnet" {
  name                = "main-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "main_subnet" {
  name                 = "main-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "jenkins_pip" {
  name                = "jenkins-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "docker_pip" {
  name                = "docker-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "jenkins_nic" {
  name                = "jenkins-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins_pip.id
  }
}

resource "azurerm_network_interface" "docker_nic" {
  name                = "docker-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.docker_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "jenkins_vm" {
  name                = "jenkins-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  admin_password      = var.admin_password

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  network_interface_ids = [
    azurerm_network_interface.jenkins_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(file("install-jenkins.txt"))

  disable_password_authentication = false
}

resource "azurerm_linux_virtual_machine" "docker_vm" {
  name                = "docker-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  admin_password      = var.admin_password
  
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  network_interface_ids = [
    azurerm_network_interface.docker_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(file("install-docker.txt", {
    jenkins_password = var.jenkins_password
  }))

  disable_password_authentication = false
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "cosmosdb20241212"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = data.azurerm_resource_group.rg.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableTable"
  }
  
  capabilities {
    name = "EnableServerless"
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "acr20241212"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

 resource "azurerm_service_plan" "app_service_plan" {
  name                = "webappplan202412121"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"  
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "app_service" {
  name                = "webapp202412121"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.app_service_plan.id
  site_config {}

  app_settings = {
    "DOCKER_REGISTRY_SERVER_URL"      = azurerm_container_registry.acr.login_server
    "DOCKER_REGISTRY_SERVER_USERNAME" = azurerm_container_registry.acr.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = azurerm_container_registry.acr.admin_password
  }
}

output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.cosmosdb.endpoint
}

output "jenkins_public_ip" {
  value = azurerm_public_ip.jenkins_pip.ip_address
}

output "docker_public_ip" {
  value = azurerm_public_ip.docker_pip.ip_address
}