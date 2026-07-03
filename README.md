# Oracle Exascale with Azure Key Management over Private Endpoints

Infrastructure-as-Code (Terraform) and Bash orchestration for deploying [Oracle Database@Azure Exascale](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-exascale-overview) on Azure with [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/overview) or [Azure Managed HSM](https://learn.microsoft.com/en-us/azure/key-vault/managed-hsm/overview) for Customer-Managed Encryption Keys (CMEK) over [Private Endpoints](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview).

## How It Works

Deployment is split into two phases:

| Phase | How | What |
|-------|-----|------|
| **1. Infrastructure** | `deploy-exascale-demo.sh` (Terraform + Azure CLI) | VNet, subnets, Key Vault/HSM, Private Endpoints, DNS zones, Firewall, NAT Gateway, Jumpbox VM, Oracle Exascale Storage Vault + VM Cluster |
| **2. Key integration** | Manual (Oracle SQL + OCI Console) | Keystore open, TDE master key creation, key rotation, validation |

Phase 1 is fully automated. Phase 2 is documented in [exascale-test-plan.md](exascale-test-plan.md) and [Step-by-step.md](Step-by-step.md).

## Quick Start

```bash
# 1. Clone and configure
git clone https://github.com/terrymandin/odaa-akv-tests.git
cd odaa-akv-tests
cp .env.example .env   # Edit with your values (at minimum: AZ_LOCATION, ORACLE_SSH_PUBLIC_KEY)

# 2. Deploy Exascale + AKV Standard (default)
./deploy-exascale-demo.sh -exascale

# Or with AKV Premium (HSM-backed keys inside AKV)
# Set KEY_VAULT_SKU=premium in .env, then run the same command

# Or with Azure Managed HSM (FIPS 140-3 Level 3, single-tenant)
./deploy-exascale-demo.sh -exascale-hsm
```

### Orchestrator Commands

```bash
./deploy-exascale-demo.sh -exascale              # Exascale + AKV
./deploy-exascale-demo.sh -exascale-hsm          # Exascale + Managed HSM
./deploy-exascale-demo.sh -akv                   # ADB Serverless + AKV (legacy)
./deploy-exascale-demo.sh -hsm                   # ADB Serverless + HSM (legacy)
./deploy-exascale-demo.sh --only-terraform       # Plan only (no apply)
./deploy-exascale-demo.sh --only-configure-hsm   # Activate & configure an existing HSM
./deploy-exascale-demo.sh --create-tfvars        # Generate terraform.tfvars for manual use
./deploy-exascale-demo.sh --destroy              # Destroy all infrastructure
./deploy-exascale-demo.sh --help                 # Show full help
```

### What the Orchestrator Does

```
deploy-exascale-demo.sh
├── Validate .env configuration & prerequisites (az, terraform, jq)
├── Authenticate to Azure (az login + subscription)
├── Generate terraform.tfvars from .env
├── terraform init → validate → plan → apply
│   ├── Resource Group
│   ├── VNet + 5 subnets (Oracle, PE, NAT, VM, Firewall)
│   ├── Key Vault + Private Endpoint + RSA/EC keys + rotation policies
│   ├── Managed HSM + Private Endpoint  (if -exascale-hsm)
│   ├── Private DNS zones
│   ├── Azure Firewall + NAT Gateway
│   ├── Windows Jumpbox VM
│   ├── Log Analytics + diagnostics  (optional)
│   └── Oracle Exascale Storage Vault + VM Cluster
├── Activate & configure Managed HSM  (if -exascale-hsm)
│   ├── Security domain download
│   ├── Role assignments (Crypto Officer, Crypto User)
│   └── Create HSM encryption keys
└── Display deployment summary with outputs
```

### After Infrastructure Deployment

See [exascale-test-plan.md](exascale-test-plan.md) for the full key lifecycle test plan covering AKV Standard, AKV Premium, and MHSM scenarios.

---

## Documentation Index

### Guides

| Document | Description |
|----------|-------------|
| **[exascale-test-plan.md](exascale-test-plan.md)** | Manual test plan: AKV Standard, Premium, and MHSM key lifecycle on Exascale |
| **[Step-by-step.md](Step-by-step.md)** | End-to-end implementation guide: prerequisites, Azure infra, OCI DNS, OAuth, Key Vault integration, and validation queries |
| **[lessons-learned-exascale.md](lessons-learned-exascale.md)** | Critical gotchas, undocumented requirements, bugs, and workarounds — **read this before starting** |

### Reference

| Document | Description |
|----------|-------------|
| **[DOCUMENTATION_GUIDE.md](DOCUMENTATION_GUIDE.md)** | Architecture diagrams, security overview, configuration options, monitoring, and quick-reference commands |
| **[infra-deployment/README.md](infra-deployment/README.md)** | Terraform infrastructure reference: resources, variables, outputs |
| **[.env.example](.env.example)** | All configurable variables with descriptions and defaults |
| **[AGENTS.MD](AGENTS.MD)** | AI agent knowledge base for automated assistance |

---

## Repository Structure

```
.
├── deploy-exascale-demo.sh        # Bash orchestrator (wraps Terraform + Azure CLI)
├── .env.example                   # Configuration template (→ copy to .env)
├── exascale-test-plan.md          # Manual test plan for AKV/MHSM key lifecycle
├── Step-by-step.md                # End-to-end implementation guide
├── lessons-learned-exascale.md    # Gotchas, undocumented requirements, workarounds
├── infra-deployment/              # Terraform configuration
│   ├── main.tf                    #   VNet, subnets, route tables
│   ├── exascale.tf                #   Oracle Exascale Storage Vault + VM Cluster (AzAPI)
│   ├── Exascale.tf                    #   Oracle ADB Serverless (legacy, deploy_exascale=false)
│   ├── key_vault.tf               #   Key Vault + Private Endpoint + RSA/EC keys + rotation
│   ├── managed_hsm.tf             #   Managed HSM + Private Endpoint (optional)
│   ├── firewall.tf                #   Azure Firewall (Standard SKU)
│   ├── firewall_policy.tf         #   Firewall rules and policies
│   ├── nat_gateway.tf             #   NAT Gateway for outbound connectivity
│   ├── jumpbox_vm.tf              #   Windows Jumpbox VM
│   ├── log_analytics.tf           #   Log Analytics + diagnostics (optional)
│   ├── event_hub.tf               #   Event Hub streaming (optional)
│   ├── workbook.tf                #   Firewall traffic workbook (optional)
│   ├── variables.tf               #   Input variables with validation
│   ├── outputs.tf                 #   Resource IDs, URIs, IPs
│   ├── locals.tf                  #   Computed values
│   └── providers.tf               #   azurerm, azapi, random providers
└── deploy/lib/                    # Modular Bash library
    ├── common.sh                  #   Logging, colors, utilities
    ├── validation.sh              #   Pre-flight checks (.env, tools, passwords)
    ├── azure.sh                   #   Azure CLI login, subscription
    ├── terraform.sh               #   init, validate, plan, apply, destroy, output
    ├── config-akv.sh              #   Key Vault post-deploy configuration
    └── config-hsm.sh             #   HSM activation, role assignment, key creation
```

---

## Configuration

All settings are driven by the `.env` file (copy from [.env.example](.env.example)):

| Variable | Required | Description |
|----------|----------|-------------|
| `AZ_LOCATION` | Yes | Azure region (e.g. `eastus`) |
| `ORACLE_SSH_PUBLIC_KEY` | Yes (Exascale) | SSH public key for Exascale VM Cluster nodes |
| `AZURE_SUBSCRIPTION_ID` | No | Uses active subscription if empty |
| `KEY_VAULT_SKU` | No | `standard` (default) or `premium` (HSM-backed keys in AKV) |
| `KEY_VAULT_PUBLIC_NETWORK_ACCESS` | No | `true` (default) for public endpoint, `false` for Private Endpoint-only access |
| `DEPLOY_MANAGED_HSM` | No | `true` / `false` — deploy Azure Managed HSM (default: `false`) |
| `DEPLOY_EXASCALE` | No | `true` / `false` — Exascale vs ADB Serverless (default: `true`) |
| `JUMPBOX_ADMIN_PASSWORD` | Conditional | Required only when `DEPLOY_EXASCALE=false` (ADB Serverless mode) |
| `ENABLE_LOG_ANALYTICS` | No | Deploy Log Analytics workspace (default: `true`) |
| `ENABLE_EVENTHUB_LOGGING` | No | Deploy Event Hub for log streaming (default: `false`) |
| `TF_LOG` | No | Terraform log level (`TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`) |
| `TERRAFORM_WORK_DIR` | No | Terraform working directory (default: `./infra-deployment`) |
| `TERRAFORM_AUTO_APPROVE` | No | Skip Terraform approval prompts (`true` / `false`) |

Exascale-specific overrides (`EXASCALE_VAULT_AZ`, `EXASCALE_CLUSTER_SHAPE`, `EXASCALE_CLUSTER_ENABLED_ECPU_COUNT`, etc.) are available — see [.env.example](.env.example) for the full list.

---

## Key Store Scenarios at a Glance

| | AKV Standard | AKV Premium | Azure Managed HSM |
|---|---|---|---|
| **FIPS Level** | 140-2 Level 2 | 140-3 Level 3 | 140-3 Level 3 |
| **Hardware** | Multi-tenant (software keys) | Multi-tenant (HSM-backed) | Single-tenant dedicated |
| **Key type** | RSA | RSA-HSM | RSA-HSM |
| **Cost** | ~$0.03 / 10K ops | ~20% more | ~$3–5 / hour |
| **Deploy flag** | `-exascale` | `-exascale` + `KEY_VAULT_SKU=premium` | `-exascale-hsm` |
| **Test plan section** | Scenario A | Scenario B | Scenario C |

---

## Prerequisites

- **Azure**: Subscription with Owner or Contributor role
- **Oracle Database@Azure**: Active subscription ([overview](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/database-overview))
- **Advanced Networking**: Enabled in your region ([network planning](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan#advanced-networking-features))
- **Tools**: Azure CLI >= 2.79.0, Terraform >= 1.9.0, `jq`, Bash, `openssl` (for MHSM security domain)
- **SSH key pair**: RSA or Ed25519 key for Exascale VM Cluster node access

> **Before starting**: Read [lessons-learned-exascale.md](lessons-learned-exascale.md) — it documents critical undocumented requirements that will save hours of troubleshooting.

---

## Official References

- [Integrate Oracle Exadata Database@Azure with Azure Key Vault](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/manage-oracle-transparent-data-encryption-azure-key-vault) — Microsoft Learn
- [Azure Key Vault integration architecture (CAF)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/oracle-on-azure/oracle-azure-key-vault-integration-exadata) — Cloud Adoption Framework
- [Oracle Database@Azure overview](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/database-overview) — Microsoft Learn
- [Oracle Exascale documentation](https://docs.oracle.com/en/engineered-systems/exadata/exascale/) — Oracle


