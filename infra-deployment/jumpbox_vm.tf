# Windows jumpbox VM for secure access to private resources
# This VM provides RDP access to manage Exascale and Key Vault

# Get current public IP address
data "http" "my_public_ip" {
  count = var.deploy_jumpbox_vm ? 1 : 0

  url = "https://api.ipify.org?format=text"
}

# Public IP for jumpbox VM with DNS label
resource "azurerm_public_ip" "jumpbox" {
  count = var.deploy_jumpbox_vm ? 1 : 0

  name                = "pip-${var.jumpbox_config.name}-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = lower("${var.jumpbox_config.name}-${random_integer.suffix.result}")

  tags = var.tags
}

# Network interface for jumpbox VM
resource "azurerm_network_interface" "jumpbox" {
  count = var.deploy_jumpbox_vm ? 1 : 0

  name                = "nic-${var.jumpbox_config.name}-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox[0].id
  }

  tags = var.tags
}

# Windows virtual machine (jumpbox)
resource "azurerm_windows_virtual_machine" "jumpbox" {
  count = var.deploy_jumpbox_vm ? 1 : 0

  name                = var.jumpbox_config.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.jumpbox_config.size
  admin_username      = var.jumpbox_config.admin_username
  admin_password      = local.jumpbox_admin_password_effective

  network_interface_ids = [
    azurerm_network_interface.jumpbox[0].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.jumpbox_config.os_disk_type
    disk_size_gb         = var.jumpbox_config.os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-23h2-pro"
    version   = "latest"
  }

  # Disable boot diagnostics
  boot_diagnostics {}

  tags = var.tags
}

# Network Security Group for jumpbox
resource "azurerm_network_security_group" "jumpbox" {
  count = var.deploy_jumpbox_vm ? 1 : 0

  name                = "nsg-${var.jumpbox_config.name}-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow RDP from my IP address
  security_rule {
    name                       = "AllowRDPFromMyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${chomp(data.http.my_public_ip[0].response_body)}/32"
    destination_address_prefix = "*"
  }

  # Allow outbound to internet
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = var.tags
}

# Associate NSG with network interface
resource "azurerm_network_interface_security_group_association" "jumpbox" {
  count = var.deploy_jumpbox_vm ? 1 : 0

  network_interface_id      = azurerm_network_interface.jumpbox[0].id
  network_security_group_id = azurerm_network_security_group.jumpbox[0].id
}
