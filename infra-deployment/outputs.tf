# Output values for the infrastructure deployment

output "random_values" {
  description = "Random values generated for resource naming"
  value = {
    suffix = random_integer.suffix.result
  }
}

output "resource_group" {
  description = "Resource group information"
  value = {
    id       = azurerm_resource_group.main.id
    name     = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
  }
}

output "autonomous_database" {
  description = "Oracle Autonomous Database details (legacy output; not used in Exascale-only deployment)"
  value       = null
}

output "exascale_storage_vault" {
  description = "Oracle Exascale DB Storage Vault details (null when deploy_exascale = false)"
  value = var.deploy_exascale ? {
    id           = azapi_resource.exascale_storage_vault[0].id
    name         = azapi_resource.exascale_storage_vault[0].name
    display_name = azapi_resource.exascale_storage_vault[0].output.properties.displayName
    location     = azurerm_resource_group.main.location
  } : null
}

output "exascale_vm_cluster" {
  description = "Oracle Exascale Cloud VM Cluster details (null when deploy_exascale = false)"
  value = var.deploy_exascale ? {
    id            = azapi_resource.exascale_vm_cluster[0].id
    name          = azapi_resource.exascale_vm_cluster[0].name
    display_name  = azapi_resource.exascale_vm_cluster[0].output.properties.displayName
    location      = azurerm_resource_group.main.location
    hostname      = azapi_resource.exascale_vm_cluster[0].output.properties.hostname
    scan_dns_name = azapi_resource.exascale_vm_cluster[0].output.properties.scanDnsName
    gi_version    = azapi_resource.exascale_vm_cluster[0].output.properties.giVersion
    license_model = azapi_resource.exascale_vm_cluster[0].output.properties.licenseModel
    subnet_id     = azapi_resource.exascale_vm_cluster[0].output.properties.subnetId
  } : null
}

output "managed_hsm" {
  description = "Managed HSM details (when deployed)"
  value = var.deploy_managed_hsm ? {
    id                = azurerm_key_vault_managed_hardware_security_module.mhsm[0].id
    name              = azurerm_key_vault_managed_hardware_security_module.mhsm[0].name
    hsm_uri           = azurerm_key_vault_managed_hardware_security_module.mhsm[0].hsm_uri
    resource_group    = azurerm_resource_group.main.name
    location          = azurerm_resource_group.main.location
  } : null
}



output "useful_info" {
  description = "Info for configuring Oracle database with AKV"
  value = {
    rg_name                = azurerm_resource_group.main.name
    vnet_name              = azurerm_virtual_network.main.name
    vnet_address_space     = azurerm_virtual_network.main.address_space
    vm_name                = var.deploy_jumpbox_vm ? azurerm_windows_virtual_machine.jumpbox[0].name : null
    vm_admin_username      = var.deploy_jumpbox_vm ? azurerm_windows_virtual_machine.jumpbox[0].admin_username : null
    vm_public_ip_address   = var.deploy_jumpbox_vm ? azurerm_public_ip.jumpbox[0].ip_address : null
    vm_fqdn                = var.deploy_jumpbox_vm ? azurerm_public_ip.jumpbox[0].fqdn : null
    akv_uri                = azurerm_key_vault.main.vault_uri
    akv_name               = azurerm_key_vault.main.name
    akv_private_ip_address = azurerm_private_endpoint.keyvault.private_service_connection[0].private_ip_address

    fw_public_ip_address  = azurerm_public_ip.firewall.ip_address
    fw_private_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
    subscription_id       = data.azurerm_client_config.current.subscription_id
    tenant_id             = data.azurerm_client_config.current.tenant_id
    my_ip_address         = var.deploy_jumpbox_vm ? data.http.my_public_ip[0].response_body : null

    # Deployment mode
    deploy_mode = "Exascale"

    # Exascale connection endpoint
    exascale_scan_dns_name = var.deploy_exascale ? azapi_resource.exascale_vm_cluster[0].output.properties.scanDnsName : null

    # HSM URI (when HSM was deployed)
    mhsm_uri = var.deploy_managed_hsm ? azurerm_key_vault_managed_hardware_security_module.mhsm[0].hsm_uri : ""
  }
}