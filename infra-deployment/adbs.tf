# Oracle Autonomous Database resource
# Provides a managed Oracle database instance on Azure
# Disabled when deploy_exascale = true (Exascale uses azurerm_oracle_cloud_vm_cluster instead)

resource "azurerm_oracle_autonomous_database" "main" {
  count = var.deploy_exascale ? 0 : 1

  name                = coalesce(var.autonomous_database_config.name, "adbsakvtest${random_integer.suffix.result}")
  display_name        = coalesce(var.autonomous_database_config.display_name, "adbsakvtest${random_integer.suffix.result}")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  subnet_id          = azurerm_subnet.adbs.id
  virtual_network_id = azurerm_virtual_network.main.id

  db_version                      = var.autonomous_database_config.db_version
  db_workload                     = var.autonomous_database_config.workload
  compute_model                   = var.autonomous_database_config.compute_model
  compute_count                   = var.autonomous_database_config.compute_count
  data_storage_size_in_tbs        = var.autonomous_database_config.storage_size_tbs
  admin_password                  = coalesce(var.adbs_admin_password, "CHANGE_ME_SecureP@ssw0rd123")
  license_model                   = var.autonomous_database_config.license_model
  backup_retention_period_in_days = var.autonomous_database_config.backup_retention_days

  auto_scaling_enabled             = var.autonomous_database_config.auto_scaling_enabled
  auto_scaling_for_storage_enabled = var.autonomous_database_config.auto_scaling_storage_enabled
  mtls_connection_required         = var.autonomous_database_config.mtls_required

  character_set          = var.autonomous_database_config.character_set
  national_character_set = var.autonomous_database_config.national_character_set

  tags = var.tags

  # Extended timeouts for long-running operations
  timeouts {
    create = "2h"
    update = "2h"
    delete = "2h"
  }

  lifecycle {
    ignore_changes = [
      display_name,
      admin_password # Ignore password changes to avoid forcing replacement on imported resources
    ]
  }
}


