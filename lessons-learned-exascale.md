# 🎓 Lessons Learned: Oracle Autonomous Database on Azure with Customer-Managed Encryption Keys

**Project**: Integration of Oracle Exascale with Azure Key Vault for CMEK  
**Duration**: October 2025 - February 2026  
**Test Iterations**: Test 2, Test 3, Test 4 (UK South region)  
**Complexity Level**: Advanced Multi-Cloud Integration

> **📘 For detailed step-by-step implementation guide, see [Step-by-step.md](Step-by-step.md)**

---

## 📚 Table of Contents

1. [Critical Undocumented Requirements](#1-critical-undocumented-requirements)
2. [Major Bugs and Workarounds](#2-major-bugs-and-workarounds)
3. [Authentication and Authorization Pitfalls](#3-authentication-and-authorization-pitfalls)
4. [Network and DNS Gotchas](#4-network-and-dns-gotchas)
5. [Managed HSM Differences](#5-managed-hsm-differences)
6. [Operational Limitations](#6-operational-limitations)
7. [Key Compatibility Findings](#7-key-compatibility-findings)
8. [Documentation Gaps](#8-documentation-gaps)
9. [Best Practices Summary](#9-best-practices-summary)
10. [What Would We Do Differently](#10-what-would-we-do-differently)

---

## 1. Critical Undocumented Requirements

### 1.1 DNS Configuration on OCI Side is Completely Undocumented

**The Gap:**
Oracle's official documentation does **not** mention that you must manually configure Private DNS Zones in the OCI VCN. This is the #1 cause of implementation failures.

**What's Required:**
- TWO Private DNS Zones for Standard Key Vault
- TWO additional zones for Managed HSM
- A records in **BOTH** zones pointing to the **same** Private Endpoint IP
- Zones must be created in the Private View with **exact same name** as the VCN

**Impact if Missed:**
- DNS resolves to public IP (e.g., Cloudflare servers)
- All connectivity tests fail silently
- No clear error messages
- Hours/days of troubleshooting

**Reference**: [Step-by-step.md - Section 3: OCI DNS Configuration](Step-by-step.md#3-oci-dns-configuration)

### 1.2 `route_outbound_connections` Must Be Explicitly Set

**The Gap:**
Early Oracle documentation didn't mention that Exascale won't consistently use Private Endpoints unless you explicitly set this parameter.

**What's Required:**
```sql
ALTER DATABASE PROPERTY SET route_outbound_connections = 'enforce_private_endpoint';
```

**Impact if Missed:**
- Database behaves inconsistently (sometimes public, sometimes private)
- Key rotation may fail intermittently
- No clear pattern to the failures

**When to Set:**
- **AFTER** DNS is configured correctly
- **AFTER** successful connectivity tests
- Requires database restart

### 1.3 Advanced Networking is a Hard Prerequisite

**The Reality:**
- Standard networking **cannot** use Private Endpoints
- Not all Azure regions support Advanced Networking
- Must verify **before** any deployment begins
- Cannot be changed after Exascale creation

**Regions Confirmed Working (as of Feb 2026):**
- UK South ✅
- West Europe ✅
- East US ✅

---

## 2. Major Bugs and Workarounds

### 2.1 Service Principal Proliferation

**The Bug:**
Every call to `DBMS_CLOUD_ADMIN.ENABLE_PRINCIPAL_AUTH` creates a **new** Service Principal with a different `client_id`, even if one with the same name already exists.

**Impact:**
- Azure AD gets cluttered with stale app registrations
- Confusion about which client_id to use for permissions
- No automatic cleanup

**Workaround:**
```sql
-- ALWAYS disable before re-enabling
BEGIN
  DBMS_CLOUD_ADMIN.DISABLE_PRINCIPAL_AUTH(
    provider => 'AZURE',
    username => 'ADMIN');
END;
/

-- Wait 30 seconds

-- Then re-enable
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_PRINCIPAL_AUTH(...);
END;
/
```

### 2.2 Oracle Documentation Uses Wrong Tenant ID

**The Bug:**
Oracle's documentation examples reference the **Subscription ID** instead of the **Directory (Tenant) ID** for the `azure_tenantid` parameter.

**Impact:**
- Service Principal gets created in wrong tenant
- Consent URL redirects to wrong Microsoft login
- OAuth flow impossible to complete
- Not obvious what's wrong

**The Fix:**
Always use **Directory (Tenant) ID** from: Azure Portal → Azure Active Directory → Overview

### 2.3 Consent URL Contains "www." Prefix

**The Bug:**
The auto-generated `azure_consent_url` sometimes includes "www." which doesn't exist for Microsoft's OAuth endpoint.

**Error:**
`DNS_PROBE_FINISHED_NXDOMAIN`

**The Fix:**
Manually remove "www." from the URL:
- ❌ `https://www.login.microsoftonline.com/...`
- ✅ `https://login.microsoftonline.com/...`

---

## 3. Authentication and Authorization Pitfalls

### 3.1 Azure RBAC Roles Don't Work for Oracle Database@Azure

**The Finding:**
Assigning `Key Vault Crypto Officer` or any Azure IAM role to the Oracle Database@Azure Service Principal via RBAC **does not work**.

**Error Message:**
```
The user, group or application 'appid=...' does not have keys list permission on key vault
```

**Root Cause:**
Oracle Database@Azure requires **Access Policies** (vault-level permissions), not RBAC assignments.

**The Solution:**
- Navigate to Key Vault → Access Policies → Create
- Grant: Get, List, Wrap Key, Unwrap Key, Sign, Verify
- Assign to the Oracle Database@Azure Service Principal (by Application ID)

**Why This Matters:**
Many Azure admins default to RBAC. This cost us hours of troubleshooting.

### 3.2 Managed HSM Uses Local RBAC, Not Azure IAM

**The Finding:**
For Managed HSM, **Azure IAM roles don't work at all**. You must use the HSM's Local RBAC system (data-plane only).

**The Command:**
```bash
az keyvault role assignment create \
  --hsm-name <hsm-name> \
  --role "Managed HSM Crypto Officer" \
  --assignee-object-id <sp-object-id> \
  --assignee-principal-type ServicePrincipal \
  --scope "/"
```

**Why It's Different:**
Managed HSM is a dedicated hardware device with its own RBAC system, separate from Azure's management plane.

---

## 4. Network and DNS Gotchas

### 4.1 Why Two DNS Zones Are Required

**The Reason:**
Azure Key Vault uses different endpoints for different operations:
- `privatelink.vaultcore.azure.net` - Private Endpoint resolution
- `vault.azure.net` - Service endpoint resolution

**What Happens with Only One Zone:**
- Intermittent failures
- Some operations work, others don't
- No clear pattern

### 4.2 Azure Firewall Can Block Even with Correct DNS

**The Scenario:**
In environments with User Defined Routes forcing traffic through Azure Firewall:
- DNS resolves correctly to private IP ✅
- Connectivity still fails ❌

**The Cause:**
Firewall lacks explicit allow rule for the HSM/Key Vault FQDN.

**The Fix:**
Add Application Rule allowing Exascale subnet → `*.vault.azure.net` or `*.managedhsm.azure.net` on port 443.

### 4.3 Network ACL for HSM Needs More Privileges

**The Finding:**
For Standard Key Vault, `connect` privilege is sufficient.
For Managed HSM, you need: `resolve`, `http`, `connect`

**Impact if Missed:**
Subtle connection failures that don't occur with standard Key Vault.

---

## 5. Managed HSM Differences

### Key Differences from Standard Key Vault:

| Aspect | Standard Key Vault | Managed HSM |
|--------|-------------------|-------------|
| **Permission Model** | Access Policies or RBAC | Local RBAC only |
| **DNS Zones Required** | 2 zones | 4 zones total |
| **Network ACL Privileges** | `connect` | `resolve`, `http`, `connect` |
| **Health Endpoint** | `/healthstatus` exists | No health endpoint |
| **Private Endpoint** | `privatelink.vaultcore.azure.net` | `privatelink.managedhsm.azure.net` |
| **FQDN Pattern** | `*.vault.azure.net` | `*.managedhsm.azure.net` |

**Testing Recommendation:**
Test with Standard Key Vault first, then move to HSM once everything works.

---

## 6. Operational Limitations

### 6.1 24-Hour Rate Limit on Key Changes

**The Limitation:**
Oracle enforces **maximum 2 key changes per 24 hours** per database instance.

**Error Message:**
```
You cannot switch to a different customer-managed key more than 
two times in a 24-hour period. Try again later.
```

**Impact:**
- Blocks rapid testing of different key types
- Must plan key rotation tests across multiple days
- Or provision separate database instances per key type

**Why It Exists:**
Protection against accidental rapid key changes that could cause data access issues.

### 6.2 Re-encryption Duration

**Timing Observed:**

| Database Size | Re-encryption Time |
|--------------|-------------------|
| < 100 GB | 10-30 minutes |
| 100-500 GB | 30 min - 2 hours |
| > 1 TB | 4+ hours |

**Important:**
- Database remains ONLINE and AVAILABLE
- Applications can continue running
- Performance may be impacted during re-encryption

### 6.3 Private Endpoint URL for SQL Developer

**The Finding:**
When the database has `Public Access: Disabled`, the ORDS SQL Developer interface is only accessible via:
- **Private Endpoint URL** (from OCI Console)
- Must access from a VM within the VNet (e.g., Jump Box)

**Cannot Access:**
- Public OCI URL (even with VPN)
- From on-premises without Express Route

---

## 7. Key Compatibility Findings

### Tested Key Types (All Working):

| Key Type | Size/Curve | Production Ready |
|----------|-----------|------------------|
| RSA      | 2048      | ✅ Yes |
| RSA      | 3072      | ✅ Yes |
| RSA      | 4096      | ✅ Yes (Recommended) |
| EC       | P-256     | ✅ Yes |
| EC       | P-384     | ✅ Yes |
| EC       | P-521     | ✅ Yes |
| AES (HSM) | 128/256  | ⚠️ Unclear (HSM only) |

**Recommendation:**
Use **RSA-4096** for production environments for maximum compatibility and security.

**Not Tested:**
- RSA-HSM variants
- Software-protected EC keys
- AES-256 (HSM only; verify Exascale support)

---

## 8. Documentation Gaps

### What's Missing from Official Docs:

| Topic | Gap | Impact |
|-------|-----|--------|
| **OCI DNS Configuration** | Not mentioned at all | Guaranteed failure |
| **Two DNS Zones Requirement** | Only mentions privatelink zone | Intermittent failures |
| **Service Principal Behavior** | Doesn't warn about proliferation | Azure AD clutter |
| **Tenant ID vs Subscription ID** | Uses wrong ID in examples | OAuth flow fails |
| **RBAC vs Access Policies** | Doesn't distinguish | Hours of troubleshooting |
| **Managed HSM Local RBAC** | Not documented for Oracle Database@Azure use case | Permission denied errors |
| **Network ACL for HSM** | Missing privilege requirements | Subtle connection failures |
| **24-Hour Rate Limit** | Not mentioned in key rotation docs | Blocked testing |
| **`route_outbound_connections`** | Missing from early docs | Inconsistent behavior |

### Documentation Quality Issues:

**Microsoft Docs:**
- Generally good architecture overview
- Lacks OCI-specific steps
- Assumes Azure-only knowledge

**Oracle Docs:**
- Focuses on concepts, not procedures
- Missing critical configuration steps
- Examples sometimes use wrong values

**Combined:**
- No single source covers the full flow
- Must piece together from multiple sources
- Trial and error required

---

## 9. Best Practices Summary

### Before Starting:

1. ✅ **Verify regional support** for Advanced Networking
2. ✅ **Plan network topology** with all subnets and IP ranges
3. ✅ **Document everything** (IPs, IDs, FQDNs, client_ids)
4. ✅ **Provision in correct order** (Exascale → Key Vault → PE → DNS → OAuth → Key)

### During Implementation:

1. ✅ **Test progressively** after each major step
2. ✅ **Keep both consoles open** (Azure Portal + OCI Console)
3. ✅ **Leave public access enabled** on Key Vault during setup
4. ✅ **Verify DNS resolution FIRST** before any other tests
5. ✅ **Never skip the connectivity test** with `/healthstatus`

### Configuration:

1. ✅ **Use Access Policies**, not RBAC for Standard Key Vault
2. ✅ **Use Local RBAC** for Managed HSM (not Azure IAM)
3. ✅ **Configure ALL required DNS zones** (2 for AKV, 4 for HSM)
4. ✅ **Set route_outbound_connections** after successful tests
5. ✅ **Disable old Service Principals** before creating new ones

### Troubleshooting:

1. ✅ **DNS first** - If DNS resolves to public IP, stop and fix it
2. ✅ **Check network ACLs** - Different requirements for AKV vs HSM
3. ✅ **Verify correct Tenant ID** - Not Subscription ID
4. ✅ **Remove "www."** from consent URLs if present
5. ✅ **Check Azure Firewall** if DNS is correct but connectivity fails

---

## 10. What Would We Do Differently

### If Starting Over:

#### Planning Phase:

**Do First:**
- Create detailed network diagram with all IP ranges
- Create checklist with all required Azure resource IDs
- Set up Log Analytics workspace for diagnostics **before** starting
- Provision Jump Box VM for private endpoint access

**Don't:**
- Assume documentation is complete
- Skip DNS verification step
- Deploy to production without full non-prod testing

#### Implementation Phase:

**Do:**
- Test with Standard Key Vault before attempting HSM
- Use separate Exascale instances for testing different key types
- Script all Azure CLI commands for repeatability
- Take screenshots of every configuration screen
- Document every `client_id` and `object_id` immediately

**Don't:**
- Disable public access on Key Vault too early
- Re-run `ENABLE_PRINCIPAL_AUTH` without disabling first
- Assume RBAC will work (use Access Policies)
- Skip the connectivity test before enforcing private endpoints

#### Testing Phase:

**Do:**
- Create comprehensive test plan with validation queries
- Test key rotation process in non-prod first
- Monitor Azure diagnostics for actual traffic patterns
- Validate that `conn_type=PrivateLink` in responses

**Don't:**
- Test multiple key types rapidly (24-hour limit)
- Assume it works without checking wallet status
- Skip verification of encrypted tablespaces

### Time Estimates (Realistic):

| Phase | First Time | With This Guide |
|-------|-----------|-----------------|
| Planning | 4 hours | 2 hours |
| Azure Infrastructure | 2 hours | 1 hour |
| OCI DNS Configuration | 4 hours | 30 minutes |
| OAuth Setup | 3 hours | 30 minutes |
| Network ACL + Testing | 2 hours | 30 minutes |
| Key Configuration | 1 hour + re-encrypt time | 30 min + re-encrypt |
| Troubleshooting | 8+ hours | 1-2 hours |
| **Total** | **24+ hours** | **5-7 hours** |

**Re-encryption time**: Add 10 minutes to 4+ hours depending on database size.

---

## Key Takeaways

### The Top 5 Lessons:

1. **DNS configuration on OCI side is mandatory and undocumented** - This is the biggest gotcha. Budget time for this.

2. **Azure RBAC doesn't work - use Access Policies for AKV, Local RBAC for HSM** - Don't waste time trying to make RBAC work.

3. **Always disable Service Principal before re-enabling** - Prevents Azure AD clutter and confusion.

4. **Use Directory (Tenant) ID, not Subscription ID** - Oracle docs have this wrong.

5. **Test DNS resolution before everything else** - If this fails, nothing else will work.

### Success Criteria:

You know it's working when:

```sql
-- DNS resolves to private IP
SELECT utl_inaddr.get_host_address('your-kv.vault.azure.net') FROM dual;
-- Returns: 10.115.2.4 (your private IP)

-- Wallet configured correctly
SELECT wrl_type, wallet_type FROM V$ENCRYPTION_WALLET;
-- Returns: AZURE_KEY_VAULT, CLOUD

-- Connectivity test shows Private Link
-- Response header contains: conn_type=PrivateLink

-- Routing enforced
SELECT property_value FROM DATABASE_PROPERTIES 
WHERE property_name = 'ROUTE_OUTBOUND_CONNECTIONS';
-- Returns: enforce_private_endpoint
```

---

## References

**For detailed implementation procedures**: [Step-by-step.md](Step-by-step.md)

**Official Documentation:**
- [Oracle Exascale Security](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azusr-security-protect-autonomous-ai-database.html)
- [Microsoft: TDE with Azure Key Vault](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/manage-oracle-transparent-data-encryption-azure-key-vault)

**Related Files:**
- [Step-by-step.md](Step-by-step.md) - End-to-end implementation guide
- [DOCUMENTATION_GUIDE.md](DOCUMENTATION_GUIDE.md) - Architecture and configuration reference

---

**Document Purpose**: Capture lessons learned and gotchas discovered during implementation. For procedures and commands, see Step-by-step.md.

**Last Updated**: February 17, 2026  
**Test Environment**: Oracle Database@Azure, UK South region  
**Iterations**: 3 complete test cycles


