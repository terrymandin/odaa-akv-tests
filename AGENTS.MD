# 🤖 AGENT KNOWLEDGE BASE - Oracle Data Guard Deployment System

## 📋 TABLE OF CONTENTS
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Script Structure](#script-structure)
4. [Configuration Files](#configuration-files)
5. [Deployment Modes](#deployment-modes)
6. [Command-Line Parameters](#command-line-parameters)
7. [Validation System](#validation-system)
8. [Execution Flow](#execution-flow)
9. [Library Modules](#library-modules)
10. [Terraform Integration](#terraform-integration)
11. [Ansible Integration](#ansible-integration)
12. [Error Handling](#error-handling)
13. [Best Practices](#best-practices)
14. [Troubleshooting](#troubleshooting)
15. [LLM Agent Guidelines](#llm-agent-guidelines)

---

## 🎯 OVERVIEW

### Purpose
This system deploys Oracle Database 19c with Data Guard on Azure using a modular, production-ready deployment orchestrator (`deploy-oracle-dg.sh`). It combines Infrastructure as Code (Terraform) with Configuration Management (Ansible) to create a fully automated, enterprise-grade Oracle deployment.

### Key Features
- **Modular Architecture**: Library-based design with separation of concerns
- **Multiple Deployment Modes**: Fresh, Terraform-only, Ansible-only, Destroy, Generate-tfvars
- **Comprehensive Validation**: Pre-flight checks, environment validation, resource verification
- **Error Recovery**: Retry mechanisms for corrupted Oracle binaries, cleanup on failure
- **JIT Access**: Automated Just-In-Time VM access configuration
- **Managed Identity**: Azure Managed Identity for secure Oracle binary access

### Technology Stack
- **Infrastructure**: Azure (VMs, VNet, NSG, Storage, JIT Policies)
- **IaC**: Terraform (modular design with AVM modules)
- **Configuration**: Ansible 2.15 (Oracle 19c installation, Data Guard setup)
- **Orchestration**: Bash (modular library system)
- **Security**: SSH RSA keys, Azure Managed Identity, JIT access

---

## 🏗️ ARCHITECTURE

### Component Overview
```
┌─────────────────────────────────────────────────────────────┐
│                  deploy-oracle-dg.sh                        │
│              (Main Orchestrator Script)                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ├──> Load Library Modules
                            │    ├── common.sh (logging, utilities)
                            │    ├── validation.sh (pre-checks)
                            │    ├── azure.sh (Azure operations)
                            │    ├── terraform.sh (IaC deployment)
                            │    ├── ssh.sh (key management)
                            │    └── ansible.sh (Oracle installation)
                            │
                            ├──> Validate Configuration (.env)
                            │
                            ├──> Deploy Infrastructure (Terraform)
                            │    └── Creates: VMs, VNet, NSG, Disks, JIT Policies
                            │
                            ├──> Configure JIT Access
                            │
                            └──> Install Oracle (Ansible)
                                 └── Installs: Oracle 19c + Data Guard
```

### Directory Structure
```
project/
├── deploy-oracle-dg.sh              # Main orchestrator
├── .env                              # Configuration (user-created)
├── .env.example                      # Configuration template
├── deploy/
│   └── lib/                          # Modular library functions
│       ├── common.sh                 # Logging, colors, utilities
│       ├── validation.sh             # Pre-checks, env validation
│       ├── azure.sh                  # Azure CLI operations
│       ├── terraform.sh              # Terraform workflows
│       ├── ssh.sh                    # SSH key management
│       ├── ansible.sh                # Ansible playbook execution
│       └── README.md                 # Library documentation
├── terraform/
│   └── data_guard/                   # Terraform configuration
│       ├── module.tf                 # Main module imports
│       ├── variables_global.tf       # Global variables
│       ├── variables_local.tf        # Local variables
│       ├── transform.tf              # Data transformations
│       ├── jit_rule.tf               # JIT policy definitions
│       ├── providers.tf              # Azure providers
│       ├── backend.tf                # State backend
│       └── terraform.tfvars          # Auto-generated variables
├── ansible/
│   └── bootstrap/
│       └── oracle/
│           ├── playbook_dg.yml       # Main Data Guard playbook
│           ├── playbook_redownload.yml # Binary retry playbook
│           ├── inventory_dg          # Auto-generated inventory
│           ├── ansible.cfg           # Ansible configuration
│           └── roles/                # Ansible roles
│               ├── common/           # OS preparation
│               ├── grid/             # Grid Infrastructure
│               ├── oracle19c/        # Oracle binaries
│               ├── dbca/             # Database creation
│               └── dataguard/        # Data Guard setup
└── certs/                            # HSM security domain certificates
```

---

## ⚙️ CONFIGURATION FILES

### `.env` File (Primary Configuration)

**Location**: `./OnPremSetup/.env`  
**Created from**: `.env.example`  
**Purpose**: Centralized configuration for all deployment parameters

#### Configuration Categories

##### 1. Azure Configuration (REQUIRED)
```bash
# Region where resources will be deployed
AZ_LOCATION=eastus

# Resource Group naming (mode-dependent):
# - fresh/terraform-only: Use AZ_RG_BASENAME (adds random suffix)
# - ansible-only: Use RESOURCE_GROUP_NAME (existing RG)
AZ_RG_BASENAME=oracle-onprem-01

# Optional: Subscription ID (uses default if not set)
AZURE_SUBSCRIPTION_ID=
```

##### 2. SSH Configuration (REQUIRED)
```bash
# Path to SSH private key (supports ~ expansion)
SSH_PRIVATE_KEY_FILE=~/.ssh/oracle_key

# SSH user for VM access
SSH_USER=oracle
```

##### 3. Pre-existing Azure Resources (REQUIRED)
```bash
# Resource Group containing Oracle binaries
SOFTWARE_RG=binaryresource

# Managed Identity name for binary access
USER_ASSIGNED_IDENTITY=oraclelza

# Optional: Storage account/container (falls back to group_vars)
STORAGE_ACCOUNT=oraclebinaries
STORAGE_CONTAINER=installation-files
```

##### 4. Oracle Database Configuration (REQUIRED)
```bash
# Database name (3-8 characters, alphanumeric)
ORCL_DB_NAME=ORCL

# VM names
VM_PRIMARY_NAME=vm-primary-0
VM_SECONDARY_NAME=vm-secondary-0
```

##### 5. Terraform Configuration (OPTIONAL)
```bash
# Terraform logging level
TF_LOG=INFO

# Working directory (usually not changed)
TERRAFORM_WORK_DIR=./terraform/data_guard

# Diagnostic settings (see technical_debt.md for known issues)
IS_DIAGNOSTIC_SETTINGS_ENABLED=true
DIAGNOSTIC_TARGET=Log_Analytics_Workspace

# Auto-approve (use with caution in production)
TERRAFORM_AUTO_APPROVE=false
```

##### 6. JIT Access Configuration (OPTIONAL)
```bash
# JIT access duration in hours
JIT_DURATION_HOURS=3
```

#### Variable Validation Rules

| Variable | Required For | Validation | Default |
|----------|-------------|------------|---------|
| `AZ_LOCATION` | All modes | Non-empty string | None |
| `AZ_RG_BASENAME` | fresh, terraform-only | Non-empty string | None |
| `RESOURCE_GROUP_NAME` | ansible-only | Existing RG in Azure | From Terraform state |
| `SSH_PRIVATE_KEY_FILE` | All modes | File exists, RSA key | None |
| `SSH_USER` | All modes except create-tfvars-only | Non-empty string | None |
| `SOFTWARE_RG` | All modes except destroy | Existing RG in Azure | None |
| `USER_ASSIGNED_IDENTITY` | All modes except destroy | Existing identity | None |
| `ORCL_DB_NAME` | All modes except destroy | 3-8 chars, alphanumeric | None |
| `VM_PRIMARY_NAME` | All modes except destroy | Non-empty string | None |
| `VM_SECONDARY_NAME` | All modes except destroy | Non-empty string | None |

### `terraform.tfvars` (Auto-Generated)

**Location**: `./terraform/data_guard/terraform.tfvars`  
**Generated by**: `deploy-oracle-dg.sh` (calls `terraform_create_tfvars`)  
**Purpose**: Terraform input variables

**CRITICAL**: This file is auto-generated by the script. DO NOT MANUALLY EDIT unless using `--create-tfvars-only` mode.

#### Example Generated Content
```hcl
resource_group_name           = "oracle-onprem-01-abc12345"
location                      = "eastus"
ssh_key_path                  = "/Users/user/.ssh/oracle_key"
vm_name_prefix_primary        = "vm-primary-0"
vm_name_prefix_secondary      = "vm-secondary-0"
admin_username                = "oracle"
oracle_database_name          = "ORCL"
software_resource_group       = "binaryresource"
user_assigned_identity_id     = "/subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/oraclelza"
```

**IMPORTANT**: `user_assigned_identity_id` must be the FULL Resource ID, not just the name. The script handles this conversion automatically.

### `ansible.cfg` Configuration

**Location**: `./ansible/bootstrap/oracle/ansible.cfg`  
**Purpose**: Ansible runtime configuration

```ini
[defaults]
host_key_checking = False
inventory = ./inventory_dg
retry_files_enabled = False
timeout = 30

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

### Ansible Inventory (Auto-Generated)

**Location**: `./ansible/bootstrap/oracle/inventory_dg`  
**Generated by**: `ansible_create_inventory_dg` function  
**Purpose**: Ansible host definitions

#### Example Generated Inventory
```ini
[dbasm]

[ora-x1]
vm-primary-0 ansible_host=20.1.2.3 ansible_ssh_private_key_file=/path/to/key ansible_user=oracle ansible_python_interpreter=/usr/bin/python3

[ora-x2]
vm-secondary-0 ansible_host=20.1.2.4 ansible_ssh_private_key_file=/path/to/key ansible_user=oracle ansible_python_interpreter=/usr/bin/python3

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

---

## 🚀 DEPLOYMENT MODES

### 1. Fresh Deployment (Default)
**Command**: `./deploy-oracle-dg.sh`

**Behavior**:
- Cleans all Terraform state files
- Generates new Resource Group with random suffix
- Deploys infrastructure via Terraform
- Configures JIT access
- Installs Oracle via Ansible

**Use Case**: New deployment from scratch

**Required Variables**: All except `RESOURCE_GROUP_NAME`

**Workflow**:
```
Clean State → Create tfvars → Terraform Init/Plan/Apply → 
Get VM IPs → Configure JIT → Run Ansible → Summary
```

### 2. Terraform-Only Mode
**Command**: `./deploy-oracle-dg.sh --only-terraform` or `-tf`

**Behavior**:
- Deploys infrastructure only
- Creates Terraform plan (`tfplan`)
- Skips Ansible installation
- Skips JIT access configuration

**Use Case**: 
- Testing infrastructure changes
- Manual Ansible execution later
- Incremental deployment

**Workflow**:
```
Create tfvars → Terraform Init/Validate/Plan → 
Save Plan → Display Next Steps
```

### 3. Ansible-Only Mode
**Command**: `./deploy-oracle-dg.sh --only-ansible` or `-oa`

**Behavior**:
- Skips Terraform deployment
- Uses existing infrastructure
- Retrieves `RESOURCE_GROUP_NAME` from Terraform state
- Configures JIT access
- Runs Ansible playbooks

**Use Case**:
- Re-run Oracle installation
- Fix Ansible configuration issues
- Update Oracle configuration

**Required Variables**: `RESOURCE_GROUP_NAME` (or Terraform state with outputs)

**Workflow**:
```
Get RG from Terraform → Get VM IPs → Configure JIT → 
Run Ansible → Summary
```

**IMPORTANT**: If `RESOURCE_GROUP_NAME` is not in `.env`, script attempts to extract it from Terraform outputs:
```bash
terraform output -json resource_group | jq -r '.name'
```

### 4. Create TFVars Only Mode
**Command**: `./deploy-oracle-dg.sh --create-tfvars-only` or `-tfv`

**Behavior**:
- Generates `terraform.tfvars` file only
- Exits without deployment
- Useful for manual Terraform execution

**Use Case**:
- Manual Terraform workflow
- Review variables before deployment
- CI/CD integration

**Workflow**:
```
Validate Config → Create tfvars → Exit
```

**Next Steps** (manual):
```bash
cd terraform/data_guard
terraform init
terraform plan
terraform apply
```

### 5. Destroy Mode
**Command**: `./deploy-oracle-dg.sh --destroy` or `-d`

**Behavior**:
- Destroys all Terraform-managed resources
- Removes Resource Group and all contents
- Cleans Terraform state files
- Requires explicit confirmation

**Use Case**: Complete cleanup of deployment

**Confirmation Required**: User must type `yes` to proceed

**Workflow**:
```
Check Terraform State → List Resources → Confirm → 
Terraform Destroy → Clean State Files
```

**Resources Destroyed**:
- Resource Group
- Virtual Machines
- Disks (OS + Data)
- VNet and Subnets
- NSG and Rules
- Public IPs
- JIT Policies
- Diagnostic Settings

---

## 🎛️ COMMAND-LINE PARAMETERS

### Syntax
```bash
./deploy-oracle-dg.sh [MODE] [OPTIONS]
```

### Available Parameters

| Parameter | Short | Description | Exit After |
|-----------|-------|-------------|-----------|
| _(none)_ | - | Fresh deployment | No |
| `--only-terraform` | `-tf` | Infrastructure only | Yes |
| `--only-ansible` | `-oa` | Configuration only | No |
| `--create-tfvars-only` | `-tfv` | Generate variables file | Yes |
| `--destroy` | `-d` | Destroy infrastructure | Yes |
| `--cleanup-on-failure` | - | Remove resources on error | No |
| `--help` | `-h` | Show help message | Yes |

### Parameter Details

#### `--only-terraform` / `-tf`
- Sets `DEPLOYMENT_MODE="terraform-only"`
- Skips Ansible execution
- Creates `tfplan` file for review
- Requires `AZ_RG_BASENAME` (not `RESOURCE_GROUP_NAME`)

#### `--only-ansible` / `-oa`
- Sets `DEPLOYMENT_MODE="ansible-only"`
- Assumes infrastructure exists
- Retrieves `RESOURCE_GROUP_NAME` from Terraform state if not in `.env`
- Configures JIT access before Ansible

#### `--create-tfvars-only` / `-tfv`
- Sets `DEPLOYMENT_MODE="create-tfvars-only"`
- Minimal validation (only Azure location, RG basename, SSH key)
- Generates `terraform.tfvars` and exits

#### `--destroy` / `-d`
- Sets `DEPLOYMENT_MODE="destroy"`
- Lists resources before deletion
- Requires user confirmation (`yes`)
- Cleans state files after successful destroy

#### `--cleanup-on-failure`
- Sets `CLEANUP_ON_FAILURE=true`
- Triggers resource cleanup if deployment fails
- **USE WITH CAUTION**: May remove partially working infrastructure

#### `--help` / `-h`
- Displays usage information
- Shows examples
- Exits immediately

### Examples

```bash
# Fresh deployment
./deploy-oracle-dg.sh

# Infrastructure only (review plan before applying)
./deploy-oracle-dg.sh -tf

# Re-run Ansible on existing infrastructure
./deploy-oracle-dg.sh -oa

# Generate tfvars for manual execution
./deploy-oracle-dg.sh -tfv

# Complete cleanup
./deploy-oracle-dg.sh --destroy

# Fresh deployment with cleanup on failure
./deploy-oracle-dg.sh --cleanup-on-failure
```

---

## ✅ VALIDATION SYSTEM

### Validation Phases

#### Phase 1: Command-Line Parsing
- **Location**: Lines 45-84 in `deploy-oracle-dg.sh`
- **Function**: Argument parsing loop
- **Validates**: Valid parameter combinations

#### Phase 2: Environment File
- **Function**: `validation_check_env_file`
- **Module**: `deploy/lib/validation.sh`
- **Validates**:
  - `.env` file exists
  - File is readable
- **Error Action**: Displays copy command from `.env.example`

#### Phase 3: Required Variables
- **Function**: `validation_check_required_vars`
- **Module**: `deploy/lib/validation.sh`
- **Mode-Dependent Validation**:

**For `ansible-only` mode**:
```bash
# Try to get RESOURCE_GROUP_NAME from Terraform first
RESOURCE_GROUP_NAME=$(terraform output -json resource_group | jq -r '.name')

# If not found, validate it's in .env
if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then
    validation_check_required_vars "${ENV_FILE}" "RESOURCE_GROUP_NAME"
fi

# Always validate these
validation_check_required_vars "${ENV_FILE}" \
    "AZ_LOCATION" "SSH_PRIVATE_KEY_FILE" \
    "VM_PRIMARY_NAME" "VM_SECONDARY_NAME" "SSH_USER" \
    "ORCL_DB_NAME" "SOFTWARE_RG" "USER_ASSIGNED_IDENTITY"
```

**For `fresh` / `terraform-only` mode**:
```bash
validation_check_required_vars "${ENV_FILE}" \
    "AZ_LOCATION" "AZ_RG_BASENAME" "SSH_PRIVATE_KEY_FILE" \
    "VM_PRIMARY_NAME" "VM_SECONDARY_NAME" "SSH_USER" \
    "ORCL_DB_NAME" "SOFTWARE_RG" "USER_ASSIGNED_IDENTITY"
```

**For `create-tfvars-only` mode**:
```bash
validation_check_required_vars "${ENV_FILE}" \
    "AZ_LOCATION" "AZ_RG_BASENAME" "SSH_PRIVATE_KEY_FILE"
```

#### Phase 4: Prerequisites Check
- **Function**: `validation_check_prerequisites`
- **Module**: `deploy/lib/validation.sh`
- **Validates Tool Presence**:
  - `az` (Azure CLI)
  - `terraform` (Terraform)
  - `ansible` (Ansible - skip for terraform-only mode)
  - `jq` (JSON processor)
  - `ssh-keygen` (SSH utilities)

**Behavior**:
- Checks if command exists using `command -v`
- Retrieves and displays version numbers
- Accumulates missing tools
- Exits with error if any tool missing

**Example Output**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 Checking Prerequisites
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Azure CLI: v2.55.0
✅ Terraform: v1.6.5
✅ Ansible: v2.15.8
✅ jq: v1.7
✅ All prerequisites are met
```

#### Phase 5: SSH Key Validation
- **Function**: `ssh_validate_key` + `ssh_validate_key_type`
- **Module**: `deploy/lib/ssh.sh`
- **Validates**:
  - Private key file exists
  - File has correct permissions (400 or 600)
  - Key type is RSA (not ED25519 or other)
  - Public key exists or can be generated

**Auto-Generation**:
```bash
# If .pub file missing, generate it
if [[ ! -f "${SSH_PRIVATE_KEY_FILE}.pub" ]]; then
    ssh-keygen -f "${SSH_PRIVATE_KEY_FILE}" -y > "${SSH_PRIVATE_KEY_FILE}.pub"
fi
```

#### Phase 6: Azure Authentication
- **Function**: `azure_login` + `azure_set_subscription`
- **Module**: `deploy/lib/azure.sh`
- **Validates**:
  - User is logged into Azure CLI
  - Subscription is accessible
  - User has permissions

#### Phase 7: Managed Identity Validation
- **Function**: Custom logic in main script
- **Validates**:
  - Managed Identity exists in `SOFTWARE_RG`
  - Can retrieve Resource ID
  - Resource ID format is correct

**Critical Validation**:
```bash
USER_ASSIGNED_IDENTITY_ID=$(az identity show \
    --name "${USER_ASSIGNED_IDENTITY}" \
    --resource-group "${SOFTWARE_RG}" \
    --query id \
    --output tsv)

# Fix case issue (resourcegroups → resourceGroups)
USER_ASSIGNED_IDENTITY_ID=$(echo "${USER_ASSIGNED_IDENTITY_ID}" | sed 's/resourcegroups/resourceGroups/g')

# Validate format
if [[ ! "$USER_ASSIGNED_IDENTITY_ID" =~ ^/subscriptions/.*/resourceGroups/.*/providers/Microsoft.ManagedIdentity/userAssignedIdentities/.* ]]; then
    print_error "Invalid Managed Identity Resource ID format"
    exit 1
fi
```

#### Phase 8: Terraform Validation
- **Function**: `terraform_validate`
- **Module**: `deploy/lib/terraform.sh`
- **Validates**:
  - Terraform configuration syntax
  - Module references
  - Variable definitions
  - Provider configuration

#### Phase 9: JIT Policy Validation
- **Function**: `azure_validate_jit_policies`
- **Module**: `deploy/lib/azure.sh`
- **Validates**:
  - JIT policies exist for both VMs
  - Policies are properly configured
  - Security Center is enabled

### Validation Error Handling

**Error Trap**:
```bash
error_handler() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    print_error "DEPLOYMENT FAILED"
    print_info "Location: Line ${line_number}"
    print_info "Exit Code: ${exit_code}"
    print_info "Command: ${command}"
    exit ${exit_code}
}

trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
```

**Error Exit Function**:
```bash
error_exit() {
    print_error "$1"
    exit 1
}
```

---

## 🔄 EXECUTION FLOW

### Complete Deployment Flow (Fresh Mode)

```
START
  │
  ├─> 1. INITIALIZATION
  │     ├─ Load library modules (common, validation, azure, terraform, ssh, ansible)
  │     ├─ Set error trap handler
  │     └─ Parse command-line arguments
  │
  ├─> 2. CONFIGURATION
  │     ├─ Load .env file
  │     ├─ Validate required variables (mode-dependent)
  │     └─ Check prerequisites (az, terraform, ansible, jq)
  │
  ├─> 3. SSH PREPARATION
  │     ├─ Expand SSH_PRIVATE_KEY_FILE path (~/ → full path)
  │     ├─ Validate SSH key (exists, type=RSA)
  │     ├─ Generate .pub file if missing
  │     └─ Create temporary SSH keys for Ansible
  │
  ├─> 4. AZURE AUTHENTICATION
  │     ├─ Check az login status
  │     ├─ Set active subscription
  │     └─ Verify permissions
  │
  ├─> 5. RESOURCE GROUP SETUP
  │     ├─ Generate random suffix (8 chars)
  │     ├─ Create RESOURCE_GROUP_NAME = ${AZ_RG_BASENAME}-${RANDOM_SUFFIX}
  │     └─ Display configuration summary
  │
  ├─> 6. MANAGED IDENTITY
  │     ├─ Retrieve Managed Identity Resource ID from Azure
  │     ├─ Fix case (resourcegroups → resourceGroups)
  │     ├─ Validate Resource ID format
  │     └─ Export USER_ASSIGNED_IDENTITY_ID
  │
  ├─> 7. TERRAFORM DEPLOYMENT
  │     ├─ Change to terraform/data_guard directory
  │     ├─ Clean previous state (fresh mode only)
  │     │   ├─ Remove .terraform/ directory
  │     │   ├─ Remove .terraform.lock.hcl
  │     │   ├─ Remove terraform.tfstate*
  │     │   └─ Remove terraform.tfvars
  │     ├─ Generate terraform.tfvars
  │     │   ├─ CRITICAL: Use USER_ASSIGNED_IDENTITY_ID (Resource ID)
  │     │   └─ Include all required variables
  │     ├─ terraform init
  │     ├─ terraform validate
  │     ├─ terraform plan -out=tfplan
  │     ├─ terraform apply tfplan (interactive approval)
  │     └─ terraform refresh
  │
  ├─> 8. VM INFORMATION RETRIEVAL
  │     ├─ Get Primary VM Public IP
  │     ├─ Get Secondary VM Public IP
  │     └─ Display SSH connection commands
  │
  ├─> 9. JIT ACCESS CONFIGURATION
  │     ├─ Get current public IP (get_public_ip)
  │     ├─ Calculate end time (current + JIT_DURATION_HOURS)
  │     ├─ Validate JIT policies exist
  │     ├─ Request JIT access for Primary VM
  │     │   ├─ Policy: JIT-SSH-Policy-primary
  │     │   ├─ Port: 22
  │     │   ├─ Source IP: ${CURRENT_IP}
  │     │   └─ Duration: ${JIT_DURATION_HOURS} hours
  │     └─ Request JIT access for Secondary VM
  │         ├─ Policy: JIT-SSH-Policy-secondary
  │         ├─ Port: 22
  │         ├─ Source IP: ${CURRENT_IP}
  │         └─ Duration: ${JIT_DURATION_HOURS} hours
  │
  ├─> 10. ANSIBLE PREPARATION
  │     ├─ Add VM host keys to ~/.ssh/known_hosts
  │     ├─ Create Ansible inventory (inventory_dg)
  │     │   ├─ [ora-x1] Primary VM
  │     │   ├─ [ora-x2] Secondary VM
  │     │   └─ Set ansible_ssh_common_args
  │     └─ Activate Ansible venv (.venv-ansible215)
  │
  ├─> 11. ORACLE INSTALLATION (ANSIBLE)
  │     ├─ Build extra_vars string:
  │     │   ├─ data_guard=yes
  │     │   ├─ vm_user_assigned_identity_id=${USER_ASSIGNED_IDENTITY_ID}
  │     │   ├─ storage_account=${STORAGE_ACCOUNT} (optional)
  │     │   └─ storage_container=${STORAGE_CONTAINER} (optional)
  │     ├─ Run playbook_dg.yml with retry logic:
  │     │   ├─ Attempt 1: Full installation
  │     │   ├─ Check for corrupted ZIP error
  │     │   ├─ If corrupted:
  │     │   │   ├─ Clean corrupted files on both VMs
  │     │   │   └─ Attempt 2: Re-download with playbook_redownload.yml
  │     │   └─ Log output to ansible_deployment.log
  │     └─ Deactivate Ansible venv
  │
  ├─> 12. CLEANUP
  │     ├─ Remove temporary SSH keys
  │     └─ Display completion message
  │
  └─> 13. DEPLOYMENT SUMMARY
        ├─ Display success banner
        ├─ Show deployment information:
        │   ├─ Resource Group
        │   ├─ Location
        │   ├─ Database Name
        │   ├─ Primary VM (name + IP)
        │   └─ Secondary VM (name + IP)
        ├─ Display SSH connection commands
        ├─ Show next steps:
        │   ├─ Connect via SSH
        │   ├─ Switch to oracle user
        │   ├─ Check database status
        │   └─ Review Data Guard status
        └─ Display documentation links

END (Exit Code: 0)
```

### Error Flow

```
ERROR DETECTED (via trap)
  │
  ├─> error_handler called
  │     ├─ Capture exit code
  │     ├─ Capture line number
  │     ├─ Capture failed command
  │     └─ Display formatted error
  │
  ├─> Check CLEANUP_ON_FAILURE flag
  │     ├─ If true: Run cleanup_corrupted_files
  │     └─ If false: Skip cleanup
  │
  └─> EXIT with original exit code
```

### Mode-Specific Flow Differences

#### Terraform-Only Mode (`-tf`)
```
Skip: Steps 9-11 (JIT, Ansible Preparation, Oracle Installation)
Exit After: Step 7 (Terraform Deployment)
Output: tfplan file for manual review
```

#### Ansible-Only Mode (`-oa`)
```
Skip: Step 7 (Terraform Deployment)
Modified Step 5: Get RESOURCE_GROUP_NAME from Terraform state or .env
Continue: Steps 8-13 (VM IPs, JIT, Ansible, Summary)
```

#### Create TFVars Only (`-tfv`)
```
Execute: Steps 1-6 (Init, Config, SSH, Azure, RG Setup, Managed Identity)
Skip: Steps 7-13
Exit After: Generate terraform.tfvars
```

#### Destroy Mode (`-d`)
```
Execute: Steps 1-4 (Init, Config, SSH, Azure)
Custom Flow:
  ├─ Check Terraform state exists
  ├─ List resources to destroy
  ├─ Display warning
  ├─ Request user confirmation
  ├─ terraform destroy -auto-approve
  ├─ Clean state files
  └─ Exit
```

---

## 📚 LIBRARY MODULES

### Module: `common.sh`

**Purpose**: Core utilities, logging, color output

#### Functions

##### `print_info(message)`
- Displays informational message with ℹ️ icon
- Color: Blue
- Usage: `print_info "Starting deployment..."`

##### `print_success(message)`
- Displays success message with ✅ icon
- Color: Green
- Usage: `print_success "Deployment completed"`

##### `print_warning(message)`
- Displays warning message with ⚠️ icon
- Color: Yellow
- Usage: `print_warning "Resource already exists"`

##### `print_error(message)`
- Displays error message with ❌ icon
- Color: Red
- Usage: `print_error "Deployment failed"`

##### `print_section(title)`
- Displays section header with decorative border
- Color: Magenta
- Usage: `print_section "Terraform Deployment"`

##### `print_kv(key, value)`
- Displays key-value pair with consistent formatting
- Usage: `print_kv "Resource Group" "${RESOURCE_GROUP_NAME}"`

##### `command_exists(command)`
- Checks if command is available in PATH
- Returns: 0 (exists) or 1 (not found)
- Usage: `if command_exists terraform; then ...`

##### `expand_path(path)`
- Expands ~/ to full home directory path
- Handles symlinks and relative paths
- Usage: `SSH_KEY=$(expand_path "${SSH_PRIVATE_KEY_FILE}")`

##### `get_public_ip()`
- Retrieves current public IP using ipinfo.io
- Returns: IP address string
- Usage: `CURRENT_IP=$(get_public_ip)`

##### `get_future_time(hours)`
- Calculates UTC time X hours in the future
- Format: ISO 8601
- Usage: `END_TIME=$(get_future_time 3)`

##### `error_exit(message)`
- Prints error and exits with code 1
- Usage: `error_exit "Configuration file not found"`

### Module: `validation.sh`

**Purpose**: Pre-flight checks, environment validation

#### Functions

##### `validation_check_prerequisites(tools...)`
- Validates all required tools are installed
- Displays version information
- Exits if any tool missing
- Usage: `validation_check_prerequisites az terraform ansible`

##### `validation_check_env_file(env_file)`
- Validates .env file exists and is readable
- Displays helpful error with copy command
- Usage: `validation_check_env_file "${SCRIPT_DIR}/.env"`

##### `validation_check_required_vars(env_file, vars...)`
- Sources env file
- Checks each variable is non-empty
- Accumulates missing variables
- Exits if any variable missing
- Usage: `validation_check_required_vars "${ENV_FILE}" "AZ_LOCATION" "SSH_KEY"`

##### `validation_check_variable_format(var_name, var_value, pattern, description)`
- Validates variable matches regex pattern
- Used for database names, VM names, etc.
- Usage: `validation_check_variable_format "ORCL_DB_NAME" "${ORCL_DB_NAME}" "^[a-zA-Z0-9]{3,8}$" "3-8 alphanumeric chars"`

### Module: `azure.sh`

**Purpose**: Azure CLI operations, resource management

#### Functions

##### `azure_login()`
- Checks if user is logged into Azure CLI
- Uses `az account show` to verify
- Prompts for login if needed
- Usage: `azure_login`

##### `azure_get_subscription_id()`
- Retrieves current subscription ID
- Returns: Subscription GUID
- Usage: `SUB_ID=$(azure_get_subscription_id)`

##### `azure_set_subscription(subscription_id)`
- Sets active Azure subscription
- Validates subscription is accessible
- Usage: `azure_set_subscription "${AZURE_SUBSCRIPTION_ID}"`

##### `azure_get_vm_public_ip(resource_group, vm_name, wait_for_ip)`
- Retrieves VM public IP address
- Optional retry logic if IP not ready
- Returns: IP address string
- Usage: `VM_IP=$(azure_get_vm_public_ip "${RG}" "${VM_NAME}" "true")`

##### `azure_validate_jit_policies(subscription, resource_group, location, policy1, policy2)`
- Validates JIT policies exist in Security Center
- Checks policy configuration
- Usage: `azure_validate_jit_policies "${SUB_ID}" "${RG}" "${LOCATION}" "JIT-SSH-Policy-primary" "JIT-SSH-Policy-secondary"`

##### `azure_request_jit_access(subscription, resource_group, location, policy_name, vm_id, source_ip, duration_hours)`
- Requests Just-In-Time VM access
- Configures port 22 (SSH) access
- Sets source IP restriction
- Sets time-based expiration
- Usage: `azure_request_jit_access "${SUB_ID}" "${RG}" "${LOCATION}" "JIT-SSH-Policy-primary" "${VM_ID}" "${CURRENT_IP}" "3"`

### Module: `terraform.sh`

**Purpose**: Terraform workflow automation

#### Functions

##### `terraform_init(tf_dir, upgrade)`
- Initializes Terraform working directory
- Downloads providers and modules
- Optional provider upgrade
- Usage: `terraform_init "${TF_DIR}" "false"`

##### `terraform_validate(tf_dir)`
- Validates Terraform configuration syntax
- Checks module references
- Usage: `terraform_validate "${TF_DIR}"`

##### `terraform_plan(tf_dir, plan_file)`
- Creates Terraform execution plan
- Saves to specified file
- Usage: `terraform_plan "${TF_DIR}" "tfplan"`

##### `terraform_apply(tf_dir, plan_file, auto_approve)`
- Applies Terraform configuration
- Optional auto-approve (use with caution)
- Usage: `terraform_apply "${TF_DIR}" "tfplan" "false"`

##### `terraform_refresh(tf_dir)`
- Refreshes Terraform state from real infrastructure
- Updates state file with current values
- Usage: `terraform_refresh "${TF_DIR}"`

##### `terraform_destroy(tf_dir, auto_approve)`
- Destroys all Terraform-managed resources
- Optional auto-approve
- Usage: `terraform_destroy "${TF_DIR}" "false"`

##### `terraform_create_tfvars(tf_dir, tfvars_file, vars...)`
- Generates terraform.tfvars file
- Reads variable values from environment
- Handles special cases (paths, Resource IDs)
- **CRITICAL**: Must receive `USER_ASSIGNED_IDENTITY_ID` (Resource ID), not `USER_ASSIGNED_IDENTITY` (name)
- Usage: `terraform_create_tfvars "${TF_DIR}" "terraform.tfvars" "RESOURCE_GROUP_NAME" "AZ_LOCATION" "USER_ASSIGNED_IDENTITY_ID"`

**Implementation Detail for `terraform_create_tfvars`**:
```bash
terraform_create_tfvars() {
    local tf_dir="$1"
    local tfvars_file="$2"
    shift 2
    local var_names=("$@")
    
    cat > "${tf_dir}/${tfvars_file}" <<EOF
resource_group_name           = "${RESOURCE_GROUP_NAME}"
location                      = "${AZ_LOCATION}"
ssh_key_path                  = "${SSH_PRIVATE_KEY_FILE}"
vm_name_prefix_primary        = "${VM_PRIMARY_NAME}"
vm_name_prefix_secondary      = "${VM_SECONDARY_NAME}"
admin_username                = "${SSH_USER}"
oracle_database_name          = "${ORCL_DB_NAME}"
software_resource_group       = "${SOFTWARE_RG}"
user_assigned_identity_id     = "${USER_ASSIGNED_IDENTITY_ID}"
EOF
}
```

### Module: `ssh.sh`

**Purpose**: SSH key management, validation

#### Functions

##### `ssh_validate_key(key_file)`
- Validates SSH private key file exists
- Checks file permissions (400 or 600)
- Corrects permissions if needed
- Usage: `ssh_validate_key "${SSH_PRIVATE_KEY_FILE}"`

##### `ssh_validate_key_type(key_file, expected_type)`
- Validates SSH key type (RSA, ED25519, etc.)
- Uses `ssh-keygen -l -f` to identify type
- Exits if type mismatch (Azure VMs require RSA)
- Usage: `ssh_validate_key_type "${SSH_KEY}" "RSA"`

##### `ssh_generate_public_key(private_key)`
- Generates .pub file from private key
- Uses `ssh-keygen -y`
- Usage: `ssh_generate_public_key "${SSH_PRIVATE_KEY_FILE}"`

##### `ssh_remove_temp_key(temp_key)`
- Removes temporary SSH key files
- Cleans both private and .pub files
- Usage: `ssh_remove_temp_key "${TEMP_SSH_KEY}"`

##### `ssh_display_commands(stage, key_file, user, primary_ip, secondary_ip)`
- Displays formatted SSH connection commands
- Shows commands for both VMs
- Includes context (pre-ansible, post-deployment, etc.)
- Usage: `ssh_display_commands "final" "${SSH_KEY}" "oracle" "${PRIMARY_IP}" "${SECONDARY_IP}"`

### Module: `ansible.sh`

**Purpose**: Ansible playbook execution, Oracle installation

#### Functions

##### `ansible_activate_venv(venv_path)`
- Activates Ansible virtual environment
- Falls back to system Ansible if venv missing
- Usage: `ansible_activate_venv "${SCRIPT_DIR}/.venv-ansible215"`

##### `ansible_deactivate_venv()`
- Deactivates current virtual environment
- Safe to call even if no venv active
- Usage: `ansible_deactivate_venv`

##### `ansible_create_inventory_dg(inventory_file, primary_name, primary_ip, secondary_name, secondary_ip, ssh_key, ssh_user)`
- Generates Ansible inventory for Data Guard
- Creates host groups: [ora-x1], [ora-x2]
- Configures SSH settings
- Usage: `ansible_create_inventory_dg "${INVENTORY}" "${VM1_NAME}" "${VM1_IP}" "${VM2_NAME}" "${VM2_IP}" "${SSH_KEY}" "oracle"`

##### `ansible_add_known_hosts(known_hosts_file, ip1, ip2)`
- Adds VM SSH host keys to known_hosts
- Uses ssh-keyscan
- Prevents host key verification prompts
- Usage: `ansible_add_known_hosts "${HOME}/.ssh/known_hosts" "${PRIMARY_IP}" "${SECONDARY_IP}"`

##### `ansible_run_with_retry(playbook, inventory, extra_vars, log_file, max_retries, error_check_func, cleanup_func, retry_playbook)`
- Executes Ansible playbook with retry logic
- Checks for specific errors (corrupted Oracle binaries)
- Runs cleanup function on error
- Retries with alternative playbook
- Logs all output
- Usage: `ansible_run_with_retry "${PLAYBOOK}" "${INVENTORY}" "data_guard=yes" "${LOG}" "1" "ansible_check_corrupted_zip_error" "cleanup_corrupted_files" "${RETRY_PLAYBOOK}"`

##### `ansible_check_corrupted_zip_error(log_file)`
- Parses Ansible log for corrupted ZIP errors
- Returns 0 if corruption detected, 1 otherwise
- Used by retry logic
- Usage: `if ansible_check_corrupted_zip_error "${LOG}"; then ...`

##### `ansible_clean_corrupted_oracle_files(ssh_key, user, ip1, ip2)`
- Connects to both VMs via SSH
- Removes corrupted Oracle binary files
- Prepares for re-download
- Usage: `ansible_clean_corrupted_oracle_files "${SSH_KEY}" "oracle" "${PRIMARY_IP}" "${SECONDARY_IP}"`

---

## 🏗️ TERRAFORM INTEGRATION

### Terraform Directory Structure
```
terraform/data_guard/
├── module.tf                    # Main module imports (AVM modules)
├── variables_global.tf          # Global variable definitions
├── variables_local.tf           # Local variable definitions
├── transform.tf                 # Data transformations
├── jit_rule.tf                  # JIT policy resources
├── providers.tf                 # Azure provider configuration
├── backend.tf                   # State backend configuration
├── outputs.tf                   # Output definitions
├── resources.telemetry.tf       # Telemetry resources
├── terraform.tfvars             # Auto-generated input values
└── terraform.tfstate            # State file (generated)
```

### Key Terraform Files

#### `module.tf` - Module Imports
Uses Azure Verified Modules (AVM) for production-grade infrastructure:

```hcl
module "common_infrastructure" {
  source = "../../terraform_units/modules/common_infrastructure"
  
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}

module "network" {
  source = "../../terraform_units/modules/network"
  
  resource_group_name = module.common_infrastructure.resource_group_name
  location            = var.location
  vnet_address_space  = ["10.0.0.0/16"]
  subnets             = local.subnets
}

module "compute" {
  source = "../../terraform_units/modules/compute"
  
  resource_group_name         = module.common_infrastructure.resource_group_name
  location                    = var.location
  vm_name_prefix_primary      = var.vm_name_prefix_primary
  vm_name_prefix_secondary    = var.vm_name_prefix_secondary
  admin_username              = var.admin_username
  ssh_key_path                = var.ssh_key_path
  user_assigned_identity_id   = var.user_assigned_identity_id
  subnet_id                   = module.network.subnet_ids["oracle"]
}

module "storage" {
  source = "../../terraform_units/modules/storage"
  
  resource_group_name = module.common_infrastructure.resource_group_name
  location            = var.location
  vm_ids              = module.compute.vm_ids
}
```

#### `variables_global.tf` - Input Variables
```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "user_assigned_identity_id" {
  description = "Resource ID of user-assigned managed identity"
  type        = string
  # Example: /subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/...
}

variable "vm_name_prefix_primary" {
  description = "Primary VM name"
  type        = string
}

variable "vm_name_prefix_secondary" {
  description = "Secondary VM name"
  type        = string
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
}

variable "oracle_database_name" {
  description = "Oracle database name (3-8 chars)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9]{3,8}$", var.oracle_database_name))
    error_message = "Database name must be 3-8 alphanumeric characters"
  }
}

variable "software_resource_group" {
  description = "Resource group containing Oracle binaries"
  type        = string
}
```

#### `transform.tf` - Data Transformations
```hcl
locals {
  # Generate random suffix for unique naming
  random_suffix = lower(random_string.suffix.result)
  
  # Common tags
  tags = {
    Environment = "Production"
    Project     = "Oracle Data Guard"
    ManagedBy   = "Terraform"
    DeployedOn  = timestamp()
  }
  
  # Subnet configuration
  subnets = {
    oracle = {
      address_prefixes = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
    management = {
      address_prefixes = ["10.0.2.0/24"]
    }
  }
  
  # VM configuration
  vm_size = "Standard_E4ds_v5"
  os_disk_size_gb = 100
  data_disk_sizes_gb = [512, 512, 512, 512]
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
```

#### `jit_rule.tf` - Just-In-Time Access
```hcl
resource "azurerm_security_center_jit_network_policy" "primary" {
  name                = "JIT-SSH-Policy-primary"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  virtual_machine_ids = [module.compute.primary_vm_id]
  
  port {
    number   = 22
    protocol = "TCP"
    max_duration = "PT3H"
    
    allowed_source_address_prefixes = ["0.0.0.0/0"]  # Restricted at request time
  }
}

resource "azurerm_security_center_jit_network_policy" "secondary" {
  name                = "JIT-SSH-Policy-secondary"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  virtual_machine_ids = [module.compute.secondary_vm_id]
  
  port {
    number   = 22
    protocol = "TCP"
    max_duration = "PT3H"
    
    allowed_source_address_prefixes = ["0.0.0.0/0"]
  }
}
```

#### `outputs.tf` - Output Values
```hcl
output "resource_group" {
  description = "Resource group information"
  value = {
    name     = var.resource_group_name
    location = var.location
    id       = module.common_infrastructure.resource_group_id
  }
}

output "primary_vm" {
  description = "Primary VM information"
  value = {
    name       = var.vm_name_prefix_primary
    id         = module.compute.primary_vm_id
    private_ip = module.compute.primary_vm_private_ip
    public_ip  = module.compute.primary_vm_public_ip
  }
}

output "secondary_vm" {
  description = "Secondary VM information"
  value = {
    name       = var.vm_name_prefix_secondary
    id         = module.compute.secondary_vm_id
    private_ip = module.compute.secondary_vm_private_ip
    public_ip  = module.compute.secondary_vm_public_ip
  }
}

output "network" {
  description = "Network information"
  value = {
    vnet_id    = module.network.vnet_id
    subnet_ids = module.network.subnet_ids
  }
}
```

### Terraform Workflow Integration

#### 1. Initialization
```bash
# Called by deploy-oracle-dg.sh
terraform_init() {
    local tf_dir="${1:-.}"
    cd "$tf_dir"
    terraform init -input=false
}
```

#### 2. Validation
```bash
terraform_validate() {
    local tf_dir="${1:-.}"
    cd "$tf_dir"
    terraform validate
}
```

#### 3. Planning
```bash
terraform_plan() {
    local tf_dir="${1:-.}"
    local plan_file="${2:-tfplan}"
    cd "$tf_dir"
    terraform plan -out="$plan_file"
}
```

#### 4. Applying
```bash
terraform_apply() {
    local tf_dir="${1:-.}"
    local plan_file="${2:-tfplan}"
    local auto_approve="${3:-false}"
    cd "$tf_dir"
    
    if [[ "$auto_approve" == "true" ]]; then
        terraform apply -auto-approve "$plan_file"
    else
        terraform apply "$plan_file"
    fi
}
```

#### 5. Destroying
```bash
terraform_destroy() {
    local tf_dir="${1:-.}"
    cd "$tf_dir"
    terraform destroy -auto-approve
}
```

### Resource Creation Flow

```
terraform init
  │
  ├─> Download Providers
  │     ├─ azurerm (Azure Resource Manager)
  │     ├─ random (Random string generator)
  │     └─ azapi (Azure API for advanced features)
  │
  ├─> Download Modules
  │     ├─ common_infrastructure (Resource Group, Log Analytics)
  │     ├─ network (VNet, Subnets, NSG)
  │     ├─ compute (VMs, Availability Set)
  │     └─ storage (Data Disks)
  │
terraform plan
  │
  ├─> Resource Graph
  │     ├─ Resource Group
  │     ├─ Virtual Network
  │     ├─ Network Security Group
  │     ├─ Public IPs (2x)
  │     ├─ Network Interfaces (2x)
  │     ├─ Availability Set
  │     ├─ Virtual Machines (2x)
  │     ├─ Managed Disks (8x data disks)
  │     ├─ JIT Policies (2x)
  │     ├─ Diagnostic Settings
  │     └─ Role Assignments
  │
terraform apply
  │
  ├─> Create Resources (in dependency order)
  │     ├─ 1. Resource Group
  │     ├─ 2. Virtual Network + Subnets
  │     ├─ 3. NSG + Rules
  │     ├─ 4. Public IPs
  │     ├─ 5. Network Interfaces
  │     ├─ 6. Availability Set
  │     ├─ 7. Virtual Machines
  │     ├─ 8. Managed Disks
  │     ├─ 9. Disk Attachments
  │     ├─ 10. JIT Policies
  │     └─ 11. Diagnostic Settings
  │
  └─> Save State (terraform.tfstate)
```

### Critical Terraform Gotchas

#### 1. Managed Identity Resource ID
**Problem**: Terraform requires FULL Resource ID, not just name

**Wrong**:
```hcl
user_assigned_identity_id = "oraclelza"  # ❌ NAME ONLY
```

**Correct**:
```hcl
user_assigned_identity_id = "/subscriptions/xxx/resourceGroups/binaryresource/providers/Microsoft.ManagedIdentity/userAssignedIdentities/oraclelza"  # ✅ FULL RESOURCE ID
```

**Script Handles This**:
```bash
# Script converts name to Resource ID automatically
USER_ASSIGNED_IDENTITY_ID=$(az identity show \
    --name "${USER_ASSIGNED_IDENTITY}" \
    --resource-group "${SOFTWARE_RG}" \
    --query id \
    --output tsv)

# Fix case issue
USER_ASSIGNED_IDENTITY_ID=$(echo "${USER_ASSIGNED_IDENTITY_ID}" | sed 's/resourcegroups/resourceGroups/g')
```

#### 2. SSH Key Path
**Problem**: Terraform needs path to .pub file

**Wrong**:
```hcl
ssh_key_path = "~/.ssh/oracle_key"  # ❌ PRIVATE KEY
```

**Correct**:
```hcl
ssh_key_path = "/Users/user/.ssh/oracle_key"  # ✅ FULL PATH
```

**Script Handles This**:
```bash
# Expand path
SSH_PRIVATE_KEY_FILE=$(expand_path "${SSH_PRIVATE_KEY_FILE}")

# Generate .pub if missing
if [[ ! -f "${SSH_PRIVATE_KEY_FILE}.pub" ]]; then
    ssh-keygen -f "${SSH_PRIVATE_KEY_FILE}" -y > "${SSH_PRIVATE_KEY_FILE}.pub"
fi
```

#### 3. State File Locking
**Problem**: Multiple simultaneous runs cause state conflicts

**Solution**: Use backend with locking (Azure Storage Account)
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatexxxxxx"
    container_name       = "tfstate"
    key                  = "oracle-dg.tfstate"
  }
}
```

#### 4. Resource Dependencies
**Problem**: Resources created in wrong order

**Solution**: Use implicit dependencies via references
```hcl
# Implicit dependency: NIC depends on Subnet
network_interface_ids = [module.network.nic_id]

# Explicit dependency (if needed)
depends_on = [module.common_infrastructure]
```

---

## 🔧 ANSIBLE INTEGRATION

### Ansible Directory Structure
```
ansible/bootstrap/oracle/
├── ansible.cfg                  # Ansible configuration
├── playbook_dg.yml              # Main Data Guard playbook
├── playbook_redownload.yml      # Binary re-download playbook (retry)
├── inventory_dg                 # Auto-generated inventory
├── group_vars/
│   └── all/
│       ├── main.yml             # Global variables
│       ├── storage.yml          # Storage account config
│       └── oracle.yml           # Oracle-specific config
└── roles/
    ├── common/                  # OS preparation
    │   └── tasks/
    │       ├── main.yml
    │       ├── packages.yml
    │       ├── users.yml
    │       └── limits.yml
    ├── grid/                    # Grid Infrastructure
    │   └── tasks/
    │       ├── main.yml
    │       ├── install.yml
    │       └── configure.yml
    ├── oracle19c/               # Oracle binaries
    │   └── tasks/
    │       ├── main.yml
    │       ├── download.yml     # Azure Blob download
    │       ├── extract.yml
    │       └── install.yml
    ├── dbca/                    # Database creation
    │   └── tasks/
    │       ├── main.yml
    │       ├── create_db.yml
    │       └── configure.yml
    └── dataguard/               # Data Guard setup
        └── tasks/
            ├── main.yml
            ├── configure_primary.yml
            ├── configure_standby.yml
            └── switchover.yml
```

### Main Playbook: `playbook_dg.yml`

```yaml
---
- name: Deploy Oracle 19c with Data Guard
  hosts: all
  become: yes
  gather_facts: yes
  
  vars:
    data_guard: yes
    vm_user_assigned_identity_id: "{{ vm_user_assigned_identity_id }}"
    storage_account: "{{ storage_account | default('oraclebinaries') }}"
    storage_container: "{{ storage_container | default('installation-files') }}"
  
  roles:
    - role: common
      tags: ['common', 'os']
      
    - role: oracle19c
      tags: ['oracle', 'binaries']
      
    - role: grid
      tags: ['grid', 'asm']
      when: inventory_hostname in groups['dbasm']
      
    - role: dbca
      tags: ['dbca', 'database']
      when: inventory_hostname in groups['ora-x1']  # Primary only
      
    - role: dataguard
      tags: ['dataguard', 'dg']
      when: data_guard | bool
```

### Retry Playbook: `playbook_redownload.yml`

```yaml
---
- name: Re-download Oracle Binaries (Retry)
  hosts: all
  become: yes
  gather_facts: yes
  
  vars:
    force_redownload: yes
    vm_user_assigned_identity_id: "{{ vm_user_assigned_identity_id }}"
  
  tasks:
    - name: Clean corrupted files
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /tmp/oracle_installers
        - /home/oracle/oracle_binaries
      
    - name: Re-download Oracle binaries
      include_role:
        name: oracle19c
        tasks_from: download.yml
```

### Ansible Configuration: `ansible.cfg`

```ini
[defaults]
inventory = ./inventory_dg
retry_files_enabled = False
host_key_checking = False
timeout = 30
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
```

### Group Variables: `group_vars/all/main.yml`

```yaml
---
# Oracle Installation Paths
oracle_base: /u01/app/oracle
oracle_home: "{{ oracle_base }}/product/19.0.0/dbhome_1"
oracle_inventory: /u01/app/oraInventory

# Oracle User/Group
oracle_user: oracle
oracle_group: oinstall
oracle_groups:
  - oinstall
  - dba
  - oper
  - backupdba
  - dgdba
  - kmdba

# Database Configuration
db_name: "{{ oracle_database_name | default('ORCL') }}"
db_unique_name_primary: "{{ db_name }}_PRIMARY"
db_unique_name_standby: "{{ db_name }}_STANDBY"
db_domain: "example.com"

# Data Guard Configuration
dg_broker_start: YES
log_archive_dest_state_2: ENABLE
log_archive_dest_2: "SERVICE={{ db_unique_name_standby }} LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME={{ db_unique_name_standby }}"

# Storage Configuration (Azure Managed Identity)
use_managed_identity: yes
managed_identity_id: "{{ vm_user_assigned_identity_id }}"
```

### Group Variables: `group_vars/all/storage.yml`

```yaml
---
# Azure Storage Account Configuration
storage_account_name: "{{ storage_account | default('oraclebinaries') }}"
storage_container_name: "{{ storage_container | default('installation-files') }}"

# Oracle Binary Files (in Azure Blob Storage)
oracle_binaries:
  - name: LINUX.X64_193000_db_home.zip
    size: 3121721979
    checksum: sha256:ba8329c757133da313ed3b6d7f86c5ac42cd9970a28bf2e6233f3235233aa8d8
  - name: LINUX.X64_193000_grid_home.zip
    size: 3059705302
    checksum: sha256:d668002664d9399cf61eb03c0d1e3687121fc890b1ddd50b35dcbe13c5307d2e
  - name: p6880880_190000_Linux-x86-64.zip  # OPatch
    size: 118382987
    checksum: sha256:...

# Download Configuration
download_path: /tmp/oracle_installers
extract_path: /home/oracle/oracle_binaries
download_timeout: 3600  # 1 hour
max_retries: 3
```

### Ansible Execution Flow

```
ansible-playbook playbook_dg.yml
  │
  ├─> PLAY: Deploy Oracle 19c with Data Guard
  │     ├─ Hosts: ora-x1, ora-x2
  │     ├─ Become: yes (sudo)
  │     └─ Gather Facts
  │
  ├─> ROLE: common (OS Preparation)
  │     ├─ Install packages (python3, unzip, libaio, etc.)
  │     ├─ Create oracle user and groups
  │     ├─ Configure kernel parameters
  │     ├─ Set resource limits
  │     └─ Configure firewall
  │
  ├─> ROLE: oracle19c (Oracle Binaries)
  │     ├─ Download binaries from Azure Blob Storage
  │     │   ├─ Use Managed Identity for authentication
  │     │   ├─ Download LINUX.X64_193000_db_home.zip
  │     │   ├─ Download LINUX.X64_193000_grid_home.zip
  │     │   └─ Download OPatch
  │     ├─ Verify checksums
  │     ├─ Extract archives
  │     │   ├─ Check ZIP integrity
  │     │   ├─ Extract to $ORACLE_HOME
  │     │   └─ Set permissions
  │     └─ Install Oracle software
  │         ├─ Run runInstaller in silent mode
  │         └─ Execute root.sh
  │
  ├─> ROLE: grid (Grid Infrastructure) - CONDITIONAL
  │     ├─ Only on hosts in [dbasm] group
  │     ├─ Install Grid Infrastructure
  │     ├─ Configure ASM disks
  │     └─ Start Grid services
  │
  ├─> ROLE: dbca (Database Creation) - PRIMARY ONLY
  │     ├─ Only on hosts in [ora-x1] group
  │     ├─ Create database using DBCA
  │     │   ├─ Database name: ORCL_PRIMARY
  │     │   ├─ Character set: AL32UTF8
  │     │   ├─ Archive log mode: ENABLED
  │     │   └─ Force logging: ENABLED
  │     ├─ Configure listener
  │     └─ Create sample schemas (optional)
  │
  └─> ROLE: dataguard (Data Guard Setup) - CONDITIONAL
        ├─ Only if data_guard=yes
        ├─ Configure Primary Database
        │   ├─ Enable ARCHIVELOG mode
        │   ├─ Enable FORCE LOGGING
        │   ├─ Configure LOG_ARCHIVE_DEST_2
        │   ├─ Configure standby redo logs
        │   └─ Create standby controlfile
        ├─ Configure Standby Database (ora-x2)
        │   ├─ Restore controlfile from primary
        │   ├─ Start in MOUNT mode
        │   ├─ Configure LOG_ARCHIVE_DEST_2
        │   └─ Start MRP (Managed Recovery Process)
        └─ Configure Data Guard Broker
            ├─ Enable broker on both databases
            ├─ Create configuration
            ├─ Add primary database
            ├─ Add standby database
            └─ Enable configuration
```

### Key Ansible Tasks

#### Oracle Binary Download (Using Managed Identity)

```yaml
- name: Download Oracle binaries from Azure Blob Storage
  shell: |
    # Get Azure access token using Managed Identity
    TOKEN=$(curl -s -H "Metadata: true" \
      "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/" \
      | jq -r '.access_token')
    
    # Download file using token
    curl -H "x-ms-version: 2019-12-12" \
         -H "Authorization: Bearer ${TOKEN}" \
         "https://{{ storage_account_name }}.blob.core.windows.net/{{ storage_container_name }}/{{ item.name }}" \
         -o "{{ download_path }}/{{ item.name }}"
  loop: "{{ oracle_binaries }}"
  args:
    creates: "{{ download_path }}/{{ item.name }}"
```

#### ZIP Integrity Check

```yaml
- name: Verify ZIP file integrity
  command: unzip -t "{{ download_path }}/{{ item.name }}"
  loop: "{{ oracle_binaries }}"
  register: zip_check
  failed_when: zip_check.rc != 0
  changed_when: false
```

#### Data Guard Configuration

```yaml
- name: Configure Data Guard on Primary
  become_user: oracle
  shell: |
    sqlplus / as sysdba <<EOF
    ALTER SYSTEM SET LOG_ARCHIVE_CONFIG='DG_CONFIG=({{ db_unique_name_primary }},{{ db_unique_name_standby }})' SCOPE=BOTH;
    ALTER SYSTEM SET LOG_ARCHIVE_DEST_2='SERVICE={{ db_unique_name_standby }} LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME={{ db_unique_name_standby }}' SCOPE=BOTH;
    ALTER SYSTEM SET LOG_ARCHIVE_DEST_STATE_2=ENABLE SCOPE=BOTH;
    ALTER SYSTEM SET FAL_SERVER='{{ db_unique_name_standby }}' SCOPE=BOTH;
    ALTER SYSTEM SET DB_FILE_NAME_CONVERT='{{ db_unique_name_standby }}','{{ db_unique_name_primary }}' SCOPE=SPFILE;
    ALTER SYSTEM SET LOG_FILE_NAME_CONVERT='{{ db_unique_name_standby }}','{{ db_unique_name_primary }}' SCOPE=SPFILE;
    ALTER SYSTEM SET STANDBY_FILE_MANAGEMENT=AUTO SCOPE=BOTH;
    EOF
  when: inventory_hostname in groups['ora-x1']
```

### Ansible Error Recovery

#### Corrupted ZIP Detection

```bash
ansible_check_corrupted_zip_error() {
    local log_file="$1"
    
    # Check for ZIP corruption errors
    if grep -q "End-of-central-directory signature not found" "$log_file"; then
        return 0  # Error found
    fi
    
    if grep -q "bad CRC" "$log_file"; then
        return 0  # Error found
    fi
    
    if grep -q "invalid compressed data" "$log_file"; then
        return 0  # Error found
    fi
    
    return 1  # No error
}
```

#### Cleanup Corrupted Files

```bash
ansible_clean_corrupted_oracle_files() {
    local ssh_key="$1"
    local user="$2"
    local ip1="$3"
    local ip2="$4"
    
    print_info "Cleaning corrupted files on Primary VM..."
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "${user}@${ip1}" \
        "sudo rm -rf /tmp/oracle_installers/* /home/oracle/oracle_binaries/*"
    
    print_info "Cleaning corrupted files on Secondary VM..."
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "${user}@${ip2}" \
        "sudo rm -rf /tmp/oracle_installers/* /home/oracle/oracle_binaries/*"
    
    print_success "Corrupted files cleaned on both VMs"
}
```

#### Retry Logic

```bash
ansible_run_with_retry() {
    local playbook="$1"
    local inventory="$2"
    local extra_vars="$3"
    local log_file="$4"
    local max_retries="${5:-1}"
    local error_check_func="$6"
    local cleanup_func="$7"
    local retry_playbook="${8:-$playbook}"
    
    local attempt=1
    
    while [[ $attempt -le $((max_retries + 1)) ]]; do
        print_info "Ansible execution attempt $attempt..."
        
        # Run Ansible
        if ansible-playbook "$playbook" \
            -i "$inventory" \
            -e "$extra_vars" \
            | tee -a "$log_file"; then
            print_success "Ansible completed successfully"
            return 0
        fi
        
        # Check for specific error
        if [[ -n "$error_check_func" ]] && $error_check_func "$log_file"; then
            print_warning "Detected corrupted Oracle binaries"
            
            # Run cleanup
            if [[ -n "$cleanup_func" ]]; then
                $cleanup_func
            fi
            
            # Retry with alternative playbook
            playbook="$retry_playbook"
            ((attempt++))
            continue
        fi
        
        # Non-recoverable error
        print_error "Ansible failed with non-recoverable error"
        return 1
    done
    
    print_error "Ansible failed after $max_retries retries"
    return 1
}
```

### Ansible Inventory Auto-Generation

```bash
ansible_create_inventory_dg() {
    local inventory_file="$1"
    local primary_name="$2"
    local primary_ip="$3"
    local secondary_name="$4"
    local secondary_ip="$5"
    local ssh_key="$6"
    local ssh_user="${7:-oracle}"
    
    cat > "$inventory_file" <<EOF
[dbasm]

[ora-x1]
${primary_name} ansible_host=${primary_ip} ansible_ssh_private_key_file=${ssh_key} ansible_user=${ssh_user} ansible_python_interpreter=/usr/bin/python3

[ora-x2]
${secondary_name} ansible_host=${secondary_ip} ansible_ssh_private_key_file=${ssh_key} ansible_user=${ssh_user} ansible_python_interpreter=/usr/bin/python3

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
}
```

### Extra Variables Passed to Ansible

```bash
# Build extra vars string
EXTRA_VARS="data_guard=yes vm_user_assigned_identity_id=${USER_ASSIGNED_IDENTITY_ID}"

# Optional: Add storage account/container
if [[ -n "${STORAGE_ACCOUNT:-}" ]]; then
    EXTRA_VARS="${EXTRA_VARS} storage_account=${STORAGE_ACCOUNT}"
fi

if [[ -n "${STORAGE_CONTAINER:-}" ]]; then
    EXTRA_VARS="${EXTRA_VARS} storage_container=${STORAGE_CONTAINER}"
fi

# Run Ansible
ansible-playbook playbook_dg.yml -i inventory_dg -e "${EXTRA_VARS}"
```

**CRITICAL**: `vm_user_assigned_identity_id` must be the FULL Resource ID (with `/subscriptions/.../resourceGroups/...`), not just the name.

---

## 🚨 ERROR HANDLING

### Error Handling Strategy

#### 1. Global Error Trap
```bash
set -euo pipefail

error_handler() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_error "DEPLOYMENT FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Location: Line ${line_number}"
    print_info "Exit Code: ${exit_code}"
    print_info "Command: ${command}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Cleanup if requested
    if [[ "${CLEANUP_ON_FAILURE:-false}" == "true" ]]; then
        print_warning "Cleanup enabled - removing resources..."
        # Add cleanup logic here
    fi
    
    exit ${exit_code}
}

trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
```

#### 2. Validation Errors
```bash
error_exit() {
    print_error "$1"
    print_info "Check logs for details"
    print_info "Review configuration in .env file"
    exit 1
}

# Usage
if [[ ! -f "$CONFIG_FILE" ]]; then
    error_exit "Configuration file not found: $CONFIG_FILE"
fi
```

#### 3. Azure CLI Errors
```bash
# Check Azure login
if ! az account show &>/dev/null; then
    print_error "Not logged into Azure"
    print_info "Run: az login"
    exit 1
fi

# Check subscription
if ! az account set --subscription "$SUBSCRIPTION_ID" &>/dev/null; then
    error_exit "Cannot access subscription: $SUBSCRIPTION_ID"
fi
```

#### 4. Terraform Errors
```bash
# Terraform init failure
if ! terraform init -input=false; then
    print_error "Terraform initialization failed"
    print_info "Check provider configuration"
    print_info "Check network connectivity"
    exit 1
fi

# Terraform plan failure
if ! terraform plan -out=tfplan; then
    print_error "Terraform plan failed"
    print_info "Review variable values in terraform.tfvars"
    print_info "Check Azure resource quotas"
    exit 1
fi

# Terraform apply failure
if ! terraform apply tfplan; then
    print_error "Terraform apply failed"
    print_info "Check Azure service health"
    print_info "Review Terraform error messages above"
    print_info "State file may be partially updated"
    exit 1
fi
```

#### 5. Ansible Errors
```bash
# SSH connectivity
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 -i "$SSH_KEY" "${USER}@${VM_IP}" exit; then
    print_error "Cannot connect to VM via SSH"
    print_info "Check JIT access is enabled"
    print_info "Check NSG rules allow SSH from your IP"
    print_info "Verify SSH key is correct"
    exit 1
fi

# Ansible playbook failure
if ! ansible-playbook "$PLAYBOOK" -i "$INVENTORY" -e "$EXTRA_VARS"; then
    print_error "Ansible playbook failed"
    print_info "Check ansible_deployment.log for details"
    print_info "Verify Oracle binaries are accessible"
    print_info "Check Managed Identity has Blob Reader role"
    exit 1
fi
```

### Specific Error Scenarios

#### Scenario 1: Corrupted Oracle ZIP Files

**Detection**:
```bash
ansible_check_corrupted_zip_error() {
    local log_file="$1"
    
    if grep -q "End-of-central-directory signature not found" "$log_file"; then
        return 0
    fi
    
    if grep -q "bad CRC" "$log_file"; then
        return 0
    fi
    
    return 1
}
```

**Recovery**:
```bash
if ansible_check_corrupted_zip_error "$LOG_FILE"; then
    print_warning "Corrupted ZIP detected - initiating recovery"
    
    # Clean files
    ansible_clean_corrupted_oracle_files "$SSH_KEY" "$USER" "$PRIMARY_IP" "$SECONDARY_IP"
    
    # Retry with re-download playbook
    ansible-playbook playbook_redownload.yml -i "$INVENTORY" -e "$EXTRA_VARS"
fi
```

#### Scenario 2: JIT Access Expired

**Detection**:
```bash
# SSH connection refused
ssh -i "$SSH_KEY" "${USER}@${VM_IP}" exit
if [[ $? -eq 255 ]]; then
    print_error "SSH connection refused - JIT access may be expired"
fi
```

**Recovery**:
```bash
print_info "Re-requesting JIT access..."
azure_request_jit_access "$SUB_ID" "$RG" "$LOCATION" "$POLICY" "$VM_ID" "$CURRENT_IP" "$DURATION"
sleep 60  # Wait for policy to activate
```

#### Scenario 3: Managed Identity Permission Denied

**Detection**:
```bash
# Ansible fails to download Oracle binaries
if grep -q "403 Forbidden" "$LOG_FILE"; then
    print_error "Managed Identity lacks permissions"
fi
```

**Recovery**:
```bash
print_info "Verifying Managed Identity role assignment..."

# Check role assignment
az role assignment list \
    --assignee "$IDENTITY_ID" \
    --resource-group "$SOFTWARE_RG" \
    --query "[?roleDefinitionName=='Storage Blob Data Reader']"

# If missing, prompt user
print_info "Assign role with:"
print_info "  az role assignment create \\"
print_info "    --assignee $IDENTITY_ID \\"
print_info "    --role 'Storage Blob Data Reader' \\"
print_info "    --resource-group $SOFTWARE_RG"
```

#### Scenario 4: Terraform State Conflict

**Detection**:
```bash
# Terraform plan shows unexpected changes
terraform plan | grep -q "Error acquiring the state lock"
```

**Recovery**:
```bash
print_warning "State lock detected"
print_info "Another deployment may be in progress"
print_info "If no other deployment is running:"
print_info "  terraform force-unlock <LOCK_ID>"
```

#### Scenario 5: Resource Quota Exceeded

**Detection**:
```bash
# Terraform apply fails with quota error
if terraform apply tfplan 2>&1 | grep -q "QuotaExceeded"; then
    print_error "Azure quota exceeded"
fi
```

**Recovery**:
```bash
print_info "Check current quota usage:"
print_info "  az vm list-usage --location $LOCATION --query \"[?name.value=='standardEDSv5Family']\" -o table"
print_info "Request quota increase in Azure Portal"
```

### Logging and Debugging

#### Terraform Logging
```bash
# Enable detailed Terraform logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform_debug.log

terraform apply tfplan
```

#### Ansible Logging
```bash
# Run Ansible with verbose output
ansible-playbook playbook_dg.yml -i inventory_dg -e "$EXTRA_VARS" -vvv | tee ansible_debug.log
```

#### Azure CLI Logging
```bash
# Enable Azure CLI debug logging
az configure --defaults "logging.enable_log_file=true"
az configure --defaults "logging.log_dir=/tmp/azure_logs"
```

---

## 💡 BEST PRACTICES

### For LLM Agents Working with This System

#### 1. Always Read Configuration First
```python
# Before making any changes:
1. Read .env file
2. Understand deployment mode
3. Verify required variables are set
4. Check prerequisites are installed
```

#### 2. Validate Before Executing
```python
# Never skip validation:
1. Validate .env file exists
2. Check all required tools (az, terraform, ansible)
3. Verify SSH key exists and is RSA type
4. Confirm Azure login is active
5. Verify Managed Identity exists
```

#### 3. Use Appropriate Deployment Mode
```python
# Choose correct mode:
- New deployment → Fresh mode (default)
- Infrastructure change → Terraform-only mode (-tf)
- Re-configure Oracle → Ansible-only mode (-oa)
- Manual execution → Create-tfvars-only (-tfv)
- Cleanup → Destroy mode (-d)
```

#### 4. Handle Errors Gracefully
```python
# Error handling:
1. Check exit codes
2. Read error messages carefully
3. Look for specific error patterns
4. Suggest recovery actions
5. Log errors for debugging
```

#### 5. Resource ID vs Name
```python
# CRITICAL DISTINCTION:

# Managed Identity NAME (short form):
USER_ASSIGNED_IDENTITY="oraclelza"

# Managed Identity RESOURCE ID (full form):
USER_ASSIGNED_IDENTITY_ID="/subscriptions/xxx/resourceGroups/yyy/providers/Microsoft.ManagedIdentity/userAssignedIdentities/oraclelza"

# Terraform requires RESOURCE ID, not NAME
# Script handles conversion automatically
```

#### 6. Path Expansion
```python
# Always use full paths:

# Wrong:
SSH_PRIVATE_KEY_FILE="~/. ssh/key"

# Correct:
SSH_PRIVATE_KEY_FILE=$(expand_path "~/.ssh/key")
```

#### 7. Mode-Specific Validation
```python
# Validate based on mode:

if mode == "ansible-only":
    # Try to get RESOURCE_GROUP_NAME from Terraform state
    # Fall back to .env if not found
    validate_vars(["RESOURCE_GROUP_NAME", "VM_PRIMARY_NAME", ...])
elif mode == "fresh" or mode == "terraform-only":
    # Requires AZ_RG_BASENAME (will create new RG)
    validate_vars(["AZ_RG_BASENAME", "VM_PRIMARY_NAME", ...])
elif mode == "create-tfvars-only":
    # Minimal validation
    validate_vars(["AZ_LOCATION", "AZ_RG_BASENAME", "SSH_KEY"])
```

#### 8. State Management
```python
# Fresh mode behavior:
1. Clean ALL Terraform state files
2. Remove .terraform directory
3. Remove terraform.tfvars
4. Start with clean slate

# Ansible-only mode behavior:
1. Keep existing Terraform state
2. Retrieve RESOURCE_GROUP_NAME from state
3. Get VM IPs from Azure
4. Re-run Ansible only
```

#### 9. JIT Access Timing
```python
# JIT access workflow:
1. Deploy infrastructure (Terraform)
2. Get VM public IPs
3. Request JIT access (BEFORE Ansible)
4. Wait 60 seconds for policy activation
5. Run Ansible

# JIT access duration:
- Default: 3 hours (JIT_DURATION_HOURS=3)
- Adjustable in .env file
- Automatically expires
```

#### 10. Ansible Extra Vars
```python
# Required extra vars:
EXTRA_VARS = "data_guard=yes vm_user_assigned_identity_id=${RESOURCE_ID}"

# Optional extra vars:
if STORAGE_ACCOUNT:
    EXTRA_VARS += " storage_account=${STORAGE_ACCOUNT}"

if STORAGE_CONTAINER:
    EXTRA_VARS += " storage_container=${STORAGE_CONTAINER}"

# NEVER pass short name to vm_user_assigned_identity_id
# Always use full Resource ID
```

### Deployment Best Practices

#### 1. Pre-Deployment Checklist
- [ ] .env file created and configured
- [ ] SSH key exists and is RSA type
- [ ] Azure CLI logged in
- [ ] Subscription has sufficient quota
- [ ] Managed Identity exists with Blob Reader role
- [ ] Software Resource Group contains Oracle binaries
- [ ] JIT access will be from current IP

#### 2. During Deployment
- [ ] Monitor Terraform output for errors
- [ ] Watch for quota warnings
- [ ] Check JIT access activation
- [ ] Monitor Ansible progress
- [ ] Watch for ZIP corruption errors

#### 3. Post-Deployment
- [ ] Verify both VMs are running
- [ ] Test SSH connectivity
- [ ] Check Oracle database status
- [ ] Verify Data Guard configuration
- [ ] Test switchover/failover
- [ ] Document any issues encountered

#### 4. Cleanup
- [ ] Remove temporary SSH keys
- [ ] Clean Ansible logs (optional)
- [ ] Save Terraform state backup
- [ ] Document deployment parameters
- [ ] Update documentation if needed

### Security Best Practices

#### 1. SSH Keys
- Use RSA keys (minimum 2048-bit)
- Never commit private keys to version control
- Use separate keys for different environments
- Rotate keys regularly
- Store keys securely (encrypted disk, key vault)

#### 2. Azure Credentials
- Use Azure CLI login (avoid hardcoded credentials)
- Use Managed Identities for VM-to-Azure communication
- Never store client secrets in .env file
- Use Azure Key Vault for sensitive data
- Enable MFA on Azure accounts

#### 3. JIT Access
- Use minimum required access duration
- Restrict source IP to current location only
- Audit JIT access logs regularly
- Disable JIT access when not needed
- Use Azure Bastion for production

#### 4. Network Security
- Keep NSG rules restrictive
- Use private endpoints for storage
- Enable Azure Firewall for production
- Implement network segmentation
- Monitor network traffic

### Performance Best Practices

#### 1. Terraform
- Use remote backend for state management
- Enable state locking
- Use workspaces for multiple environments
- Cache provider downloads
- Use `terraform fmt` before commits

#### 2. Ansible
- Use pipelining (enabled in ansible.cfg)
- Enable fact caching
- Use async tasks for long-running operations
- Minimize gather_facts calls
- Use --diff for debugging

#### 3. Oracle Installation
- Use Managed Identity for binary downloads (faster than SAS tokens)
- Enable parallel downloads (Ansible forks)
- Use local caching for re-runs
- Monitor disk I/O during installation
- Optimize ASM disk layout

---

## 🔍 TROUBLESHOOTING

### Common Issues and Solutions

#### Issue 1: "Managed Identity Resource ID format invalid"

**Symptom**:
```
❌ Invalid Managed Identity Resource ID format
Expected: /subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/...
Received: oraclelza
```

**Cause**: Script received short name instead of Resource ID

**Solution**:
```bash
# Check if identity exists
az identity show \
    --name oraclelza \
    --resource-group binaryresource \
    --query id \
    --output tsv

# Verify identity has correct permissions
az role assignment list \
    --assignee <identity_id> \
    --resource-group binaryresource
```

#### Issue 2: "SSH key type must be RSA"

**Symptom**:
```
❌ SSH key type must be RSA (Azure VMs requirement)
Current key type: ED25519
```

**Cause**: Using ED25519 or other non-RSA key type

**Solution**:
```bash
# Generate new RSA key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oracle_key -N ""

# Update .env file
SSH_PRIVATE_KEY_FILE=~/.ssh/oracle_key
```

#### Issue 3: "Terraform initialization failed"

**Symptom**:
```
❌ Terraform initialization failed
Error: Failed to query available provider packages
```

**Cause**: Network connectivity issue or provider registry unavailable

**Solution**:
```bash
# Clear Terraform cache
rm -rf .terraform .terraform.lock.hcl

# Re-initialize with upgrade
cd terraform/data_guard
terraform init -upgrade

# If behind proxy, set:
export HTTPS_PROXY=http://proxy.company.com:8080
```

#### Issue 4: "Ansible cannot connect to VMs"

**Symptom**:
```
UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh", "unreachable": true}
```

**Cause**: JIT access not enabled or expired

**Solution**:
```bash
# Check JIT access
az security jit-policy list \
    --resource-group oracle-onprem-01-abc12345 \
    --location eastus

# Re-request JIT access
./deploy-oracle-dg.sh --only-ansible

# Manual JIT request
az security jit-policy show \
    --name JIT-SSH-Policy-primary \
    --resource-group oracle-onprem-01-abc12345 \
    --location eastus
```

#### Issue 5: "Corrupted Oracle ZIP file"

**Symptom**:
```
FAILED! => {"msg": "End-of-central-directory signature not found"}
```

**Cause**: Incomplete download or network issue during binary download

**Solution**:
```bash
# Clean corrupted files (automatic in script)
# Or manually:
ssh -i ~/.ssh/oracle_key oracle@<vm_ip>
sudo rm -rf /tmp/oracle_installers/*
sudo rm -rf /home/oracle/oracle_binaries/*

# Re-run Ansible only
./deploy-oracle-dg.sh --only-ansible

# Script will automatically:
# 1. Detect corruption
# 2. Clean files
# 3. Re-download with playbook_redownload.yml
```

#### Issue 6: "Resource quota exceeded"

**Symptom**:
```
Error: creating Virtual Machine: compute.VirtualMachinesClient#CreateOrUpdate: Failure responding to request: StatusCode=409 -- Original Error: autorest/azure: Service returned an error. Status=<nil> Code="OperationNotAllowed" Message="Quota exceeded for this VM family"
```

**Cause**: Insufficient Azure quota for VM family

**Solution**:
```bash
# Check current quota
az vm list-usage \
    --location eastus \
    --query "[?name.value=='standardEDSv5Family']" \
    --output table

# Request quota increase
# Azure Portal → Subscriptions → Usage + quotas → Request increase
```

#### Issue 7: "Terraform state lock"

**Symptom**:
```
Error: Error acquiring the state lock

Error message: state blob is already locked
Lock Info:
  ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Path: tfstate
  Operation: OperationTypeApply
  Who: user@hostname
  Version: 1.6.5
  Created: 2024-01-15 10:30:00
```

**Cause**: Previous Terraform run did not release lock

**Solution**:
```bash
# Check if another deployment is running
ps aux | grep terraform

# If no deployment running, force unlock
cd terraform/data_guard
terraform force-unlock xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Verify lock released
terraform plan
```

#### Issue 8: "Data Guard configuration failed"

**Symptom**:
```
DGMGRL> show configuration
ORA-16532: Data Guard broker configuration does not exist
```

**Cause**: Data Guard broker not properly configured

**Solution**:
```bash
# SSH to primary VM
ssh -i ~/.ssh/oracle_key oracle@<primary_ip>

# Check Data Guard status
sudo su - oracle
dgmgrl /

DGMGRL> show configuration

# If configuration missing, re-run Data Guard role
cd /path/to/ansible
ansible-playbook playbook_dg.yml \
    -i inventory_dg \
    -e "data_guard=yes" \
    --tags dataguard
```

### Debugging Commands

#### Terraform Debugging
```bash
# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform_debug.log

# Show current state
terraform show

# List resources
terraform state list

# Show specific resource
terraform state show azurerm_linux_virtual_machine.primary

# Refresh state
terraform refresh
```

#### Ansible Debugging
```bash
# Run with maximum verbosity
ansible-playbook playbook_dg.yml -i inventory_dg -vvvv

# Check connectivity
ansible all -i inventory_dg -m ping

# Run specific task
ansible-playbook playbook_dg.yml -i inventory_dg --tags oracle --step

# Gather facts
ansible all -i inventory_dg -m setup
```

#### Azure Debugging
```bash
# Check login
az account show

# List subscriptions
az account list --output table

# List VMs
az vm list \
    --resource-group oracle-onprem-01-abc12345 \
    --output table

# Get VM IP
az vm show \
    --resource-group oracle-onprem-01-abc12345 \
    --name vm-primary-0 \
    --show-details \
    --query publicIps \
    --output tsv

# Check NSG rules
az network nsg rule list \
    --resource-group oracle-onprem-01-abc12345 \
    --nsg-name oracle-nsg \
    --output table

# Check JIT policies
az security jit-policy list \
    --resource-group oracle-onprem-01-abc12345 \
    --location eastus
```

#### Oracle Debugging
```bash
# SSH to VM
ssh -i ~/.ssh/oracle_key oracle@<vm_ip>

# Switch to oracle user
sudo su - oracle

# Check database status
sqlplus / as sysdba
SELECT status FROM v$instance;
SELECT open_mode FROM v$database;

# Check Data Guard status
dgmgrl /
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE orcl_primary;
SHOW DATABASE VERBOSE orcl_standby;

# Check listener
lsnrctl status

# Check alert log
tail -100 $ORACLE_BASE/diag/rdbms/orcl_primary/ORCL/trace/alert_ORCL.log

# Check archive logs
SELECT dest_id, status, destination FROM v$archive_dest WHERE dest_id <= 2;
```

---

## 📖 LLM AGENT GUIDELINES

### How LLM Agents Should Use This Document

#### 1. Understanding User Intent

When a user asks to deploy Oracle Database:

```
User: "I want to deploy Oracle Data Guard on Azure"

Agent Analysis:
1. Identify deployment type: Fresh deployment
2. Required mode: Default (fresh)
3. Check if .env exists
4. Verify prerequisites
5. Execute deployment
```

#### 2. Troubleshooting User Issues

When a user reports an error:

```
User: "Deployment failed with 'SSH connection refused'"

Agent Analysis:
1. Identify error category: Connectivity issue
2. Likely cause: JIT access expired or not configured
3. Solution: Re-run deployment with --only-ansible
4. Verification: Check JIT policy status
```

#### 3. Modifying Deployment

When a user wants to change configuration:

```
User: "I want to change the database name"

Agent Analysis:
1. Identify affected component: Oracle configuration
2. Files to modify: .env (ORCL_DB_NAME)
3. Deployment mode needed: Fresh (to recreate database)
4. Warning: Existing data will be lost
5. Confirmation required: Yes
```

#### 4. Explaining Components

When a user asks about system components:

```
User: "How does the script handle Oracle binary downloads?"

Agent Response:
1. Reference: Ansible Integration section
2. Explain: Managed Identity authentication
3. Describe: Azure Blob Storage integration
4. Detail: Retry mechanism for corrupted files
5. Provide: Code examples from ansible.sh
```

#### 5. Suggesting Improvements

When suggesting code improvements:

```
Agent Guidelines:
1. Maintain modular structure (don't merge libraries)
2. Follow existing naming conventions
3. Add logging for new functions
4. Include error handling
5. Update this AGENTS.MD document
6. Add validation for new parameters
```

### Agent Response Templates

#### Template 1: Deployment Request
```
I'll help you deploy Oracle Data Guard on Azure. Let me check your configuration:

1. ✅ Checking prerequisites
   - Azure CLI: Installed
   - Terraform: Installed
   - Ansible: Installed

2. ✅ Validating .env file
   - Location: eastus
   - SSH Key: ~/.ssh/oracle_key
   - Database Name: ORCL

3. 🚀 Starting deployment
   - Mode: Fresh deployment
   - Estimated time: 30-60 minutes
   
Executing: ./deploy-oracle-dg.sh

[Monitor deployment progress...]
```

#### Template 2: Troubleshooting
```
I see you're experiencing [ERROR]. Let me help:

Root Cause:
[Explanation based on error pattern]

Solution:
1. [Step 1]
2. [Step 2]
3. [Step 3]

If this doesn't resolve the issue, we can:
- Check [component] logs
- Verify [configuration]
- Re-run [command]

Would you like me to proceed with the solution?
```

#### Template 3: Configuration Change
```
To change [PARAMETER], here's what we need to do:

Current Value: [current]
New Value: [new]

Impact:
- [Impact 1]
- [Impact 2]

Required Actions:
1. Update .env file: [parameter]=[value]
2. Re-run deployment: ./deploy-oracle-dg.sh [mode]

⚠️  Warning: [Any data loss or downtime warnings]

Shall I proceed with the change?
```

### Agent Decision Tree

```
User Request Received
  │
  ├─ Is it a deployment request?
  │   ├─ Yes → Check .env → Validate → Execute deployment
  │   └─ No → Continue
  │
  ├─ Is it an error report?
  │   ├─ Yes → Identify error → Suggest solution → Execute fix
  │   └─ No → Continue
  │
  ├─ Is it a configuration question?
  │   ├─ Yes → Reference AGENTS.MD → Explain → Provide examples
  │   └─ No → Continue
  │
  ├─ Is it a modification request?
  │   ├─ Yes → Assess impact → Confirm → Execute change
  │   └─ No → Continue
  │
  └─ Is it a learning question?
      ├─ Yes → Reference docs → Explain concepts → Provide examples
      └─ No → Ask for clarification
```

### Agent Knowledge Base Sections

For quick reference, agents should know:

1. **Configuration**: Section 4 - Configuration Files
2. **Deployment Modes**: Section 5 - Deployment Modes
3. **Command Syntax**: Section 6 - Command-Line Parameters
4. **Validation**: Section 7 - Validation System
5. **Execution Flow**: Section 8 - Execution Flow
6. **Libraries**: Section 9 - Library Modules
7. **Terraform**: Section 10 - Terraform Integration
8. **Ansible**: Section 11 - Ansible Integration
9. **Errors**: Section 12 - Error Handling
10. **Best Practices**: Section 13 - Best Practices
11. **Troubleshooting**: Section 14 - Troubleshooting

### Agent Self-Check Questions

Before responding to users, agents should ask:

1. Do I understand the user's intent?
2. What deployment mode is appropriate?
3. What files need to be read/modified?
4. What are the risks/impacts?
5. What validation is needed?
6. What is the expected outcome?
7. How will I verify success?
8. What could go wrong?
9. What is the rollback plan?
10. Is user confirmation needed?

---

## 📚 RELATED DOCUMENTATION

### Internal Documentation
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [README.md](README.md) - Project overview and quickstart
- [MACOS_QUICKSTART.md](MACOS_QUICKSTART.md) - macOS-specific instructions
- [technical_debt.md](technical_debt.md) - Known issues and workarounds

### Project Documentation
- [Step-by-step.md](Step-by-step.md) - End-to-end implementation guide
- [DOCUMENTATION_GUIDE.md](DOCUMENTATION_GUIDE.md) - Architecture and configuration reference
- [lessons-learned-adbs.md](lessons-learned-adbs.md) - Lessons learned and gotchas

### Library Documentation
- [deploy/lib/README.md](deploy/lib/README.md) - Library modules overview

### Terraform Documentation
- [terraform/data_guard/README.md](terraform/data_guard/README.md) - Terraform module documentation
- [terraform/data_guard/variables.md](terraform/data_guard/variables.md) - Variable reference
- [terraform_units/AVM_MODULES.md](terraform_units/AVM_MODULES.md) - Azure Verified Modules guide

---

## 🔄 VERSION HISTORY

### Version 1.0.0 (2026-02-02)
- Initial documentation
- Complete coverage of deploy-oracle-dg.sh
- Modular library system documentation
- Terraform and Ansible integration guides
- Comprehensive troubleshooting section
- LLM agent guidelines

---

## 📝 DOCUMENT MAINTENANCE

### For LLM Agents Updating This Document

When making changes to the codebase that affect this document:

1. **Update Relevant Sections**: Modify only affected sections
2. **Maintain Structure**: Keep existing section numbering
3. **Add Examples**: Include code examples for new features
4. **Update Flow Diagrams**: Reflect changes in execution flow
5. **Test Examples**: Verify all code examples work
6. **Version History**: Add entry to Version History section
7. **Cross-Reference**: Update related documentation links
8. **Validation**: Ensure document is still accurate

### Document Organization Principles

1. **Top-Down Structure**: General → Specific
2. **Practical Focus**: Emphasis on how-to, not just what-is
3. **Code Examples**: Real, working code snippets
4. **Error Scenarios**: Real errors with real solutions
5. **Agent-Friendly**: Designed for LLM consumption and generation

---

## 🎓 LEARNING RESOURCES

### For New LLM Agents

If you're a new LLM agent working with this system:

1. **Start Here**: Read Overview and Architecture sections
2. **Understand Config**: Study Configuration Files section
3. **Learn Modes**: Master Deployment Modes section
4. **Practice**: Try explaining common scenarios
5. **Troubleshoot**: Review Troubleshooting section
6. **Experiment**: Use Agent Guidelines for decision-making

### Key Concepts to Master

1. **Modular Design**: How libraries work together
2. **Mode Selection**: When to use each deployment mode
3. **Resource IDs**: Difference between name and Resource ID
4. **Error Recovery**: How retry mechanisms work
5. **State Management**: Terraform state handling
6. **JIT Access**: Timing and configuration
7. **Managed Identity**: Authentication flow

---

## 🚀 QUICK REFERENCE CARD

### Most Common Operations

```bash
# Fresh deployment
./deploy-oracle-dg.sh

# Infrastructure only
./deploy-oracle-dg.sh -tf

# Re-run Oracle installation
./deploy-oracle-dg.sh -oa

# Generate tfvars for manual execution
./deploy-oracle-dg.sh -tfv

# Destroy everything
./deploy-oracle-dg.sh -d

# Get help
./deploy-oracle-dg.sh --help
```

### Most Common Troubleshooting

```bash
# Check prerequisites
az --version
terraform version
ansible --version

# Verify Azure login
az account show

# Check Managed Identity
az identity show --name oraclelza --resource-group binaryresource

# Test SSH connectivity
ssh -i ~/.ssh/oracle_key oracle@<vm_ip>

# Check JIT access
az security jit-policy list --resource-group <rg> --location <location>

# View Terraform state
cd terraform/data_guard && terraform show

# Check Ansible logs
tail -f ansible_deployment.log
```

---

**END OF DOCUMENT**

*This document is designed for consumption by Large Language Models (LLMs) to assist with Oracle Database Data Guard deployment on Azure. For human-readable documentation, see README.md and DEPLOYMENT_GUIDE.md.*
