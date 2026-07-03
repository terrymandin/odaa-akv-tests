# Azure Firewall for centralized network security and traffic inspection
# All outbound traffic from subnets will route through this firewall



# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-firewall-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Azure Firewall (Standard tier)
resource "azurerm_firewall" "main" {
  name                = "afw-${var.location}-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.tags
    lifecycle {
    ignore_changes = [ tags ]
  }
}


# Route Table to force traffic through firewall
resource "azurerm_route_table" "firewall" {
  name                = "rt-firewall-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Default route to firewall
  route {
    name                   = "DefaultRouteToFirewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }

  tags = var.tags
}

# # Associate route table with VM subnet. x.x.4.0/24
# resource "azurerm_subnet_route_table_association" "vm_subnet" {
#   subnet_id      = azurerm_subnet.vm_subnet.id
#   route_table_id = azurerm_route_table.firewall.id
# }

# Associate route table with private endpoints subnet. x.x.2.0/24
resource "azurerm_subnet_route_table_association" "private_endpoints" {
  subnet_id      = azurerm_subnet.private_endpoints.id
  route_table_id = azurerm_route_table.firewall.id
}

# Associate route table with Oracle delegated subnet. x.x.1.0/24
resource "azurerm_subnet_route_table_association" "oracle_subnet" {
  subnet_id      = azurerm_subnet.oracle.id
  route_table_id = azurerm_route_table.firewall.id
}

# Associate route table with all subnets in vnet. x.x.3.0/24
resource "azurerm_subnet_route_table_association" "nat_gateway_subnet" {
  subnet_id      = azurerm_subnet.nat_gateway.id
  route_table_id = azurerm_route_table.firewall.id
}

