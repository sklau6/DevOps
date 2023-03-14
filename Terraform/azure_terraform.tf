# Configure the Azure provider
provider "azurerm" {
  subscription_id = "my-subscription-id"
  tenant_id       = "my-tenant-id"
  client_id       = "my-client-id"
  client_secret   = "my-client-secret"
}

# Create an Azure virtual network
resource "azurerm_virtual_network" "example" {
  name                = "example-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
}

# Create an Azure virtual machine
resource "azurerm_virtual_machine" "example" {
  name                  = "example-vm"
  location              = azurerm_virtual_network.example.location
  resource_group_name   = "example-resource-group"
  network_interface_ids = [azurerm_network_interface.example.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "example-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "example-vm"
    admin_username = "adminuser"
    admin_password = "password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "dev"
  }
}

# Create an Azure network interface
resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_virtual_network.example.location
  resource_group_name = "example-resource-group"

  ip_configuration {
    name                          = "example-ip-config"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create an Azure subnet
resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = "example-resource-group"
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Output the public IP address of the virtual machine
output "public_ip_address" {
  value = azurerm_network_interface.example.private_ip_address
}
