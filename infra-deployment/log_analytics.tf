# Log Analytics Workspace for centralized logging and monitoring
# Collects diagnostic logs and metrics from all Azure resources

resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_log_analytics_logging ? 1 : 0

  name                = "law-${var.location}-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}


# Diagnostic settings for Key Vault
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count = var.enable_log_analytics_logging ? 1 : 0

  name                       = "diag-kv-${random_integer.suffix.result}"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic settings for Virtual Network
resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count = var.enable_log_analytics_logging ? 1 : 0

  name                       = "diag-vnet-${random_integer.suffix.result}"
  target_resource_id         = azurerm_virtual_network.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category = "VMProtectionAlerts"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

#Collecting logs from Firewall. AllLogs and AllMetrics  
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = var.enable_log_analytics_logging ? 1 : 0

  name                       = "diag-firewall-${random_integer.suffix.result}"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic settings for Network Security Group (Jumpbox)
resource "azurerm_monitor_diagnostic_setting" "nsg_jumpbox" {
  count = var.enable_log_analytics_logging ? 1 : 0

  name                       = "diag-nsg-jumpbox-${random_integer.suffix.result}"
  target_resource_id         = azurerm_network_security_group.jumpbox.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# Diagnostic settings for Managed HSM (enabled only when enable_managed_hsm is true)
resource "azurerm_monitor_diagnostic_setting" "managed_hsm" {
  count = var.enable_log_analytics_logging && var.deploy_managed_hsm ? 1 : 0

  name                       = "diag-mhsm-${random_integer.suffix.result}"
  target_resource_id         = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
