# Oracle Autonomous Database with Azure Key Management over Private Endpoints

Infrastructure-as-Code (Terraform) and Bash orchestration for deploying [Oracle Autonomous Database Serverless (ADBS)](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/) on Azure with [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/overview) or [Azure Managed HSM](https://learn.microsoft.com/en-us/azure/key-vault/managed-hsm/overview) for Customer-Managed Encryption Keys (CMEK) over [Private Endpoints](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview).

## How It Works

The deployment is split in two phases:

| Phase | How | What |
|-------|-----|------|
| **1. Infrastructure** | `deploy-adbs-demo.sh` (Terraform + Bash) | VNet, subnets, Key Vault/HSM, Private Endpoints, DNS zones, Firewall, NAT Gateway, Jumpbox VM, Oracle ADBS |
| **2. Key integration** | Manual (OCI Console + SQL) | OCI DNS records, OAuth Service Principal, Key Vault Access Policies, CMEK configuration, `route_outbound_connections` |

Phase 1 is fully automated. Phase 2 requires manual steps documented in [Step-by-step.md](Step-by-step.md) (sections 3–7) and [lessons-learned-adbs.md](lessons-learned-adbs.md).

## Quick Start

```bash
# 1. Clone and configure
git clone https://github.com/sihbher/oracle-adbs-akv-tests.git
cd oracle-adbs-akv-tests
cp .env.example .env   # Edit with your values (at minimum: AZ_LOCATION, ADBS_ADMIN_PASSWORD)

# 2. Deploy infrastructure with Key Vault (default)
./deploy-adbs-demo.sh -akv

# Or deploy with Managed HSM (FIPS 140-3 Level 3)
./deploy-adbs-demo.sh -hsm
```

### All Orchestrator Commands

```bash
./deploy-adbs-demo.sh -akv                # Deploy infra + Key Vault
./deploy-adbs-demo.sh -hsm                # Deploy infra + Managed HSM
./deploy-adbs-demo.sh --only-terraform    # Plan only (no apply)
./deploy-adbs-demo.sh --only-configure-hsm # Activate & configure existing HSM
./deploy-adbs-demo.sh --create-tfvars     # Generate terraform.tfvars for manual use
./deploy-adbs-demo.sh --destroy           # Destroy all infrastructure
./deploy-adbs-demo.sh --help              # Show full help
```

### What the Orchestrator Does

```
deploy-adbs-demo.sh
├── Validate .env configuration & prerequisites (az, terraform, jq)
├── Authenticate to Azure (az login + subscription)
├── Generate terraform.tfvars from .env
├── terraform init → validate → plan → apply
│   ├── Resource Group
│   ├── VNet + 5 subnets (ADBS, PE, NAT, VM, Firewall)
│   ├── Key Vault + Private Endpoint + RSA/EC keys + rotation policies
│   ├── Managed HSM + Private Endpoint (if -hsm)
│   ├── Private DNS zones (privatelink.vaultcore.azure.net, etc.)
│   ├── Azure Firewall + NAT Gateway
│   ├── Windows Jumpbox VM
│   ├── Log Analytics + diagnostics (optional)
│   └── Oracle Autonomous Database
├── Activate & configure Managed HSM (if -hsm)
│   ├── Security domain download
│   ├── Role assignments (Crypto Officer, Crypto User)
│   └── Create HSM encryption keys
└── Display deployment summary with outputs
```

### After Infrastructure Deployment (Manual Steps)

1. **Configure OCI DNS** — Create private DNS zones in the OCI VCN for Key Vault resolution → [Step-by-step.md §3](Step-by-step.md)
2. **Set up OAuth** — Enable Service Principal auth on ADBS, complete consent flow → [Step-by-step.md §4](Step-by-step.md)
3. **Configure Access Policies** — Grant Key Vault permissions to the Service Principal → [Step-by-step.md §4.6](Step-by-step.md)
4. **Set Network ACLs** — Allow ADBS to reach Key Vault → [Step-by-step.md §5](Step-by-step.md)
5. **Configure CMEK** — Assign encryption key and enforce private endpoint routing → [Step-by-step.md §6](Step-by-step.md)
6. **Validate** — DNS resolution, connectivity, wallet status, encrypted tablespaces → [Step-by-step.md §7](Step-by-step.md)

## Documentation Index

### Guides

| Document | Description |
|----------|-------------|
| **[Step-by-step.md](Step-by-step.md)** | End-to-end implementation guide: prerequisites, Azure infra, OCI DNS, OAuth, Key Vault integration, and validation queries |
| **[lessons-learned-adbs.md](lessons-learned-adbs.md)** | Critical gotchas, undocumented requirements, bugs, and workarounds from 3 test iterations — **read this before starting** |

### Reference

| Document | Description |
|----------|-------------|
| **[DOCUMENTATION_GUIDE.md](DOCUMENTATION_GUIDE.md)** | Architecture diagrams, security overview, configuration options, monitoring, and quick reference commands |
| **[infra-deployment/README.md](infra-deployment/README.md)** | Terraform infrastructure reference: resources, variables, outputs |
| **[deploy/lib/README.md](deploy/lib/README.md)** | Bash library modules: functions, usage, and examples |
| **[.env.example](.env.example)** | All configurable variables with descriptions and defaults |
| **[AGENTS.MD](AGENTS.MD)** | AI agent knowledge base for automated assistance |

## Repository Structure

```
.
├── deploy-adbs-demo.sh            # Bash orchestrator (wraps Terraform + Azure CLI)
├── .env.example                   # Configuration template (→ copy to .env)
├── infra-deployment/              # Terraform configuration
│   ├── main.tf                    #   VNet, subnets, route tables
│   ├── adbs.tf                    #   Oracle Autonomous Database (azurerm_oracle_autonomous_database)
│   ├── key_vault.tf               #   Key Vault + Private Endpoint + RSA/EC keys + rotation
│   ├── managed_hsm.tf             #   Managed HSM + Private Endpoint (optional)
│   ├── firewall.tf                #   Azure Firewall (Standard SKU)
│   ├── firewall_policy.tf         #   Firewall rules and policies
│   ├── nat_gateway.tf             #   NAT Gateway for ADBS outbound
│   ├── jumpbox_vm.tf              #   Windows Jumpbox VM
│   ├── log_analytics.tf           #   Log Analytics + diagnostics (optional)
│   ├── event_hub.tf               #   Event Hub streaming (optional)
│   ├── workbook.tf                #   Firewall traffic workbook (optional)
│   ├── variables.tf               #   Input variables with validation
│   ├── outputs.tf                 #   Resource IDs, URIs, IPs
│   ├── locals.tf                  #   Computed values
│   └── providers.tf               #   azurerm, random providers
├── deploy/lib/                    # Modular Bash library
│   ├── common.sh                  #   Logging, colors, utilities
│   ├── validation.sh              #   Pre-flight checks (.env, tools, passwords)
│   ├── azure.sh                   #   Azure CLI login, subscription
│   ├── terraform.sh               #   init, validate, plan, apply, destroy, output
│   ├── config-akv.sh              #   Key Vault post-deploy configuration
│   └── config-hsm.sh             #   HSM activation, role assignment, key creation
└── certs/                         # HSM security domain certificates & keys
```

## Configuration

All settings are driven by the `.env` file (copy from [.env.example](.env.example)):

| Variable | Required | Description |
|----------|----------|-------------|
| `AZ_LOCATION` | Yes | Azure region (e.g. `uksouth`) |
| `ADBS_ADMIN_PASSWORD` | Yes | 12–30 chars, mixed case + number |
| `AZURE_SUBSCRIPTION_ID` | No | Uses active subscription if empty |
| `DEPLOY_MANAGED_HSM` | No | `true` / `false` (default: `false`) |
| `ENABLE_LOG_ANALYTICS` | No | Deploy Log Analytics (default: `true`) |
| `ENABLE_EVENTHUB_LOGGING` | No | Deploy Event Hub (default: `false`) |

ADBS-specific overrides (`ADBS_DISPLAY_NAME`, `ADBS_DB_VERSION`, `ADBS_WORKLOAD`, etc.) and Jumpbox VM settings are also configurable — see [.env.example](.env.example) for the full list.

## Scenarios at a Glance

| | Azure Key Vault | Azure Managed HSM |
|---|---|---|
| **FIPS Level** | 140-2 Level 2 | 140-3 Level 3 |
| **Hardware** | Multi-tenant | Single-tenant dedicated |
| **Key Types** | RSA, EC | RSA-HSM, EC-HSM, AES-HSM |
| **Cost** | ~$0.03 / 10K ops | ~$3–5 / hour |
| **Best For** | Most workloads | Regulated industries |
| **Guide** | [Step-by-step.md](Step-by-step.md) | [Step-by-step.md § Section 9](Step-by-step.md#9-managed-hsm-specific-steps) |

## Prerequisites

- **Azure**: Subscription with Owner or Contributor role
- **Oracle Database@Azure**: Active subscription ([overview](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/database-overview))
- **Advanced Networking**: Enabled in your region ([network planning](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan#advanced-networking-features))
- **Tools**: Azure CLI >= 2.79.0, Terraform >= 1.9.0, jq, Bash

> **Before starting**: Read [lessons-learned-adbs.md](lessons-learned-adbs.md) — it documents critical undocumented requirements (OCI DNS, Access Policies vs RBAC, Tenant ID pitfalls) that will save hours of troubleshooting.

## Official References

- [Integrate Oracle Exadata Database@Azure with Azure Key Vault](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/manage-oracle-transparent-data-encryption-azure-key-vault) — Microsoft Learn
- [Azure Key Vault integration architecture (CAF)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/oracle-on-azure/oracle-azure-key-vault-integration-exadata) — Cloud Adoption Framework
- [Oracle ADB Encryption Keys](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-encrypt-set-rotate-keys.html) — Oracle Documentation
- [Azure Key Vault Private Link](https://learn.microsoft.com/en-us/azure/key-vault/general/private-link-service) — Microsoft Learn
- [Azure Managed HSM Private Link](https://learn.microsoft.com/en-us/azure/key-vault/managed-hsm/private-link) — Microsoft Learn

## License

This project is provided as-is for testing and educational purposes. Review [Oracle licensing terms](https://www.oracle.com/cloud/azure/oracle-database-at-azure/), [Microsoft Azure terms](https://azure.microsoft.com/en-us/support/legal/), and your organization's compliance policies.
