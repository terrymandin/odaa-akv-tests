#!/usr/bin/env bash
# ============================================================================
# Oracle Autonomous Database + Azure Key Vault Deployment Orchestrator
# ============================================================================
# Purpose: Deploy Oracle ADBS with Azure Key Vault using Terraform
# Version: 1.0.0
# Date: 2026-02-02
# ============================================================================

set -euo pipefail

# ============================================================================
# Script Directory and Library Loading
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/deploy/lib"

# Load library modules
if [[ ! -d "${LIB_DIR}" ]]; then
    echo "❌ Error: Library directory not found: ${LIB_DIR}"
    exit 1
fi

source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/validation.sh"
source "${LIB_DIR}/azure.sh"
source "${LIB_DIR}/terraform.sh"
source "${LIB_DIR}/config-hsm.sh"

# ============================================================================
# Global Variables
# ============================================================================

DEPLOYMENT_MODE="fresh"
VAULT_TYPE=""  # Can be 'keyvault', 'managedhsm', or empty (use .env)
DEPLOY_EXASCALE=""  # Overrides DEPLOY_EXASCALE from .env when set
CLEANUP_ON_FAILURE=false
ENV_FILE="${SCRIPT_DIR}/.env"
TERRAFORM_WORK_DIR="${SCRIPT_DIR}/infra-deployment"

# ============================================================================
# Error Handler
# ============================================================================

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
    
    if [[ "${CLEANUP_ON_FAILURE}" == "true" ]]; then
        print_warning "Cleanup on failure is enabled"
        print_info "Run with --destroy to clean up resources"
    fi
    
    exit "${exit_code}"
}

trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

# ============================================================================
# Usage and Help
# ============================================================================

usage() {
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Oracle Autonomous Database + Azure Key Vault Deployment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Usage: $(basename "$0") [MODE] [OPTIONS]

DEPLOYMENT MODES:
  (default)              Fresh deployment (uses DEPLOY_MANAGED_HSM from .env)
  -akv, --key-vault      Fresh deployment with Azure Key Vault + ADBS
  -hsm, --managed-hsm    Fresh deployment with Managed HSM + ADBS
  -exascale              Fresh deployment with Azure Key Vault + Oracle Exascale
  --only-configure-hsm   Configure Managed HSM only (requires deployed infra)
  --only-terraform, -tf  Infrastructure only (plan without apply)
  --create-tfvars, -tfv  Generate terraform.tfvars only
  --destroy, -d          Destroy all infrastructure
  --help, -h             Show this help message

OPTIONS:
  --cleanup-on-failure   Remove resources if deployment fails
  --auto-approve         Skip Terraform confirmation prompts

EXAMPLES:
  # Fresh deployment (uses .env DEPLOY_MANAGED_HSM setting)
  ./deploy-adbs-demo.sh

  # Fresh deployment with Azure Key Vault + ADBS
  ./deploy-adbs-demo.sh -akv

  # Fresh deployment with Managed HSM + ADBS
  ./deploy-adbs-demo.sh -hsm

  # Fresh deployment with Azure Key Vault + Oracle Exascale
  ./deploy-adbs-demo.sh -exascale

  # Infrastructure only (review plan)
  ./deploy-adbs-demo.sh --only-terraform

  # Configure Managed HSM only
  ./deploy-adbs-demo.sh --only-configure-hsm

  # Generate tfvars for manual execution
  ./deploy-adbs-demo.sh --create-tfvars

  # Destroy infrastructure
  ./deploy-adbs-demo.sh --destroy

CONFIGURATION:
  1. Copy .env.example to .env
  2. Edit .env with your configuration
  3. Run the deployment script

REQUIRED VARIABLES (.env):
  - AZ_LOCATION: Azure region
  - ADBS_ADMIN_PASSWORD: Database admin password

OPTIONAL VARIABLES:
  - AZURE_SUBSCRIPTION_ID: Azure subscription
  - ADBS_DISPLAY_NAME: Database display name (ADBS mode)
  - ENABLE_LOG_ANALYTICS: Enable Log Analytics (true/false)
  - DEPLOY_MANAGED_HSM: Deploy Managed HSM (true/false)
  - DEPLOY_EXASCALE: Deploy Oracle Exascale instead of ADBS (true/false)
  - ORACLE_SSH_PUBLIC_KEY: SSH public key for Exascale VM Cluster (required for Exascale)

For more information, see .env.example

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# ============================================================================
# Command-Line Argument Parsing
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -akv|--key-vault)
                DEPLOYMENT_MODE="fresh"
                VAULT_TYPE="keyvault"
                shift
                ;;
            -hsm|--managed-hsm)
                DEPLOYMENT_MODE="fresh"
                VAULT_TYPE="managedhsm"
                shift
                ;;
            -exascale|--exascale)
                DEPLOYMENT_MODE="fresh"
                VAULT_TYPE="keyvault"
                DEPLOY_EXASCALE="true"
                shift
                ;;
            --only-configure-hsm)
                DEPLOYMENT_MODE="configure-hsm-only"
                shift
                ;;
            --only-terraform|-tf)
                DEPLOYMENT_MODE="terraform-only"
                shift
                ;;
            --create-tfvars|-tfv)
                DEPLOYMENT_MODE="create-tfvars-only"
                shift
                ;;
            --destroy|-d)
                DEPLOYMENT_MODE="destroy"
                shift
                ;;
            --cleanup-on-failure)
                CLEANUP_ON_FAILURE=true
                shift
                ;;
            --auto-approve)
                export TERRAFORM_AUTO_APPROVE=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate vault type parameters are not both specified
    if [[ -n "${VAULT_TYPE}" ]]; then
        # Check if user specified both (should not happen with current logic, but safeguard)
        local akv_count=0
        local hsm_count=0
        for arg in "$@"; do
            [[ "$arg" == "-akv" || "$arg" == "--key-vault" ]] && ((akv_count++))
            [[ "$arg" == "-hsm" || "$arg" == "--managed-hsm" ]] && ((hsm_count++))
        done
        
        if [[ $((akv_count + hsm_count)) -gt 1 ]]; then
            print_error "Cannot specify both -akv and -hsm parameters"
            exit 1
        fi
    fi
}

# ============================================================================
# Configuration Validation
# ============================================================================

validate_configuration() {
    print_section "📋 Validating Configuration"
    
    # Check .env file exists
    validation_check_env_file "${ENV_FILE}"
    
    # Load environment variables
    set -a
    source "${ENV_FILE}"
    set +a
    
    # Override DEPLOY_MANAGED_HSM based on VAULT_TYPE parameter
    if [[ -n "${VAULT_TYPE}" ]]; then
        if [[ "${VAULT_TYPE}" == "keyvault" ]]; then
            export DEPLOY_MANAGED_HSM="false"
            print_info "Vault Type: Azure Key Vault (from -akv/-exascale parameter)"
        elif [[ "${VAULT_TYPE}" == "managedhsm" ]]; then
            export DEPLOY_MANAGED_HSM="true"
            print_info "Vault Type: Managed HSM (from -hsm parameter)"
        fi
    else
        print_info "Vault Type: Using DEPLOY_MANAGED_HSM from .env (${DEPLOY_MANAGED_HSM:-false})"
    fi

    # Override DEPLOY_EXASCALE if set via -exascale flag
    if [[ -n "${DEPLOY_EXASCALE}" ]]; then
        export TF_VAR_deploy_exascale="${DEPLOY_EXASCALE}"
        print_info "Oracle DB Type: Exascale (from -exascale parameter)"
    else
        local env_exascale="${DEPLOY_EXASCALE:-false}"
        export TF_VAR_deploy_exascale="${env_exascale}"
        print_info "Oracle DB Type: Using DEPLOY_EXASCALE from .env (${env_exascale})"
    fi

    # When Exascale is enabled, validate that an SSH public key is available
    if [[ "${TF_VAR_deploy_exascale:-false}" == "true" ]]; then
        local ssh_key="${ORACLE_SSH_PUBLIC_KEY:-${TF_VAR_oracle_ssh_public_key:-}}"
        if [[ -z "${ssh_key}" ]]; then
            error_exit "ORACLE_SSH_PUBLIC_KEY is required when deploying Exascale. Set it in .env or export TF_VAR_oracle_ssh_public_key."
        fi
        export TF_VAR_oracle_ssh_public_key="${ssh_key}"
    fi
    echo ""
    
    # Validate required variables based on mode
    case "${DEPLOYMENT_MODE}" in
        fresh|terraform-only)
            validation_check_required_vars "${ENV_FILE}" \
                "AZ_LOCATION" \
                "ADBS_ADMIN_PASSWORD"
            ;;
        configure-hsm-only)
            # Only need location for HSM configuration
            validation_check_required_vars "${ENV_FILE}" \
                "AZ_LOCATION"
            ;;
        create-tfvars-only)
            validation_check_required_vars "${ENV_FILE}" \
                "AZ_LOCATION" \
                "ADBS_ADMIN_PASSWORD"
            ;;
        destroy)
            # Minimal validation for destroy mode
            validation_check_required_vars "${ENV_FILE}" \
                "AZ_LOCATION"
            ;;
    esac
    
    # Validate password format (if required)
    if [[ "${DEPLOYMENT_MODE}" != "destroy" && "${DEPLOYMENT_MODE}" != "configure-hsm-only" ]]; then
        if [[ ${#ADBS_ADMIN_PASSWORD} -lt 12 || ${#ADBS_ADMIN_PASSWORD} -gt 30 ]]; then
            error_exit "ADBS_ADMIN_PASSWORD must be 12-30 characters"
        fi
        
        if [[ ! "${ADBS_ADMIN_PASSWORD}" =~ [A-Z] ]]; then
            error_exit "ADBS_ADMIN_PASSWORD must contain at least one uppercase letter"
        fi
        
        if [[ ! "${ADBS_ADMIN_PASSWORD}" =~ [a-z] ]]; then
            error_exit "ADBS_ADMIN_PASSWORD must contain at least one lowercase letter"
        fi
        
        if [[ ! "${ADBS_ADMIN_PASSWORD}" =~ [0-9] ]]; then
            error_exit "ADBS_ADMIN_PASSWORD must contain at least one number"
        fi
        
        if [[ "${ADBS_ADMIN_PASSWORD}" == *\"* ]]; then
            error_exit "ADBS_ADMIN_PASSWORD cannot contain double quotes"
        fi
    fi
    
    print_success "Configuration validated"
    echo ""
}

# ============================================================================
# Display Configuration Summary
# ============================================================================

display_configuration() {
    print_section "⚙️  Deployment Configuration"
    
    print_kv "Deployment Mode" "${DEPLOYMENT_MODE}"

    # Oracle DB type
    if [[ "${TF_VAR_deploy_exascale:-false}" == "true" ]]; then
        print_kv "Oracle DB Type" "Exascale (Storage Vault + VM Cluster)"
    else
        print_kv "Oracle DB Type" "Autonomous Database Serverless (ADBS)"
    fi

    # Show vault type selection
    if [[ -n "${VAULT_TYPE}" ]]; then
        if [[ "${VAULT_TYPE}" == "keyvault" ]]; then
            print_kv "Vault Type" "Azure Key Vault (parameter override)"
        else
            print_kv "Vault Type" "Managed HSM (parameter override)"
        fi
    else
        if [[ "${DEPLOY_MANAGED_HSM:-false}" == "true" ]]; then
            print_kv "Vault Type" "Managed HSM (from .env)"
        else
            print_kv "Vault Type" "Azure Key Vault (from .env)"
        fi
    fi

    print_kv "Azure Location" "${AZ_LOCATION}"
    print_kv "Terraform Dir" "${TERRAFORM_WORK_DIR}"
    print_kv "Log Analytics" "${ENABLE_LOG_ANALYTICS:-true}"
    print_kv "Event Hub Logging" "${ENABLE_EVENTHUB_LOGGING:-false}"

    if [[ "${TF_VAR_deploy_exascale:-false}" == "true" ]]; then
        echo ""
        print_info "Oracle Exascale Configuration:"
        print_kv "  Availability Zone" "${EXASCALE_AZ:-1}"
        print_kv "  Storage (GiB)" "${EXASCALE_STORAGE_GBS:-300}"
        print_kv "  CPU Cores" "${EXASCALE_CPU_CORES:-4}"
        print_kv "  GI Version" "${EXASCALE_GI_VERSION:-19.0.0.0.0}"
        print_kv "  SSH Key Set" "$([ -n "${TF_VAR_oracle_ssh_public_key:-}" ] && echo 'yes' || echo 'no')"
    elif [[ -n "${ADBS_DISPLAY_NAME:-}" ]]; then
        echo ""
        print_info "Oracle ADBS Custom Configuration:"
        print_kv "  Display Name" "${ADBS_DISPLAY_NAME}"
        print_kv "  DB Version" "${ADBS_DB_VERSION:-19c}"
        print_kv "  Workload" "${ADBS_WORKLOAD:-OLTP}"
        print_kv "  Compute Model" "${ADBS_COMPUTE_MODEL:-ECPU}"
        print_kv "  Compute Count" "${ADBS_COMPUTE_COUNT:-2}"
        print_kv "  Storage (TB)" "${ADBS_STORAGE_SIZE_TBS:-1}"
    fi
    
    echo ""
}

# ============================================================================
# Configure Managed HSM
# ============================================================================

configure_managed_hsm() {
    local tf_dir="${TERRAFORM_WORK_DIR}"
    
    print_section "🔐 Configuring Managed HSM"
    
    # Get Managed HSM deployment status from .env
    local deploy_hsm="${DEPLOY_MANAGED_HSM:-false}"
    
    if [[ "${deploy_hsm}" != "true" ]]; then
        print_warning "Managed HSM is not enabled in configuration"
        print_info "Set DEPLOY_MANAGED_HSM=true in .env file"
        print_info "Skipping HSM configuration..."
        return 0
    fi
    
    local hsm_name=""
    local resource_group=""
    
    # Try to get HSM details from Terraform state first (if available)
    if [[ -f "${tf_dir}/terraform.tfstate" ]]; then
        print_info "Refreshing Terraform state..."
        terraform_refresh "${tf_dir}"
        
        print_info "Retrieving Managed HSM information from Terraform state..."
        hsm_name=$(terraform_output "${tf_dir}" "managed_hsm" "json" | jq -r '.name' 2>/dev/null)
        resource_group=$(terraform_output "${tf_dir}" "resource_group" "json" | jq -r '.name' 2>/dev/null)
    fi
    
    # If Terraform state not available or outputs are null, search in Azure
    if [[ -z "${hsm_name}" || "${hsm_name}" == "null" ]]; then
        print_warning "Terraform state not found or incomplete"
        print_info "Searching for Managed HSM in Azure (location: ${AZ_LOCATION})..."
        
        # Find HSM by location using Azure resource list
        local hsm_list=$(az resource list \
            --resource-type "Microsoft.KeyVault/managedHSMs" \
            --query "[?location=='${AZ_LOCATION}'].{name:name, resourceGroup:resourceGroup}" \
            -o json 2>/dev/null)
        
        if [[ -z "${hsm_list}" || "${hsm_list}" == "[]" ]]; then
            print_error "No Managed HSM found in location: ${AZ_LOCATION}"
            print_info "Deploy infrastructure first: ./deploy-adbs-demo.sh"
            exit 1
        fi
        
        # Get the first matching HSM
        hsm_name=$(echo "${hsm_list}" | jq -r '.[0].name' 2>/dev/null)
        resource_group=$(echo "${hsm_list}" | jq -r '.[0].resourceGroup' 2>/dev/null)
        
        if [[ -z "${hsm_name}" || "${hsm_name}" == "null" ]]; then
            print_error "Failed to retrieve Managed HSM information from Azure"
            exit 1
        fi
        
        print_info "Found Managed HSM via Azure CLI"
    else
        print_info "Found Managed HSM via Terraform state"
    fi
    
    print_success "Managed HSM: ${hsm_name}"
    print_success "Resource Group: ${resource_group}"
    echo ""
    
    # Activate Managed HSM
    print_info "Step 1: Activating Managed HSM (if not already activated)..."
    if ! hsm_activate "${hsm_name}" "${resource_group}" "${SCRIPT_DIR}"; then
        print_error "Failed to activate Managed HSM"
        exit 1
    fi
    echo ""
    
    # Assign role to current user
    print_info "Step 2: Assigning roles to current user..."
    
    # Assign Crypto Officer role (for creating/managing keys)
    if ! hsm_assign_current_user_role "${hsm_name}" "Managed HSM Crypto Officer" "/keys"; then
        print_error "Failed to assign Crypto Officer role"
        exit 1
    fi
    
    # Assign Crypto User role (for reading/using keys)
    if ! hsm_assign_current_user_role "${hsm_name}" "Managed HSM Crypto User" "/keys"; then
        print_error "Failed to assign Crypto User role"
        exit 1
    fi
    
    echo ""
    
    # Create encryption keys
    print_info "Step 3: Creating encryption keys..."
    if ! hsm_create_encryption_keys "${hsm_name}"; then
        print_error "Failed to create encryption keys"
        exit 1
    fi
    echo ""
    
    # Get HSM connection information
    print_info "Step 4: Retrieving HSM connection information..."
    if ! hsm_get_connection_info "${hsm_name}" "${resource_group}"; then
        print_warning "Could not retrieve complete HSM connection information"
    fi
    echo ""
    
    print_success "Managed HSM configuration completed! 🎉"
    echo ""
    
    print_info "Next Steps:"
    echo "  1. Keys are ready for Oracle ADBS encryption"
    echo "  2. Configure Oracle ADBS to use HSM keys"
    echo "  3. List all keys: hsm_list_keys \"${hsm_name}\""
    echo ""
}

# ============================================================================
# Terraform Deployment
# ============================================================================

deploy_terraform() {
    local tf_dir="${TERRAFORM_WORK_DIR}"
    
    print_section "🏗️  Terraform Infrastructure Deployment"
    
    # Generate terraform.tfvars
    terraform_create_tfvars "${tf_dir}"
    
    # Initialize Terraform
    terraform_init "${tf_dir}"
    
    # Validate configuration
    terraform_validate "${tf_dir}"
    
    if [[ "${DEPLOYMENT_MODE}" == "terraform-only" ]]; then
        # Only create plan
        terraform_plan "${tf_dir}"
        print_success "Terraform plan created successfully"
        print_info "To apply the plan, run:"
        print_info "  cd ${tf_dir}"
        print_info "  terraform apply tfplan"
        return 0
    fi
    
    # Create and apply plan
    terraform_plan "${tf_dir}"
    
    local auto_approve="${TERRAFORM_AUTO_APPROVE:-false}"
    terraform_apply "${tf_dir}" "tfplan" "${auto_approve}"
    
    # Refresh state
    terraform_refresh "${tf_dir}"
    
    print_success "Infrastructure deployed successfully"
    echo ""
}

# ============================================================================
# Display Deployment Summary
# ============================================================================

display_summary() {
    local tf_dir="${TERRAFORM_WORK_DIR}"
    
    print_section "✨ Deployment Summary"
    
    # Get outputs from Terraform
    local rg_name=$(terraform_output "${tf_dir}" "resource_group" "json" | jq -r '.name' 2>/dev/null || echo "N/A")
    local location=$(terraform_output "${tf_dir}" "resource_group" "json" | jq -r '.location' 2>/dev/null || echo "N/A")
    local vm_fqdn=$(terraform_output "${tf_dir}" "useful_info" "json" | jq -r '.vm_fqdn' 2>/dev/null || echo "N/A")
    local vm_ip=$(terraform_output "${tf_dir}" "useful_info" "json" | jq -r '.vm_public_ip_address' 2>/dev/null || echo "N/A")
    local akv_uri=$(terraform_output "${tf_dir}" "useful_info" "json" | jq -r '.akv_uri' 2>/dev/null || echo "N/A")
    local deploy_mode=$(terraform_output "${tf_dir}" "useful_info" "json" | jq -r '.deploy_mode' 2>/dev/null || echo "N/A")

    print_kv "Resource Group" "${rg_name}"
    print_kv "Location" "${location}"
    print_kv "Deploy Mode" "${deploy_mode}"
    print_kv "AKV URI" "${akv_uri}"
    print_kv "Jumpbox FQDN" "${vm_fqdn}"
    print_kv "Jumpbox IP" "${vm_ip}"

    if [[ "${TF_VAR_deploy_exascale:-false}" == "true" ]]; then
        local cluster_name=$(terraform_output "${tf_dir}" "exascale_vm_cluster" "json" | jq -r '.name' 2>/dev/null || echo "N/A")
        local scan_dns=$(terraform_output "${tf_dir}" "exascale_vm_cluster" "json" | jq -r '.scan_dns_name' 2>/dev/null || echo "N/A")
        local vault_name=$(terraform_output "${tf_dir}" "exascale_storage_vault" "json" | jq -r '.name' 2>/dev/null || echo "N/A")
        print_kv "Exascale Cluster" "${cluster_name}"
        print_kv "Exascale SCAN DNS" "${scan_dns}"
        print_kv "Exascale Storage Vault" "${vault_name}"
    else
        local adbs_name=$(terraform_output "${tf_dir}" "autonomous_database" "json" | jq -r '.name' 2>/dev/null || echo "N/A")
        print_kv "ADBS Name" "${adbs_name}"
    fi

    echo ""
    print_success "Deployment completed successfully! 🎉"
    echo ""

    if [[ "${TF_VAR_deploy_exascale:-false}" == "true" ]]; then
        print_info "Next Steps (Exascale + AKV):"
        echo "  1. Connect to jumpbox VM: ${vm_fqdn}"
        echo "  2. Configure OCI DNS for AKV private endpoint resolution"
        echo "  3. Set up OAuth Service Principal on the VM Cluster"
        echo "  4. Grant Key Vault access to the Service Principal"
        echo "  5. Configure TDE master key to use AKV (ADMINISTER KEY MANAGEMENT)"
        echo "  6. Validate encrypted tablespaces and AKV connectivity"
    else
        print_info "Next Steps (ADBS + AKV):"
        echo "  1. Connect to jumpbox VM: ${vm_fqdn}"
        echo "  2. Download Oracle ADBS wallet from Azure Portal"
        echo "  3. Configure Oracle client tools"
        echo "  4. Test database connectivity"
    fi
    echo ""
    
    print_info "To view full Terraform outputs:"
    print_info "  cd ${tf_dir}"
    print_info "  terraform output"
    echo ""
}

# ============================================================================
# Clean Terraform State
# ============================================================================

clean_terraform_state() {
    local tf_dir="${TERRAFORM_WORK_DIR}"
    
    print_section "🧹 Cleaning Terraform State"
    
    terraform_clean_state "${tf_dir}"
    
    print_success "Terraform state cleaned"
    echo ""
}

# ============================================================================
# Destroy Infrastructure
# ============================================================================

destroy_infrastructure() {
    local tf_dir="${TERRAFORM_WORK_DIR}"
    
    print_section "💥 Destroying Infrastructure"
    
    # Check if Terraform state exists
    if [[ ! -f "${tf_dir}/terraform.tfstate" ]]; then
        print_warning "No Terraform state found"
        print_info "Nothing to destroy"
        exit 0
    fi
    
    # Show resources to be destroyed
    print_info "Resources to be destroyed:"
    echo ""
    cd "${tf_dir}"
    
    # Show a concise list of resources (not full details)
    local resource_count=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "${resource_count}" -gt 0 ]]; then
        terraform state list | head -30
        
        if [[ "${resource_count}" -gt 30 ]]; then
            echo ""
            print_info "... and $((resource_count - 30)) more resources"
        fi
    else
        print_warning "No resources found in state"
    fi
    
    echo ""
    print_kv "Total resources to destroy" "${resource_count}"
    echo ""
    
    # Confirmation prompt
    print_warning "This will DESTROY all infrastructure!"
    print_warning "This action cannot be undone!"
    echo ""
    read -p "Type 'yes' to confirm destruction: " confirmation
    
    if [[ "${confirmation}" != "yes" ]]; then
        print_info "Destruction cancelled"
        exit 0
    fi
    
    # Destroy infrastructure
    terraform_destroy "${tf_dir}" "true"
    
    # Clean state files
    clean_terraform_state
    
    print_success "Infrastructure destroyed successfully"
    echo ""
}

# ============================================================================
# Main Execution Flow
# ============================================================================

main() {
    # Display banner
    cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ___                _         _    ___  ___  ___  
  / _ \ _ __ __ _  __| | ___   / \  |   \| _ )/ __| 
 | | | | '__/ _` |/ _` |/ _ \ / _ \ | |) | _ \\__ \ 
 | |_| | | | (_| | (_| |  __// ___ \|___/|___/|___/ 
  \___/|_|  \__,_|\__,_|\___/_/   \_\              
                                                     
     + Azure Key Vault Deployment Orchestrator
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    echo ""
    
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    case "${DEPLOYMENT_MODE}" in
        destroy)
            validation_check_prerequisites "terraform" "jq"
            ;;
        *)
            validation_check_prerequisites "az" "terraform" "jq"
            ;;
    esac
    
    # Validate configuration
    validate_configuration
    
    # Azure authentication (skip for tfvars-only mode)
    if [[ "${DEPLOYMENT_MODE}" != "create-tfvars-only" ]]; then
        azure_login
        azure_set_subscription "${AZURE_SUBSCRIPTION_ID:-}"
    fi
    
    # Display configuration
    display_configuration
    
    # Execute based on deployment mode
    case "${DEPLOYMENT_MODE}" in
        fresh)
            clean_terraform_state
            deploy_terraform
            
            # Configure Managed HSM if enabled
            if [[ "${DEPLOY_MANAGED_HSM:-false}" == "true" ]]; then
                configure_managed_hsm
            fi
            
            display_summary
            ;;
        terraform-only)
            deploy_terraform
            ;;
        configure-hsm-only)
            configure_managed_hsm
            ;;
        create-tfvars-only)
            local tf_dir="${TERRAFORM_WORK_DIR}"
            terraform_create_tfvars "${tf_dir}"
            print_success "Generated terraform.tfvars"
            print_info "To deploy manually:"
            print_info "  cd ${tf_dir}"
            print_info "  terraform init"
            print_info "  terraform plan"
            print_info "  terraform apply"
            ;;
        destroy)
            destroy_infrastructure
            ;;
        *)
            error_exit "Unknown deployment mode: ${DEPLOYMENT_MODE}"
            ;;
    esac
    
    exit 0
}

# ============================================================================
# Script Entry Point
# ============================================================================

main "$@"
