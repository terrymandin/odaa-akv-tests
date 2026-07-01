# Input variables for the infrastructure deployment

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "uksouth"

  validation {
    condition     = can(regex("^[a-z]+$", var.location))
    error_message = "Location must be a valid Azure region name in lowercase without spaces."
  }
}


variable "vnet_octet_min" {
  description = "Minimum value for VNet second octet (10.XXX.0.0/16)"
  type        = number
  default     = 101

  validation {
    condition     = var.vnet_octet_min >= 0 && var.vnet_octet_min <= 255
    error_message = "VNet octet minimum must be between 0 and 255."
  }
}

variable "vnet_octet_max" {
  description = "Maximum value for VNet second octet (10.XXX.0.0/16)"
  type        = number
  default     = 250

  validation {
    condition     = var.vnet_octet_max >= 0 && var.vnet_octet_max <= 255
    error_message = "VNet octet maximum must be between 0 and 255."
  }
}

variable "vnet_address_space_suffix" {
  description = "CIDR suffix for VNet address space"
  type        = number
  default     = 16

  validation {
    condition     = var.vnet_address_space_suffix >= 8 && var.vnet_address_space_suffix <= 29
    error_message = "VNet address space suffix must be between /8 and /29."
  }
}

variable "adbs_subnet_name" {
  description = "Name for the Oracle Autonomous Database subnet"
  type        = string
  default     = "adbs-subnet"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.adbs_subnet_name))
    error_message = "Subnet name must contain only lowercase letters, numbers, and hyphens."
  }
}


variable "adbs_subnet_prefix_length" {
  description = "CIDR prefix length for ADBS subnet"
  type        = number
  default     = 24

  validation {
    condition     = var.adbs_subnet_prefix_length >= 16 && var.adbs_subnet_prefix_length <= 29
    error_message = "ADBS subnet prefix length must be between /16 and /29."
  }
}

variable "oracle_delegation_name" {
  description = "Name for the Oracle Database delegation"
  type        = string
  default     = "oracle-delegation"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Test"
    Project     = "Oracle-ADB-AKV-PrivateEndpoint"
    ManagedBy   = "Terraform"
    Owner       = "Gerry"
  }
}

variable "enable_log_analytics_logging" {
  description = "Enable Log Analytics Workspace, Diagnostic Settings, and Workbook deployment. Set to false to disable Log Analytics integration."
  type        = bool
  default     = true
}

variable "enable_eventhub_logging" {
  description = "Enable Event Hub Namespace and Event Hub for diagnostic log streaming. When true, separate diagnostic settings are created to send logs to Event Hub."
  type        = bool
  default     = false
}

# Flag to control Managed HSM deployment and dependent resources
variable "deploy_managed_hsm" {
  description = "Enable deployment of Azure Key Vault Managed HSM and its related diagnostic settings and network configuration."
  type        = bool
  default     = false
}

variable "deploy_exascale" {
  description = "Deploy Oracle Exascale (Exascale Storage Vault + Cloud VM Cluster) instead of Autonomous Database Serverless. When true, ADBS will not be deployed."
  type        = bool
  default     = false
}

# Oracle Exascale Variables

variable "oracle_ssh_public_key" {
  description = "SSH public key for Oracle Exascale VM Cluster node access. Required when deploy_exascale = true. Example: file(\"~/.ssh/id_rsa.pub\")"
  type        = string
  default     = ""
  sensitive   = false

  validation {
    condition     = var.oracle_ssh_public_key == "" || can(regex("^ssh-", var.oracle_ssh_public_key))
    error_message = "oracle_ssh_public_key must be a valid SSH public key (starting with 'ssh-rsa', 'ssh-ed25519', etc.)."
  }
}

variable "exascale_storage_vault_config" {
  description = <<EXASCALE_VAULT_CONFIG
Configuration for the Oracle Exascale DB Storage Vault.

- `name`                - (Optional) Resource name; auto-generated if empty.
- `display_name`        - (Optional) Display name; auto-generated if empty.
- `availability_zone`   - (Required) Availability zone for the vault (e.g., "1", "2", "3").
- `storage_size_in_gbs` - (Required) Total storage in GiB (minimum 300 GiB per OCU allocated).
- `time_zone`           - (Optional) Oracle time zone for the vault (e.g., "UTC", "US/Eastern").
EXASCALE_VAULT_CONFIG

  type = object({
    name                = string
    display_name        = string
    availability_zone   = string
    storage_size_in_gbs = number
    time_zone           = string
  })

  default = {
    name                = ""
    display_name        = ""
    availability_zone   = "1"
    storage_size_in_gbs = 300
    time_zone           = "UTC"
  }

  validation {
    condition     = var.exascale_storage_vault_config.storage_size_in_gbs >= 300
    error_message = "Exascale storage size must be at least 300 GiB."
  }

  validation {
    condition     = contains(["1", "2", "3"], var.exascale_storage_vault_config.availability_zone)
    error_message = "Availability zone must be '1', '2', or '3'."
  }
}

variable "exascale_cluster_config" {
  description = <<EXASCALE_CLUSTER_CONFIG
Configuration for the Oracle Exascale Cloud VM Cluster (Oracle.Database/exadbVmClusters).

- `name`                          - (Optional) Resource name; auto-generated if empty.
- `display_name`                  - (Optional) Display name; auto-generated if empty.
- `hostname`                      - (Required) Hostname prefix for cluster nodes (max 12 characters).
- `cluster_name`                  - (Optional) Short cluster identifier used in Oracle (max 11 characters).
- `domain`                        - (Optional) DNS domain for the cluster.
- `enabled_ecpu_count`            - (Required) Number of ECPUs to enable on the cluster (min 0).
- `total_ecpu_count`              - (Required) Total ECPUs allocated to the cluster (min 2).
- `node_count`                    - (Required) Number of cluster nodes.
- `shape`                         - (Required) Oracle Exascale shape name (e.g., "Exadata.X11M").
- `vm_file_system_storage_in_gbs` - (Required) VM file system storage per cluster in GiB.
- `license_model`                 - (Optional) "LicenseIncluded" or "BringYourOwnLicense".
- `time_zone`                     - (Optional) Cluster time zone (e.g., "UTC", "US/Eastern").
- `diagnostics_events_enabled`    - (Optional) Collect Oracle diagnostic event telemetry.
- `health_monitoring_enabled`     - (Optional) Collect Oracle health monitoring telemetry.
- `incident_logs_enabled`         - (Optional) Collect Oracle incident log telemetry.
EXASCALE_CLUSTER_CONFIG

  type = object({
    name                          = string
    display_name                  = string
    hostname                      = string
    cluster_name                  = string
    domain                        = string
    enabled_ecpu_count            = number
    total_ecpu_count              = number
    node_count                    = number
    shape                         = string
    vm_file_system_storage_in_gbs = number
    license_model                 = string
    time_zone                     = string
    diagnostics_events_enabled    = bool
    health_monitoring_enabled     = bool
    incident_logs_enabled         = bool
  })

  default = {
    name                          = ""
    display_name                  = ""
    hostname                      = "exahost"
    cluster_name                  = "exacluster"
    domain                        = "cluster.local"
    enabled_ecpu_count            = 4
    total_ecpu_count              = 4
    node_count                    = 2
    shape                         = "Exadata.X11M"
    vm_file_system_storage_in_gbs = 180
    license_model                 = "LicenseIncluded"
    time_zone                     = "UTC"
    diagnostics_events_enabled    = true
    health_monitoring_enabled     = true
    incident_logs_enabled         = true
  }

  validation {
    condition     = var.exascale_cluster_config.total_ecpu_count >= 2
    error_message = "total_ecpu_count must be at least 2."
  }

  validation {
    condition     = var.exascale_cluster_config.enabled_ecpu_count <= var.exascale_cluster_config.total_ecpu_count
    error_message = "enabled_ecpu_count must not exceed total_ecpu_count."
  }

  validation {
    condition     = contains(["LicenseIncluded", "BringYourOwnLicense"], var.exascale_cluster_config.license_model)
    error_message = "license_model must be 'LicenseIncluded' or 'BringYourOwnLicense'."
  }

  validation {
    condition     = length(var.exascale_cluster_config.hostname) <= 12
    error_message = "hostname must be 12 characters or fewer."
  }

  validation {
    condition     = length(var.exascale_cluster_config.cluster_name) <= 11
    error_message = "cluster_name must be 11 characters or fewer."
  }
}

# Oracle Autonomous Database Variables

# Oracle Autonomous Database Configuration

variable "autonomous_database_config" {
  type = object({
    name                         = string
    display_name                 = string
    db_version                   = string
    workload                     = string
    compute_model                = string
    compute_count                = number
    storage_size_tbs             = number
    license_model                = string
    backup_retention_days        = number
    auto_scaling_enabled         = bool
    auto_scaling_storage_enabled = bool
    mtls_required                = bool
    character_set                = string
    national_character_set       = string
  })

  default = {
    name                         = ""
    display_name                 = ""
    db_version                   = "19c"
    workload                     = "OLTP"
    compute_model                = "ECPU"
    compute_count                = 2
    storage_size_tbs             = 1
    license_model                = "LicenseIncluded"
    backup_retention_days        = 60
    auto_scaling_enabled         = true
    auto_scaling_storage_enabled = false
    mtls_required                = false
    character_set                = "AL32UTF8"
    national_character_set       = "AL16UTF16"
  }

  description = <<AUTONOMOUS_DATABASE_CONFIG
Configuration for the Oracle Autonomous Database deployment.

- `display_name` - (Optional) The display name for the Autonomous Database instance, if not provided it will be auto-generated.
- `db_version` - (Required) The Oracle Database version. Allowed values: `19c`, `21c`, `23ai`.
- `workload` - (Required) The workload type for the database. Allowed values: `OLTP` (Transaction Processing), `DW` (Data Warehouse), `AJD` (JSON Database), `APEX` (Application Express).
- `compute_model` - (Required) The compute model to use. Allowed values: `ECPU` (Elastic CPU), `OCPU` (Oracle CPU).
- `compute_count` - (Required) The number of compute units to allocate. Must be between 1 and 512.
- `storage_size_tbs` - (Required) The storage size in terabytes. Must be between 1 and 384.
- `license_model` - (Required) The license model for the database. Allowed values: `LicenseIncluded`, `BringYourOwnLicense`.
- `backup_retention_days` - (Required) The number of days to retain automatic backups. Must be between 1 and 60.
- `auto_scaling_enabled` - (Required) Whether to enable automatic scaling of compute resources based on workload demand.
- `auto_scaling_storage_enabled` - (Required) Whether to enable automatic scaling of storage capacity.
- `mtls_required` - (Required) Whether mutual TLS (mTLS) authentication is required for database connections.
- `character_set` - (Required) The database character set (e.g., `AL32UTF8`).
- `national_character_set` - (Required) The national character set for NCHAR/NVARCHAR2 columns (e.g., `AL16UTF16`).
AUTONOMOUS_DATABASE_CONFIG



  validation {
    condition     = contains(["19c", "21c", "23ai"], var.autonomous_database_config.db_version)
    error_message = "Database version must be one of: 19c, 21c, 23ai."
  }

  validation {
    condition     = contains(["OLTP", "DW", "AJD", "APEX"], var.autonomous_database_config.workload)
    error_message = "Workload must be one of: OLTP, DW, AJD, APEX."
  }

  validation {
    condition     = contains(["ECPU", "OCPU"], var.autonomous_database_config.compute_model)
    error_message = "Compute model must be either ECPU or OCPU."
  }

  validation {
    condition     = var.autonomous_database_config.compute_count >= 1 && var.autonomous_database_config.compute_count <= 512
    error_message = "Compute count must be between 1 and 512."
  }

  validation {
    condition     = var.autonomous_database_config.storage_size_tbs >= 1 && var.autonomous_database_config.storage_size_tbs <= 384
    error_message = "Storage size must be between 1 and 384 TB."
  }

  validation {
    condition     = contains(["LicenseIncluded", "BringYourOwnLicense"], var.autonomous_database_config.license_model)
    error_message = "License model must be either LicenseIncluded or BringYourOwnLicense."
  }

  validation {
    condition     = var.autonomous_database_config.backup_retention_days >= 1 && var.autonomous_database_config.backup_retention_days <= 60
    error_message = "Backup retention must be between 1 and 60 days."
  }
}

variable "adbs_admin_password" {
  description = "Admin password for Autonomous Database (min 12 chars, must include uppercase, lowercase, number, and special char). If not provided, uses the default from autonomous_database_config."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.adbs_admin_password == null || (length(var.adbs_admin_password) >= 12 && length(var.adbs_admin_password) <= 30)
    error_message = "Admin password must be between 12 and 30 characters."
  }
}

# Windows Jumpbox VM Configuration

variable "jumpbox_config" {
  description = "Configuration block for Windows jumpbox VM"
  type = object({
    name             = string
    size             = string
    admin_username   = string
    enable_public_ip = bool
    os_disk_size_gb  = number
    os_disk_type     = string
  })

  default = {
    name             = "VM-DevBox"
    size             = "Standard_D2s_v3"
    admin_username   = "azureadmin"
    enable_public_ip = false
    os_disk_size_gb  = 127
    os_disk_type     = "Premium_LRS"
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.jumpbox_config.name))
    error_message = "VM name must contain only alphanumeric characters and hyphens."
  }

  validation {
    condition     = length(var.jumpbox_config.admin_username) >= 1 && length(var.jumpbox_config.admin_username) <= 20
    error_message = "Admin username must be between 1 and 20 characters."
  }
}
