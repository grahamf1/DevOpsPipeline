# Specify the provider with the version
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"  # Ensure you are using the latest compatible version, adjust if needed
    }
  }
  required_version = ">= 1.0.0" 
}

# Specify the provider
provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# Define the existing resource group
data "azurerm_resource_group" "rg" {
  name = "1-cb315a5b-playground-sandbox"
}

# Define the virtual network
resource "azurerm_virtual_network" "main_vnet" {
  name                = "main-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Define the subnet
resource "azurerm_subnet" "main_subnet" {
  name                 = "main-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Define public IP for Jenkins VM
resource "azurerm_public_ip" "jenkins_pip" {
  name                = "jenkins-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Define public IP for Docker VM
resource "azurerm_public_ip" "docker_pip" {
  name                = "docker-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Define the network interface for Jenkins VM
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

# Define the network interface for Docker VM
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

# Define Jenkins Virtual Machine
resource "azurerm_linux_virtual_machine" "jenkins_vm" {
  name                = "jenkins-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  admin_password      = "YourJenkinsPassword123!"  # Add a password for the adminuser

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

  # Use custom_data to provide the cloud-init script for Jenkins
  custom_data = base64encode(file("install-jenkins.txt"))

  disable_password_authentication = false  # Allow password authentication
}

# Define Docker Virtual Machine
resource "azurerm_linux_virtual_machine" "docker_vm" {
  name                = "docker-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  admin_password      = "YourDockerPassword123!"  # Add a password for the adminuser

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

  # Use custom_data to provide the cloud-init script for Docker
  custom_data = base64encode(file("install-docker.txt"))

  disable_password_authentication = false  # Allow password authentication
}

# CosmosDB account with serverless capacity and Table API
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "cosmosdb20241014"
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

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "acr20241014"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# App Service Plan for the Web App
 resource "azurerm_service_plan" "app_service_plan" {
  name                = "webappplan20241014"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"  
  sku_name            = "S1"
}

# Azure Web App with container deployment from ACR
resource "azurerm_linux_web_app" "app_service" {
  name                = "webapp20241014"
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

# Output the CosmosDB endpoint and Web App URL
output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.cosmosdb.endpoint
}

# Output the public IPs of both VMs
output "jenkins_public_ip" {
  value = azurerm_public_ip.jenkins_pip.ip_address
}

output "docker_public_ip" {
  value = azurerm_public_ip.docker_pip.ip_address
}
