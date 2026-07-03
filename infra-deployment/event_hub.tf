# Event Hub infrastructure for streaming diagnostic logs
# Provides an alternative to Log Analytics for log collection and streaming

# Event Hub Namespace
resource "azurerm_eventhub_namespace" "main" {
  count = var.enable_eventhub_logging ? 1 : 0

  name                = "evhns-${var.location}-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  capacity            = 1

  tags = var.tags
}

# Event Hub for diagnostic logs
resource "azurerm_eventhub" "diagnostic_logs" {
  count = var.enable_eventhub_logging ? 1 : 0

  name              = "evh-diagnostic-logs"
  namespace_id      = azurerm_eventhub_namespace.main[0].id
  partition_count   = 2
  message_retention = 1
}

# Authorization rule for diagnostic settings
resource "azurerm_eventhub_namespace_authorization_rule" "diagnostic" {
  count = var.enable_eventhub_logging ? 1 : 0

  name                = "DiagnosticLogsRule"
  namespace_name      = azurerm_eventhub_namespace.main[0].name
  resource_group_name = azurerm_resource_group.main.name

  listen = true
  send   = true
  manage = false
}

# Diagnostic Settings for Key Vault - Event Hub
resource "azurerm_monitor_diagnostic_setting" "key_vault_eventhub" {
  count = var.enable_eventhub_logging ? 1 : 0

  name                           = "diag-kv-eventhub-${random_integer.suffix.result}"
  target_resource_id             = azurerm_key_vault.main.id
  eventhub_name                  = azurerm_eventhub.diagnostic_logs[0].name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.diagnostic[0].id

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

# Diagnostic Settings for Virtual Network - Event Hub
resource "azurerm_monitor_diagnostic_setting" "vnet_eventhub" {
  count = var.enable_eventhub_logging ? 1 : 0

  name                           = "diag-vnet-eventhub-${random_integer.suffix.result}"
  target_resource_id             = azurerm_virtual_network.main.id
  eventhub_name                  = azurerm_eventhub.diagnostic_logs[0].name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.diagnostic[0].id

  enabled_log {
    category = "VMProtectionAlerts"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Azure Firewall - Event Hub
resource "azurerm_monitor_diagnostic_setting" "firewall_eventhub" {
  count = var.enable_eventhub_logging ? 1 : 0

  name                           = "diag-firewall-eventhub-${random_integer.suffix.result}"
  target_resource_id             = azurerm_firewall.main.id
  eventhub_name                  = azurerm_eventhub.diagnostic_logs[0].name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.diagnostic[0].id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Network Security Group (Jumpbox) - Event Hub
resource "azurerm_monitor_diagnostic_setting" "nsg_jumpbox_eventhub" {
  count = var.enable_eventhub_logging && var.deploy_jumpbox_vm ? 1 : 0

  name                           = "diag-nsg-jumpbox-eventhub-${random_integer.suffix.result}"
  target_resource_id             = azurerm_network_security_group.jumpbox[0].id
  eventhub_name                  = azurerm_eventhub.diagnostic_logs[0].name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.diagnostic[0].id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# Diagnostic Settings for Managed HSM - Event Hub (enabled only when enable_managed_hsm is true)
resource "azurerm_monitor_diagnostic_setting" "managed_hsm_eventhub" {
  count = var.enable_eventhub_logging && var.deploy_managed_hsm ? 1 : 0

  name                           = "diag-mhsm-eventhub-${random_integer.suffix.result}"
  target_resource_id             = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
  eventhub_name                  = azurerm_eventhub.diagnostic_logs[0].name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.diagnostic[0].id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
