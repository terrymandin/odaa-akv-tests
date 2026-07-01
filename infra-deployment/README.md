# Oracle Autonomous Database + Azure Key Vault Infrastructure

This Terraform configuration deploys the Azure infrastructure required for integrating Oracle Autonomous Database with Azure Key Vault over private endpoints.

## Recent Updates

- **ADBS Naming**: Auto-generated names use pattern `adbsakvtest{random}` when not specified
- **Managed HSM Output**: Added `managed_hsm` output with id, name, hsm_uri, resource_group, location
- **Variables Generation**: `autonomous_database_config` always included in generated tfvars
- **Private Endpoint IP**: Improved retrieval using multiple fallback methods

## Overview

This infrastructure automates the Azure resource deployment for Oracle ADBS with Key Vault integration, supporting both Azure Key Vault and Managed HSM.

**Reference Documentation**: See [Step-by-step.md](../Step-by-step.md) for the end-to-end implementation guide and [DOCUMENTATION_GUIDE.md](../DOCUMENTATION_GUIDE.md) for architecture details.

## Current Resources

**Core Infrastructure**:
- **Resource Group**: Container for all Azure resources (`rg-adbs-{location}-{suffix}`)
- **Virtual Network**: VNet with random address space (`10.{random}.0.0/16`)
- **Subnets**: 
  - ADBS Subnet (delegated to Oracle): `10.XXX.1.0/24`
  - Private Endpoints Subnet: `10.XXX.2.0/24`
  - NAT Gateway Subnet: `10.XXX.3.0/24`
  - VM Subnet: `10.XXX.4.0/24`
  - Azure Firewall Subnet: `10.XXX.5.0/26`

**Security & Key Management**:
- **Azure Key Vault**: Encryption key storage with private endpoint (always deployed)
- **Managed HSM**: FIPS 140-2 Level 3 hardware security module (optional, controlled by `.env`)
- **Private Endpoints**: For Key Vault and optionally Managed HSM
- **Private DNS Zones**: For privatelink.vaultcore.azure.net and privatelink.managedhsm.azure.net

**Networking**:
- **Azure Firewall**: Network security and filtering (Standard SKU with policy-based rules)
- **NAT Gateway**: Outbound internet connectivity for ADBS subnet
- **Route Tables**: Custom routes for firewall integration

**Compute**:
- **Windows Jumpbox VM**: Management access point (Windows Server 2022 with RDP)

**Monitoring** (optional):
- **Log Analytics Workspace**: Centralized logging
- **Event Hub**: Log streaming (optional)
- **Diagnostic Settings**: For all key resources
- **Azure Workbook**: Firewall denied traffic visualization

## Prerequisites



```### 1. Configure Admin Password

Virtual Network: 10.{XXX}.0.0/16

├── ADBS Subnet (10.{XXX}.1.0/24)The Autonomous Database requires an admin password. **IMPORTANT: Never commit passwords to git.**

│   ├── Oracle Database delegation

│   ├── Oracle Autonomous Database**Option A: Environment Variable (Recommended)**

│   └── NAT Gateway association```bash

├── Private Endpoints Subnet (10.{XXX}.2.0/24)export TF_VAR_adbs_admin_password="YourSecureP@ssw0rd123"

│   └── Key Vault Private Endpoint```

├── NAT Gateway Subnet (10.{XXX}.3.0/24)

│   └── NAT Gateway resource**Option B: terraform.tfvars (Use with caution)**

├── VM Subnet (10.{XXX}.4.0/24)```bash

│   └── Windows Jumpbox VMcp terraform.tfvars.example terraform.tfvars

└── AzureFirewallSubnet (10.{XXX}.5.0/26)# Edit terraform.tfvars and set adbs_admin_password

    └── Azure Firewall# Note: terraform.tfvars is gitignored

``````



### Security Features**Password Requirements:**

- 12-30 characters

- **Key Vault**: Public access automatically disabled post-deployment- Must include: uppercase, lowercase, number, special character

- **Private DNS**: Automatic DNS resolution for Key Vault via private endpoint- Cannot contain the username

- **Firewall Rules**: 23 application rules + 2 network rules for Oracle connectivity

- **Network Isolation**: All resources use private connectivity### 2. Initialize Terraform

- **NSG Protection**: Network security groups on jumpbox subnet

```bash

### Logging & Monitoring (Optional)cd infra-deployment/akv-scenario

terraform init

#### Log Analytics Integration```

- Log Analytics Workspace for centralized logging

- Diagnostic settings for Key Vault, VNet, Firewall, NSG### 3. Plan Deployment

- Azure Workbook for firewall denied traffic analysis

- Controlled by `enable_log_analytics_logging` variable```bash

terraform plan

#### Event Hub Integration```

- Event Hub Namespace for log streaming

- Separate diagnostic settings for real-time log exportReview the plan to ensure:

- Integration with external SIEM systems- Resource names follow expected pattern

- Controlled by `enable_eventhub_logging` variable- VNet address space is within 10.101-250.0.0/16

- ADBS subnet has Oracle delegation

## Prerequisites

### 4. Apply Configuration

### Azure Requirements

- Azure subscription with:```bash

  - Oracle Database@Azure service enabledterraform apply

  - "Advanced networking" feature enabled in UK South region```

  - Contributor or Owner role

- Azure CLI installed and authenticated (`az login`)### 5. Verify Deployment



### Tools```bash

- Terraform >= 1.9.0# Check database status

- jq (for JSON parsing in examples)terraform output -json autonomous_database | jq -r '.value.lifecycle_state'

- Azure CLI >= 2.50.0

# Get connection information (sensitive)

### Optionalterraform output -json autonomous_database

- HCP Terraform account (for remote state management)

# Access service console

## Quick Startterraform output -json autonomous_database | jq -r '.value.service_console_url'

```

### 1. Set Admin Password

### Destroy Resources

**Required**: The Autonomous Database requires an admin password.

```bash

```bashterraform destroy

export TF_VAR_adbs_admin_password="YourSecureP@ssw0rd123"```

```

## Configuration

**Password Requirements:**

- 12-30 characters### Variables

- Must include: uppercase, lowercase, number, special character

- Cannot contain the username#### Required



### 2. Initialize Terraform| Variable | Description | Example |

|----------|-------------|---------|

```bash| `adbs_admin_password` | Admin password for Autonomous Database | `SecureP@ssw0rd123` |

cd infra-deployment/akv-scenario

terraform init#### Optional - Resource Configuration

```

| Variable | Description | Default | Options |

### 3. Review and Apply|----------|-------------|---------|---------|

| `location` | Azure region for deployment | `uksouth` | Any Azure region |

```bash| `enable_logging` | Enable Log Analytics and monitoring | `true` | `true`, `false` |

# Review what will be created

terraform plan#### Optional - Logging and Monitoring



# Deploy infrastructure##### Log Analytics Logging

terraform apply

```The `enable_log_analytics_logging` variable controls the deployment of Log Analytics-based logging and monitoring infrastructure:



### 4. Verify Deployment**When `enable_log_analytics_logging = true` (default):**

- Log Analytics Workspace is deployed

```bash- Diagnostic Settings are configured for:

# Check database status  - Azure Key Vault

terraform output -json autonomous_database | jq -r '.value.db_workload'  - Virtual Network

  - Azure Firewall

# Get Key Vault information  - Network Security Groups

terraform output -json useful_info | jq -r '.value.akv_uri'- Azure Firewall Workbook for denied traffic monitoring is deployed



# Get jumpbox connection details**When `enable_log_analytics_logging = false`:**

terraform output -json useful_info | jq -r '.value.vm_fqdn'- Log Analytics Workspace is NOT deployed

```- No Log Analytics diagnostic settings are configured

- Workbook is NOT deployed

## Configuration Variables- Reduces monthly costs by eliminating Log Analytics infrastructure



### Required Variables**Cost Impact:**

- Log Analytics: Pay-per-GB ingested data (~$2.30/GB in UK South)

| Variable | Description | Example |- Diagnostic Settings: No additional cost

|----------|-------------|---------|- Workbook: No cost (visualization only)

| `adbs_admin_password` | Database admin password | Set via environment variable |

**Example: Disable Log Analytics logging:**

### Core Configuration```bash

export TF_VAR_enable_log_analytics_logging=false

| Variable | Description | Default | Options |terraform apply

|----------|-------------|---------|---------|```

| `location` | Azure region | `uksouth` | Any Azure region |

| `vnet_octet_min` | Min value for VNet second octet | `101` | 0-255 |##### Event Hub Logging

| `vnet_octet_max` | Max value for VNet second octet | `250` | 0-255 |

The `enable_eventhub_logging` variable controls the deployment of Event Hub for streaming diagnostic logs:

### Database Configuration

**When `enable_eventhub_logging = true`:**

Use the `autonomous_database_config` object to configure the database:- Event Hub Namespace (Standard SKU) is deployed

- Event Hub for diagnostic logs is created

| Parameter | Description | Default | Options |- Separate diagnostic settings are configured to stream logs to Event Hub for:

|-----------|-------------|---------|---------|  - Azure Key Vault

| `display_name` | Database display name | `autdbtestakv2` | Any string |  - Virtual Network

| `db_version` | Oracle version | `19c` | `19c`, `21c`, `23ai` |  - Azure Firewall

| `workload` | Workload type | `OLTP` | `OLTP`, `DW`, `AJD`, `APEX` |  - Network Security Groups

| `compute_model` | Compute type | `ECPU` | `ECPU`, `OCPU` |

| `compute_count` | Number of CPUs | `2` | 1-512 |**When `enable_eventhub_logging = false` (default):**

| `storage_size_tbs` | Storage in TB | `1` | 1-384 |- Event Hub infrastructure is NOT deployed

| `license_model` | License type | `LicenseIncluded` | `LicenseIncluded`, `BringYourOwnLicense` |- No Event Hub diagnostic settings are configured

| `backup_retention_days` | Backup retention | `60` | 1-60 |

| `auto_scaling_enabled` | CPU auto-scaling | `true` | `true`, `false` |**Cost Impact:**

| `auto_scaling_storage_enabled` | Storage auto-scaling | `false` | `true`, `false` |- Event Hub Standard: ~$0.015 per million events + ~$11/month base cost

| `mtls_required` | Require mTLS | `false` | `true`, `false` |- Throughput Units: ~$0.028/hour per unit

- Diagnostic Settings: No additional cost

### Jumpbox Configuration

**Use Cases:**

Use the `jumpbox_config` object:- Stream logs to external SIEM systems

- Real-time log processing and analytics

| Parameter | Description | Default |- Long-term log archival to storage accounts

|-----------|-------------|---------|- Integration with Azure Stream Analytics or Azure Functions

| `name` | VM name | `VM-DevBox` |

| `size` | VM size | `Standard_D2s_v3` |**Note:** Both `enable_log_analytics_logging` and `enable_eventhub_logging` can be enabled simultaneously to send logs to both destinations.

| `admin_username` | Admin username | `azureadmin` |

| `enable_public_ip` | Public IP | `false` |**Example: Enable Event Hub logging:**

| `os_disk_size_gb` | OS disk size | `127` |```bash

| `os_disk_type` | Disk type | `Premium_LRS` |export TF_VAR_enable_eventhub_logging=true

terraform apply

### Logging Configuration```



#### Log Analytics Logging#### Optional - Database Configuration



Control deployment of Log Analytics infrastructure:| Variable | Description | Default | Options |

|----------|-------------|---------|---------|

| Variable | Description | Default | Impact || `adbs_db_version` | Oracle Database version | `19c` | `19c`, `21c`, `23ai` |

|----------|-------------|---------|--------|| `adbs_workload` | Database workload type | `OLTP` | `OLTP`, `DW`, `AJD`, `APEX` |

| `enable_log_analytics_logging` | Enable Log Analytics | `true` | Workspace + diagnostics + workbook || `adbs_compute_model` | Compute model | `ECPU` | `ECPU`, `OCPU` |

| `adbs_compute_count` | Number of compute units | `2` | 1-512 |

**When enabled:**| `adbs_storage_size_tbs` | Storage size in TB | `1` | 1-384 |

- ✅ Log Analytics Workspace deployed| `adbs_license_model` | Oracle license model | `LicenseIncluded` | `LicenseIncluded`, `BringYourOwnLicense` |

- ✅ Diagnostic settings for Key Vault, VNet, Firewall, NSG

- ✅ Azure Firewall Workbook for denied traffic analysis#### Optional - Features



**When disabled:**| Variable | Description | Default |

- ❌ No Log Analytics resources|----------|-------------|---------|

- ❌ No diagnostic settings to Log Analytics| `adbs_auto_scaling_enabled` | Enable CPU auto-scaling | `false` |

- 💰 Reduces costs (~$2.30/GB in UK South)| `adbs_auto_scaling_storage_enabled` | Enable storage auto-scaling | `false` |

| `adbs_mtls_required` | Require mTLS connections | `false` |

**Example:**| `adbs_backup_retention_days` | Backup retention period | `7` |

```bash

export TF_VAR_enable_log_analytics_logging=falseSee `terraform.tfvars.example` for complete configuration options.

terraform apply

```### Outputs



#### Event Hub Logging| Output | Description |

|--------|-------------|

Control deployment of Event Hub for log streaming:| `random_values` | Random values used for naming |

| `resource_group` | Resource group details (id, name, location) |

| Variable | Description | Default | Impact || `virtual_network` | VNet details including address space |

|----------|-------------|---------|--------|| `adbs_subnet` | ADBS subnet details with delegation info |

| `enable_eventhub_logging` | Enable Event Hub | `false` | Namespace + hub + diagnostics || `autonomous_database` | Database details (connection strings, OCID, URLs) - **Sensitive** |



**When enabled:**## Example Deployments

- ✅ Event Hub Namespace (Standard SKU)

- ✅ Event Hub for diagnostic logs### Basic Deployment (Default Values)

- ✅ Separate diagnostic settings for all services

- ✅ Real-time log streaming capability```bash

export TF_VAR_adbs_admin_password="YourSecureP@ssw0rd123"

**When disabled:**terraform apply -auto-approve

- ❌ No Event Hub resources```

- 💰 No Event Hub costs

### Custom Configuration

**Cost**: ~$11/month base + $0.015 per million events

```bash

**Use cases:**# Set admin password

- Stream logs to external SIEM (Splunk, QRadar, etc.)export TF_VAR_adbs_admin_password="MySecureP@ss2024"

- Real-time analytics with Azure Stream Analytics

- Long-term archival to storage accounts# Deploy with custom compute and storage

- Custom log processing with Azure Functionsterraform apply \

  -var="owner_name=john" \

**Example:**  -var="adbs_compute_count=4" \

```bash  -var="adbs_storage_size_tbs=2" \

export TF_VAR_enable_eventhub_logging=true  -var="adbs_auto_scaling_enabled=true"

terraform apply```

```

### Production Deployment

**Note**: Both logging options can be enabled simultaneously to send logs to multiple destinations.

```bash

### Tags Configurationexport TF_VAR_adbs_admin_password="ProductionP@ssw0rd2024"



Customize resource tags via the `tags` variable:terraform apply \

  -var="adbs_db_version=23ai" \

```hcl  -var="adbs_compute_count=8" \

tags = {  -var="adbs_storage_size_tbs=5" \

  Environment = "Production"  -var="adbs_auto_scaling_enabled=true" \

  Project     = "Oracle-ADB-AKV-Integration"  -var="adbs_auto_scaling_storage_enabled=true" \

  ManagedBy   = "Terraform"  -var="adbs_mtls_required=true" \

  Owner       = "YourName"  -var="adbs_backup_retention_days=30" \

}  -var="adbs_license_model=BringYourOwnLicense"

``````



## Outputs## Network Architecture



### Available Outputs```

Azure Virtual Network: 10.XXX.0.0/16 (XXX = random 101-250)

| Output | Description | Sensitive |└── ADBS Subnet: 10.XXX.1.0/24

|--------|-------------|-----------|    └── Delegation: Oracle.Database/networkAttachments

| `random_values` | Random suffix and VNet octet values | No |        └── Oracle Autonomous Database (Private Connectivity)

| `resource_group` | Resource group details (id, name, location) | No |```

| `autonomous_database` | Database details and configuration | No |

| `useful_info` | Consolidated information for all resources | No |**Key Points:**

| `log_analytics_workspace` | Log Analytics details (if enabled) | No |- VNet address space is randomized to avoid conflicts

| `firewall_workbook` | Workbook details (if enabled) | No |- ADBS subnet is dedicated and delegated to Oracle

| `eventhub_namespace` | Event Hub namespace details (if enabled) | Yes |- Database has no public endpoint

| `eventhub_diagnostic_logs` | Event Hub details (if enabled) | No |- Access via VNet integration or Private Endpoint



### Accessing Outputs## Naming Convention



```bashResources follow the pattern: `<prefix>-<owner>-<location>-<random-suffix>`

# All outputs

terraform output- **Prefix**: Resource type abbreviation (e.g., `rg` for Resource Group)

- **Owner**: Owner identifier (default: `gerry`)

# Specific output in JSON- **Location**: Azure region short name (e.g., `uksouth`)

terraform output -json useful_info | jq- **Random Suffix**: 3-digit random number (100-999)



# Get Key Vault URIExamples:

terraform output -json useful_info | jq -r '.value.akv_uri'- Resource Group: `rg-gerry-uksouth-456`

- Virtual Network: `vnet-gerry-uksouth-456`

# Get VM RDP connection- Autonomous Database: `adb-gerry-uksouth-456`

terraform output -json useful_info | jq -r '.value.vm_fqdn'

## Post-Deployment Tasks

# Get firewall IP

terraform output -json useful_info | jq -r '.value.fw_public_ip_address'### 1. Verify Database Status

```

```bash

## Deployment Examples# Should return "Available"

terraform output -json autonomous_database | jq -r '.value.lifecycle_state'

### Basic Deployment (Development)```



```bash### 2. Access Service Console

export TF_VAR_adbs_admin_password="DevP@ssw0rd123"

terraform apply -auto-approve```bash

```# Get the URL

terraform output -json autonomous_database | jq -r '.value.service_console_url'

### Production Deployment (High Availability)# Open in browser

```

```bash

export TF_VAR_adbs_admin_password="ProdSecureP@ss2024!"### 3. Configure OCI Private DNS Zones



terraform apply \For Azure Key Vault integration, create these DNS zones in OCI:

  -var='autonomous_database_config={

    display_name="prod-oracle-db",1. `privatelink.vaultcore.azure.net`

    db_version="23ai",2. `vault.azure.net`

    compute_count=8,

    storage_size_tbs=5,See [Step-by-step.md § Section 3](../Step-by-step.md#3-oci-dns-configuration-manual) for detailed DNS setup.

    auto_scaling_enabled=true,

    auto_scaling_storage_enabled=true,### 4. Test Database Connectivity

    mtls_required=true,

    backup_retention_days=60,```sql

    license_model="BringYourOwnLicense"-- Connect using connection string

  }'sqlplus admin@<connection_string>

```

-- Verify TDE

### Cost-Optimized Deployment (Testing)SELECT * FROM V$ENCRYPTION_WALLET;

```

```bash

export TF_VAR_adbs_admin_password="TestP@ssw0rd123"## Next Steps

export TF_VAR_enable_log_analytics_logging=false

1. **Azure Key Vault Deployment** (Coming Next):

terraform apply \   - Deploy Azure Key Vault

  -var='autonomous_database_config={   - Configure Private Endpoint

    compute_count=2,   - Set up Private DNS zones

    storage_size_tbs=1,

    auto_scaling_enabled=false2. **DNS Configuration** (OCI Side - Manual):

  }'   - Create Private DNS zones in OCI

```   - Configure forwarders for Azure DNS

   - Test resolution

### Full Logging Deployment (Compliance)

3. **TDE Integration**:

```bash   - Configure database for external key management

export TF_VAR_adbs_admin_password="ComplianceP@ss2024!"   - Point to Azure Key Vault

export TF_VAR_enable_log_analytics_logging=true   - Restart database to apply TDE

export TF_VAR_enable_eventhub_logging=true

4. **Application Connectivity**:

terraform apply   - Use connection strings from outputs

```   - Configure connection pooling

   - Implement retry logic

## Post-Deployment Steps

Refer to [Step-by-step.md](../Step-by-step.md) for the complete integration guide.

### 1. Verify Resources

## Security Best Practices

```bash

# Check all resources in resource group1. **Password Management:**

az resource list \   - Use environment variables

  --resource-group $(terraform output -json resource_group | jq -r '.value.name') \   - Never commit to git

  --output table   - Rotate regularly



# Verify Key Vault public access is disabled2. **Network Security:**

az keyvault show \   - Database has no public endpoint

  --name $(terraform output -json useful_info | jq -r '.value.akv_name') \   - Access via private connectivity only

  --query "properties.publicNetworkAccess" \   - Configure NSGs as needed

  -o tsv

# Expected output: Disabled3. **Key Vault Security:**

```   - Public network access is automatically disabled after all configurations are complete

   - Key Vault is only accessible via Private Endpoint

### 2. Connect to Jumpbox VM   - This ensures zero-trust network access to encryption keys

   - The deployment temporarily enables public access during setup, then disables it using Azure CLI

```bash

# Get connection details4. **mTLS Configuration:**

terraform output -json useful_info | jq '{   - Set `adbs_mtls_required = true` for production

  vm_fqdn,   - Distribute client certificates securely

  vm_admin_username

}'5. **Backup & Recovery:**

   - Test restore procedures

# Connect via RDP   - Store backups securely

mstsc /v:$(terraform output -json useful_info | jq -r '.value.vm_fqdn')   - Monitor backup status

```

## Troubleshooting

### 3. Configure Oracle Private DNS (OCI Side)

### Database Not Available

For Key Vault integration, configure these DNS zones in Oracle Cloud Infrastructure:

```bash

1. `privatelink.vaultcore.azure.net`# Check state

2. `vault.azure.net`terraform output -json autonomous_database | jq -r '.value.lifecycle_state'



Refer to `../Step-by-step.md#3-oci-dns-configuration-manual` for detailed DNS configuration.

# View logs

az monitor activity-log list --resource-group rg-gerry-uksouth-XXX

### 4. Test Key Vault Connectivity```



From the jumpbox or a VM within the VNet:### Password Validation Errors



```powershellEnsure password meets all requirements:

# Test DNS resolution- 12-30 characters

Resolve-DnsName $(terraform output -json useful_info | jq -r '.value.akv_uri' | sed 's|https://||' | sed 's|/||')- Has uppercase, lowercase, number, special char

- Doesn't contain username

# Test connectivity (should resolve to private IP)

Test-NetConnection -ComputerName $(terraform output -json useful_info | jq -r '.value.akv_uri' | sed 's|https://||' | sed 's|/||') -Port 443### Connection Issues

```

1. Verify subnet delegation: `terraform output adbs_subnet`

### 5. Configure TDE with Azure Key Vault2. Check NSG rules

3. Validate Private Endpoint connectivity

1. Configure database for external key management

2. Point Oracle to Azure Key Vault using the private endpoint## State Management

3. Restart database to apply TDE configuration

By default, this configuration uses HCP Terraform for remote state management. To use local state:

See documentation for complete TDE configuration steps.

1. Remove the `cloud` block from `providers.tf`

## Security Best Practices2. Run `terraform init -migrate-state`



### 1. Password ManagementFor HCP Terraform:

- ✅ Always use environment variables for passwords

- ✅ Never commit passwords to version control1. Update `organization` in `providers.tf` with your organization name

- ✅ Rotate credentials regularly (every 90 days minimum)2. Create a workspace named `adb-akv-private-endpoint`

- ✅ Use Azure Key Vault for password storage in production3. Run `terraform login` to authenticate



### 2. Network Security## Support

- ✅ Database has no public endpoint (private connectivity only)

- ✅ Key Vault public access automatically disabled post-deploymentFor questions and detailed guidance:

- ✅ Firewall controls all outbound traffic from ADBS subnet
- **Architecture Guide**: `../DOCUMENTATION_GUIDE.md`

- ✅ NSGs protect jumpbox subnet- **AI Agent Instructions**: `../../.github/copilot-instructions.md`

- **Terraform Standards**: `../../.github/agents/terraform-agent.md`

### 3. Key Vault Security- **Oracle Database@Azure Docs**: [Official Documentation](https://docs.oracle.com/en/cloud/paas/database-on-azure/)

- ✅ Public network access automatically disabled after configuration

- ✅ Key Vault only accessible via Private Endpoint## Files in This Directory

- ✅ Zero-trust network access to encryption keys

- ✅ Soft delete with 7-day retention enabled- `main.tf` - Resource group, VNet, subnet

- ✅ Purge protection enabled- `adbs.tf` - Oracle Autonomous Database resource

- `variables.tf` - Input variable definitions

### 4. Database Security- `outputs.tf` - Output value definitions

- ✅ Enable mTLS for production: `mtls_required = true`- `providers.tf` - Provider and backend configuration

- ✅ Use customer-managed keys (BYOK) for TDE- `terraform.tfvars.example` - Example variable values

- ✅ Regular backup verification and testing- `README.md` - This file

- ✅ Monitor database activity logs

### 5. Access Management
- ✅ Use Azure RBAC for resource access control
- ✅ Implement just-in-time (JIT) access for VMs
- ✅ Use Azure Bastion instead of public IP (future enhancement)
- ✅ Audit all administrative actions

## Monitoring and Troubleshooting

### Check Database Status

```bash
# View database state
terraform output -json autonomous_database | jq -r '.value'

# Check via Azure CLI
az oracle autonomous-database show \
  --name $(terraform output -json autonomous_database | jq -r '.value.name') \
  --resource-group $(terraform output -json resource_group | jq -r '.value.name')
```

### Monitor Logs (if Log Analytics enabled)

```bash
# Get Log Analytics Workspace ID
terraform output -json log_analytics_workspace | jq -r '.value.workspace_id'

# Query firewall denied traffic
az monitor log-analytics query \
  --workspace $(terraform output -json log_analytics_workspace | jq -r '.value.workspace_id') \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallApplicationRule' | where msg_s contains 'Deny' | take 10"
```

### View Firewall Workbook (if enabled)

```bash
# Get workbook details
terraform output -json firewall_workbook | jq

# Access via Azure Portal
# Navigate to: Azure Monitor > Workbooks > [Your Workbook]
```

### Common Issues

#### Database Not Available

```bash
# Check lifecycle state
terraform output -json autonomous_database | jq -r '.value'

# View activity logs
az monitor activity-log list \
  --resource-group $(terraform output -json resource_group | jq -r '.value.name') \
  --max-events 20
```

#### Password Validation Errors

Ensure password meets requirements:
- 12-30 characters
- Uppercase + lowercase + number + special character
- Does not contain username

#### Key Vault Access Issues

```bash
# Verify public access is disabled
az keyvault show \
  --name $(terraform output -json useful_info | jq -r '.value.akv_name') \
  --query "properties.publicNetworkAccess"

# Check private endpoint
az network private-endpoint show \
  --name pe-keyvault-$(terraform output -json random_values | jq -r '.value.suffix') \
  --resource-group $(terraform output -json resource_group | jq -r '.value.name')
```

#### Firewall Blocking Traffic

```bash
# Check firewall logs
az monitor diagnostic-settings list \
  --resource $(terraform output -json useful_info | jq -r '.value.fw_public_ip_address')

# Review firewall rules
az network firewall policy show \
  --name fw-policy-$(terraform output -json random_values | jq -r '.value.suffix') \
  --resource-group $(terraform output -json resource_group | jq -r '.value.name')
```

## State Management

### Remote State (HCP Terraform)

By default, this configuration can use HCP Terraform for remote state:

1. Update `organization` in `providers.tf` with your HCP Terraform organization
2. Create a workspace named `adb-akv-private-endpoint`
3. Authenticate: `terraform login`
4. Initialize: `terraform init`

### Local State

To use local state instead:

1. Remove or comment out the `cloud` block in `providers.tf`
2. Run: `terraform init -migrate-state`

### State Security

- ✅ Contains sensitive data (passwords, keys)
- ✅ Use remote state with encryption
- ✅ Restrict access using RBAC
- ✅ Enable state locking

## Cost Estimation

### Approximate Monthly Costs (UK South, Pay-as-you-go)

| Resource | Configuration | Est. Cost/Month |
|----------|---------------|-----------------|
| Oracle Autonomous Database | 2 ECPUs, 1TB | ~$200-300 |
| Azure Key Vault | Standard, with keys | ~$5 |
| Azure Firewall | Standard SKU | ~$775 |
| NAT Gateway | Standard | ~$30 |
| Windows VM | Standard_D2s_v3 | ~$70 |
| Log Analytics (optional) | ~10GB/month | ~$25 |
| Event Hub (optional) | Standard, 1 TU | ~$15 |
| Networking | Data transfer | ~$10 |

**Total**: ~$1,100-1,200/month (with logging)

**Cost savings**:
- Disable Log Analytics: Save ~$25/month
- Use smaller VM: Save ~$40/month
- Disable Event Hub: Save ~$15/month

## File Structure

```
infra-deployment/akv-scenario/
├── main.tf                  # Core resources (RG, VNet, subnets)
├── adbs.tf                  # Oracle Autonomous Database
├── key_vault.tf             # Key Vault, private endpoint, access policies
├── firewall.tf              # Azure Firewall
├── firewall_policy.tf       # Firewall rules and policies
├── nat_gateway.tf           # NAT Gateway configuration
├── jumpbox_vm.tf            # Windows jumpbox VM
├── log_analytics.tf         # Log Analytics workspace and diagnostic settings
├── event_hub.tf             # Event Hub namespace and diagnostic settings
├── workbook.tf              # Azure Firewall monitoring workbook
├── variables.tf             # Input variable definitions
├── outputs.tf               # Output value definitions
├── providers.tf             # Provider and version configuration
├── locals.tf                # Local values and computed resources
├── terraform.tfvars.example # Example variable values
├── README.md                # This file
└── .terraform.lock.hcl      # Provider version lock file
```

## Additional Resources

- **Architecture Documentation**: `../DOCUMENTATION_GUIDE.md`
- **Oracle Database@Azure Docs**: [Official Documentation](https://docs.oracle.com/en/cloud/paas/database-on-azure/)
- **Azure Key Vault Docs**: [Official Documentation](https://learn.microsoft.com/azure/key-vault/)
- **Terraform Azure Provider**: [Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Support and Contributions

For issues, questions, or contributions:
1. Review the architecture documentation
2. Check Terraform validation: `terraform validate`
3. Review the troubleshooting section
4. Consult Azure and Oracle documentation

## Destroy Infrastructure

To remove all deployed resources:

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing: yes
```

**Warning**: This will permanently delete all resources, including:
- Oracle Autonomous Database (and all data)
- Azure Key Vault (soft-deleted, recoverable for 7 days)
- All networking components
- Virtual machines and disks
- Firewall and security rules

**Before destroying**:
- ✅ Export any critical data from the database
- ✅ Backup any keys or secrets from Key Vault
- ✅ Download firewall logs if needed for compliance

## License

This Terraform configuration is provided as-is for demonstration and testing purposes.
