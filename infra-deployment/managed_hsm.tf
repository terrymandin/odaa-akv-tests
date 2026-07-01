// Azure Key Vault Managed HSM instance (optional, controlled by deploy_managed_hsm)
resource "azurerm_key_vault_managed_hardware_security_module" "mhsm" {
  count = var.deploy_managed_hsm ? 1 : 0

  name                = "mhsm-exascale-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_B1"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  // Current user is configured as HSM admin
  admin_object_ids = [data.azurerm_client_config.current.object_id]

  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  // Restrict access to trusted services, private endpoints subnet, and caller public IP
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags

    lifecycle {
        ignore_changes = [ tags ]
    }
}

#Networking

# Private DNS Zone for Managed HSM
resource "azurerm_private_dns_zone" "mhsm" {
  count               = var.deploy_managed_hsm ? 1 : 0
  name                = "privatelink.managedhsm.azure.net"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}


# Link Private DNS Zone for Managed HSM to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mhsm" {
  count                 = var.deploy_managed_hsm ? 1 : 0
  name                  = "mhsm-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.mhsm[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}
# Private Endpoint for Managed HSM
resource "azurerm_private_endpoint" "mhsm" {
  count               = var.deploy_managed_hsm ? 1 : 0
  name                = "pe-mhsm-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-mhsm"
    private_connection_resource_id = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
    is_manual_connection           = false
    subresource_names              = ["managedHSM"]
  }

  private_dns_zone_group {
    name                 = "mhsm-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.mhsm[0].id]
  }

  tags = var.tags
}



// Managed HSM keys (created only when deploy_managed_hsm is true)

# RSA-HSM keys
# resource "azurerm_key_vault_managed_hardware_security_module_key" "rsa_2048" {
#   count    = var.deploy_managed_hsm ? 1 : 0
#   name     = "mhsm-encryption-rsa-2048"
#   managed_hsm_id   = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
#   key_type = "RSA-HSM"
#   key_size = 2048

#   key_opts = [
#     "decrypt",
#     "encrypt",
#     "sign",
#     "unwrapKey",
#     "verify",
#     "wrapKey",
#   ]

#   tags = merge(var.tags, {
#     "key-purpose" = "mhsm-encryption-rsa-2048"
#   })
# }

# resource "azurerm_key_vault_managed_hardware_security_module_key" "rsa_3072" {
#   count    = var.deploy_managed_hsm ? 1 : 0
#   name     = "mhsm-encryption-rsa-3072"
#   managed_hsm_id   = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
#   key_type = "RSA-HSM"
#   key_size = 3072
#   key_opts = azurerm_key_vault_managed_hardware_security_module_key.rsa_2048[0].key_opts

#   tags = merge(var.tags, {
#     "key-purpose" = "mhsm-encryption-rsa-3072"
#   })
# }

# resource "azurerm_key_vault_managed_hardware_security_module_key" "rsa_4096" {
#   count    = var.deploy_managed_hsm ? 1 : 0
#   name     = "mhsm-encryption-rsa-4096"
#   managed_hsm_id   = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
#   key_type = "RSA-HSM"
#   key_size = 4096
#   key_opts = azurerm_key_vault_managed_hardware_security_module_key.rsa_2048[0].key_opts

#   tags = merge(var.tags, {
#     "key-purpose" = "mhsm-encryption-rsa-4096"
#   })
# }

# EC-HSM keys
# resource "azurerm_key_vault_managed_hardware_security_module_key" "ec_p256" {
#   count    = var.deploy_managed_hsm ? 1 : 0
#   name     = "mhsm-encryption-ec-p256"
#   managed_hsm_id   = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
#   key_type = "EC-HSM"
#   curve    = "P-256"

#   key_opts = [
#     "sign",
#     "verify",
#   ]

#   tags = merge(var.tags, {
#     "key-purpose" = "mhsm-encryption-ec-p256"
#   })
# }

# resource "azurerm_key_vault_managed_hardware_security_module_key" "ec_p256k" {
#   count    = var.deploy_managed_hsm ? 1 : 0
#   name     = "mhsm-encryption-ec-p256k"
#   managed_hsm_id   = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
#   key_type = "EC-HSM"
#   curve    = "P-256K"
#   key_opts = azurerm_key_vault_managed_hardware_security_module_key.ec_p256[0].key_opts

#   tags = merge(var.tags, {
#     "key-purpose" = "mhsm-encryption-ec-p256k"
#   })
# }

# resource "azurerm_key_vault_managed_hardware_security_module_key" "ec_p384" {
#   count    = var.deploy_managed_hsm ? 1 : 0
#   name     = "mhsm-encryption-ec-p384"
#   managed_hsm_id   = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
#   key_type = "EC-HSM"
#   curve    = "P-384"
#   key_opts = azurerm_key_vault_managed_hardware_security_module_key.ec_p256[0].key_opts

#   tags = merge(var.tags, {
#     "key-purpose" = "mhsm-encryption-ec-p384"
#   })
# }

# resource "azurerm_key_vault_managed_hardware_security_module_key" "ec_p521" {
#   count    = var.deploy_managed_hsm ? 1 : 0
#   name     = "mhsm-encryption-ec-p521"
#   managed_hsm_id   = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
#   key_type = "EC-HSM"
#   curve    = "P-521"
#   key_opts = azurerm_key_vault_managed_hardware_security_module_key.ec_p256[0].key_opts

#   tags = merge(var.tags, {
#     "key-purpose" = "mhsm-encryption-ec-p521"
#   })
# }

