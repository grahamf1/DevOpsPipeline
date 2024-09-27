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
data "azurerm_resource_group" "example" {
  name = "1-e4f7ed6b-playground-sandbox"
}

# Define the virtual network
resource "azurerm_virtual_network" "main_vnet" {
  name                = "main-vnet"
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

# Define the subnet
resource "azurerm_subnet" "main_subnet" {
  name                 = "main-subnet"
  resource_group_name  = data.azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Define public IP for Jenkins VM
resource "azurerm_public_ip" "jenkins_pip" {
  name                = "jenkins-pip"
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

# Define public IP for Docker VM
resource "azurerm_public_ip" "docker_pip" {
  name                = "docker-pip"
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

# Define the network interface for Jenkins VM
resource "azurerm_network_interface" "jenkins_nic" {
  name                = "jenkins-nic"
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name

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
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name

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
  resource_group_name = data.azurerm_resource_group.example.name
  location            = data.azurerm_resource_group.example.location
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
  resource_group_name = data.azurerm_resource_group.example.name
  location            = data.azurerm_resource_group.example.location
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

# Output the public IPs of both VMs
output "jenkins_public_ip" {
  value = azurerm_public_ip.jenkins_pip.ip_address
}

output "docker_public_ip" {
  value = azurerm_public_ip.docker_pip.ip_address
}
