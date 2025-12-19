provider "azurerm" {
  features {}
  subscription_id = "d18efcbe-caa9-4004-ac2c-7312261e11de"
}

########################
# Resource Group
########################
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

########################
# Network
########################
resource "azurerm_virtual_network" "vnet" {
  name                = "fastapi-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "fastapi-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

########################
# Network Security Group
########################
resource "azurerm_network_security_group" "nsg" {
  name                = "fastapi-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

########################
# Public IP for Load Balancer
########################
resource "azurerm_public_ip" "lb_pip" {
  name                = "fastapi-lb-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

########################
# Load Balancer
########################
resource "azurerm_lb" "lb" {
  name                = "fastapi-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicFrontend"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "bepool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "backend-pool"
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bepool.id]
}

########################
# Public IPs for each VM
########################
resource "azurerm_public_ip" "vm_pip" {
  count               = 2
  name                = "fastapi-vm-pip-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

########################
# Network Interfaces (x2)
########################
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "fastapi-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lb_assoc" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bepool.id
}

########################
# Virtual Machines (x2)
########################
resource "azurerm_linux_virtual_machine" "vm" {
  count               = 2
  name                = "fastapi-vm-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key)
  }

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
}

########################
# PostgreSQL Flexible Server
########################
resource "azurerm_postgresql_flexible_server" "db" {
  name                   = "fastapi-postgres"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location

  administrator_login    = "fastapiuser"
  administrator_password = "StrongPassword123!"

  sku_name   = "B_Standard_B1ms"
  version    = "14"
  storage_mb = 32768

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "fastapi"
  server_id = azurerm_postgresql_flexible_server.db.id
}

########################
# Outputs
########################
output "vm_public_ips" {
  value = azurerm_public_ip.vm_pip[*].ip_address
}

output "lb_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}

output "vm_private_ips" {
  value = azurerm_network_interface.nic[*].private_ip_address
}
