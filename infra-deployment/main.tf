# Resource Group for Oracle Exascale + Azure Key Vault Integration
# This resource group will contain all resources for the private endpoint scenario

resource "random_integer" "suffix" {
  min = 100
  max = 999
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
  address_space       = ["10.40.0.0/16"]

  tags = var.tags
}

# Subnet for Oracle Autonomous Database with delegation
resource "azurerm_subnet" "adbs" {
  name                            = local.oracle_subnet_name_effective
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
  address_prefixes                = ["10.40.1.0/${local.oracle_subnet_prefix_length_effective}"]

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
  address_prefixes                = ["10.40.2.0/${local.oracle_subnet_prefix_length_effective}"]
}



# Subnet for NAT Gateway
resource "azurerm_subnet" "nat_gateway" {
  name                            = "nat-gateway-subnet"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
  address_prefixes                = ["10.40.3.0/${local.oracle_subnet_prefix_length_effective}"]
}

# Subnet for virtual machines (jumpbox)
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.40.4.0/${local.oracle_subnet_prefix_length_effective}"]
}

# Subnet for Azure Firewall (required name: AzureFirewallSubnet)
resource "azurerm_subnet" "firewall" {
  name                            = "AzureFirewallSubnet"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
  address_prefixes                = ["10.40.5.0/26"]
}

