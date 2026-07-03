
# # Public IP for NAT Gateway
# resource "azurerm_public_ip" "nat_gateway" {
#   name                = "pip-natgw-${random_integer.suffix.result}"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   allocation_method   = "Static"
#   sku                 = "Standard"

#   tags = var.tags
# }

# # NAT Gateway for outbound connectivity
# resource "azurerm_nat_gateway" "main" {
#   name                = "natgw-exascale-${var.location}-${random_integer.suffix.result}"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   sku_name            = "Standard"

#   tags = var.tags
# }

# # Associate Public IP with NAT Gateway
# resource "azurerm_nat_gateway_public_ip_association" "main" {
#   nat_gateway_id       = azurerm_nat_gateway.main.id
#   public_ip_address_id = azurerm_public_ip.nat_gateway.id
# }

# # Associate NAT Gateway with private endpoints subnet
# resource "azurerm_subnet_nat_gateway_association" "private_endpoints" {
#   subnet_id      = azurerm_subnet.private_endpoints.id
#   nat_gateway_id = azurerm_nat_gateway.main.id
# }

# # Associate NAT Gateway with Oracle delegated subnet
# resource "azurerm_subnet_nat_gateway_association" "oracle" {
#   subnet_id      = azurerm_subnet.oracle.id
#   nat_gateway_id = azurerm_nat_gateway.main.id
# }

# # Associate NAT Gateway with VM subnet
# resource "azurerm_subnet_nat_gateway_association" "vm_subnet" {
#   subnet_id      = azurerm_subnet.vm_subnet.id
#   nat_gateway_id = azurerm_nat_gateway.main.id
# }


