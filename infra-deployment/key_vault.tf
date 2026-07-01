# Azure Key Vault for Oracle Autonomous Database encryption
# This Key Vault will store encryption keys used by the ADBS

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "adbs-kv-${random_integer.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  # Enable public network access
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.tags
}

# Access policy for the current user (Terraform executor)
resource "azurerm_key_vault_access_policy" "terraform_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Backup",
    "Create",
    "Decrypt",
    "Delete",
    "Encrypt",
    "Get",
    "Import",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Sign",
    "UnwrapKey",
    "Update",
    "Verify",
    "WrapKey",
    "Release",
    "Rotate",
    "GetRotationPolicy",
    "SetRotationPolicy"
  ]

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set"
  ]

  certificate_permissions = [
    "Backup",
    "Create",
    "Delete",
    "DeleteIssuers",
    "Get",
    "GetIssuers",
    "Import",
    "List",
    "ListIssuers",
    "ManageContacts",
    "ManageIssuers",
    "Purge",
    "Recover",
    "Restore",
    "SetIssuers",
    "Update"
  ]
}

# RSA encryption keys for ADBS
resource "azurerm_key_vault_key" "rsa_2048" {
  name         = "adbs-encryption-rsa-2048"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]

  tags = merge(var.tags, {
    "key-purpose" = "adbs-encryption-rsa-2048"
  })

  rotation_policy {
    expire_after = "P1M"
    notify_before_expiry = "P7D"

    automatic {
      time_before_expiry = "P7D"
    }
  }
}

resource "azurerm_key_vault_key" "rsa_3072" {
  name         = "adbs-encryption-rsa-3072"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 3072

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]

  tags = merge(var.tags, {
    "key-purpose" = "adbs-encryption-rsa-3072"
  })

  rotation_policy {
    expire_after          = "P1M"
    notify_before_expiry  = "P7D"

    automatic {
      time_before_expiry = "P7D"
    }
  }
}

resource "azurerm_key_vault_key" "rsa_4096" {
  name         = "adbs-encryption-rsa-4096"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]

  tags = merge(var.tags, {
    "key-purpose" = "adbs-encryption-rsa-4096"
  })

  rotation_policy {
    expire_after          = "P1M"
    notify_before_expiry  = "P7D"

    automatic {
      time_before_expiry = "P7D"
    }
  }
}

# EC encryption keys
resource "azurerm_key_vault_key" "ec_p256" {
  name         = "adbs-encryption-ec-p256"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "EC"
  curve        = "P-256"

  key_opts = [
    "sign",
    "verify",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]

  tags = merge(var.tags, {
    "key-purpose" = "adbs-encryption-ec-p256"
  })

  rotation_policy {
    expire_after          = "P1M"
    notify_before_expiry  = "P7D"

    automatic {
      time_before_expiry = "P7D"
    }
  }
}

resource "azurerm_key_vault_key" "ec_p256k" {
  name         = "adbs-encryption-ec-p256k"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "EC"
  curve        = "P-256K"

  key_opts = [
    "sign",
    "verify",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]

  tags = merge(var.tags, {
    "key-purpose" = "adbs-encryption-ec-p256k"
  })

  rotation_policy {
    expire_after          = "P1M"
    notify_before_expiry  = "P7D"

    automatic {
      time_before_expiry = "P7D"
    }
  }
}

resource "azurerm_key_vault_key" "ec_p384" {
  name         = "adbs-encryption-ec-p384"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "EC"
  curve        = "P-384"

  key_opts = [
    "sign",
    "verify",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]

  tags = merge(var.tags, {
    "key-purpose" = "adbs-encryption-ec-p384"
  })

  rotation_policy {
    expire_after          = "P1M"
    notify_before_expiry  = "P7D"

    automatic {
      time_before_expiry = "P7D"
    }
  }
}

resource "azurerm_key_vault_key" "ec_p521" {
  name         = "adbs-encryption-ec-p521"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "EC"
  curve        = "P-521"

  key_opts = [
    "sign",
    "verify",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]

  tags = merge(var.tags, {
    "key-purpose" = "adbs-encryption-ec-p521"
  })

  rotation_policy {
    expire_after          = "P1M"
    notify_before_expiry  = "P7D"

    automatic {
      time_before_expiry = "P7D"
    }
  }
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "keyvault-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-keyvault-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }

  tags = var.tags
}

### Disable public network access after all Key Vault configurations are complete
### This ensures the Key Vault is only accessible via Private Endpoint
# resource "null_resource" "disable_keyvault_public_access" {
#   # Trigger this resource after all Key Vault dependencies are created
#   triggers = {
#     key_vault_id          = azurerm_key_vault.main.id
#     private_endpoint_id   = azurerm_private_endpoint.keyvault.id
#     encryption_key_id     = azurerm_key_vault_key.private_encryption_key.id
#     access_policy_id      = azurerm_key_vault_access_policy.terraform_user.id
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       az keyvault update \
#         --name ${azurerm_key_vault.main.name} \
#         --resource-group ${azurerm_resource_group.main.name} \
#         --public-network-access Disabled
#     EOT
#   }

#   depends_on = [
#     azurerm_key_vault.main,
#     azurerm_key_vault_access_policy.terraform_user,
#     azurerm_key_vault_key.private_encryption_key,
#     azurerm_private_endpoint.keyvault,
#     azurerm_private_dns_zone_virtual_network_link.keyvault
#   ]
# }
