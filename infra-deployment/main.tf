# Resource Group for Oracle Exascale + Azure Key Vault Integration
# This resource group will contain all resources for the private endpoint scenario

resource "random_integer" "suffix" {
  min = 100
  max = 999
}

resource "random_integer" "vnet_octet" {
  min = var.vnet_octet_min
  max = var.vnet_octet_max
}

resource "azurerm_resource_group" "main" {
  name     = "rg-exascale-${var.location}-${random_integer.suffix.result}"
  location = var.location

  tags = var.tags
}

# Virtual Network for Oracle ADB and Azure Key Vault integration
resource "azurerm_virtual_network" "main" {
  name                = "vnet-exascale-${var.location}-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.${random_integer.vnet_octet.result}.0.0/${var.vnet_address_space_suffix}"]

  tags = var.tags
}

# Subnet for Oracle Autonomous Database with delegation
resource "azurerm_subnet" "adbs" {
  name                            = var.adbs_subnet_name
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
  address_prefixes                = ["10.${random_integer.vnet_octet.result}.1.0/${var.adbs_subnet_prefix_length}"]

  delegation {
    name = var.oracle_delegation_name

    service_delegation {
      name = "Oracle.Database/networkAttachments"
      actions = [
        "Microsoft.Network/networkinterfaces/*",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Subnet for private endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                            = "private-endpoints-subnet"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
  address_prefixes                = ["10.${random_integer.vnet_octet.result}.2.0/${var.adbs_subnet_prefix_length}"]
}



# Subnet for NAT Gateway
resource "azurerm_subnet" "nat_gateway" {
  name                            = "nat-gateway-subnet"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
  address_prefixes                = ["10.${random_integer.vnet_octet.result}.3.0/${var.adbs_subnet_prefix_length}"]
}

# Subnet for virtual machines (jumpbox)
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.${random_integer.vnet_octet.result}.4.0/${var.adbs_subnet_prefix_length}"]
}

# Subnet for Azure Firewall (required name: AzureFirewallSubnet)
resource "azurerm_subnet" "firewall" {
  name                            = "AzureFirewallSubnet"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
  address_prefixes                = ["10.${random_integer.vnet_octet.result}.5.0/26"]
}

