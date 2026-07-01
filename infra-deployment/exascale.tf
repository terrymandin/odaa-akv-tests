# Oracle Exascale Infrastructure
# Deploys Oracle Database@Azure Exascale (Storage Vault + Cloud VM Cluster)
# Controlled by the deploy_exascale variable (false = ADB Serverless, true = Exascale)
#
# Both resources use the AzAPI provider because azurerm does not expose
# Oracle Exascale resource types in the current provider version.

# Oracle Exascale DB Storage Vault
# Provides the Exascale storage tier that the VM Cluster attaches to

resource "azapi_resource" "exascale_storage_vault" {
  count = var.deploy_exascale ? 1 : 0

  type      = "Oracle.Database/exascaleDbStorageVaults@2025-09-01"
  name      = coalesce(var.exascale_storage_vault_config.name, "exavault-${random_integer.suffix.result}")
  parent_id = azurerm_resource_group.main.id
  location  = azurerm_resource_group.main.location

  tags = var.tags

  body = {
    properties = {
      displayName = coalesce(var.exascale_storage_vault_config.display_name, "Exascale Storage Vault ${random_integer.suffix.result}")
      highCapacityDatabaseStorageInput = {
        totalSizeInGbs = var.exascale_storage_vault_config.storage_size_in_gbs
      }
      timeZone = var.exascale_storage_vault_config.time_zone
    }
    zones = [var.exascale_storage_vault_config.availability_zone]
  }

  response_export_values = ["*"]

  timeouts {
    create = "3h"
    update = "3h"
    delete = "3h"
  }
}

# Oracle Exascale Cloud VM Cluster
# Compute tier for Oracle Exascale; connects to the Storage Vault above
# Uses the Oracle-delegated subnet (Oracle.Database/networkAttachments)
# SSH key-based authentication is required (no admin password)

resource "azapi_resource" "exascale_vm_cluster" {
  count = var.deploy_exascale ? 1 : 0

  type      = "Oracle.Database/exadbVmClusters@2025-09-01"
  name      = coalesce(var.exascale_cluster_config.name, "exacluster-${random_integer.suffix.result}")
  parent_id = azurerm_resource_group.main.id
  location  = azurerm_resource_group.main.location

  tags = var.tags

  body = {
    properties = {
      displayName              = coalesce(var.exascale_cluster_config.display_name, "Exascale Cluster ${random_integer.suffix.result}")
      hostname                 = var.exascale_cluster_config.hostname
      clusterName              = var.exascale_cluster_config.cluster_name
      domain                   = var.exascale_cluster_config.domain
      enabledEcpuCount         = var.exascale_cluster_config.enabled_ecpu_count
      totalEcpuCount           = var.exascale_cluster_config.total_ecpu_count
      nodeCount                = var.exascale_cluster_config.node_count
      shape                    = var.exascale_cluster_config.shape
      exascaleDbStorageVaultId = azapi_resource.exascale_storage_vault[0].id
      subnetId                 = azurerm_subnet.adbs.id
      vnetId                   = azurerm_virtual_network.main.id
      sshPublicKeys            = [var.oracle_ssh_public_key]
      licenseModel             = var.exascale_cluster_config.license_model
      timeZone                 = var.exascale_cluster_config.time_zone
      vmFileSystemStorage = {
        totalSizeInGbs = var.exascale_cluster_config.vm_file_system_storage_in_gbs
      }
      dataCollectionOptions = {
        isDiagnosticsEventsEnabled = var.exascale_cluster_config.diagnostics_events_enabled
        isHealthMonitoringEnabled  = var.exascale_cluster_config.health_monitoring_enabled
        isIncidentLogsEnabled      = var.exascale_cluster_config.incident_logs_enabled
      }
    }
    zones = [var.exascale_storage_vault_config.availability_zone]
  }

  response_export_values = ["*"]

  lifecycle {
    precondition {
      condition     = var.oracle_ssh_public_key != ""
      error_message = "oracle_ssh_public_key must be set when deploy_exascale = true. Provide via TF_VAR_oracle_ssh_public_key env var or in terraform.tfvars."
    }
  }

  timeouts {
    create = "4h"
    update = "4h"
    delete = "4h"
  }
}

