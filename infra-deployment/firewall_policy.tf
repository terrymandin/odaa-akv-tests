
# Firewall Policy with Azure Arc and Exascale rules
resource "azurerm_firewall_policy" "main" {
  name                     = "afwp-${var.location}-${random_integer.suffix.result}"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"

  explicit_proxy {
    enabled    = true
    http_port  = 9001
    https_port = 9002
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [ tags ]
  }
}

# Network Rule Collection Group for Exascale connectivity
resource "azurerm_firewall_policy_rule_collection_group" "network_rules" {
  name               = "DefaultNetworkRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 200

  network_rule_collection {
    name     = "ExascaleRuleCollection"
    priority = 900
    action   = "Allow"

    rule {
      name                  = "Allow-ODAA-to-Testing-Response"
      protocols             = ["TCP"]
      source_addresses      = ["10.100.0.0/16"]
      destination_addresses = ["10.200.0.0/16"]
      destination_ports     = ["*"]
    }

    rule {
      name                  = "Allow-Testing-to-ODAA-Request"
      protocols             = ["TCP"]
      source_addresses      = ["10.200.0.0/16"]
      destination_addresses = ["10.100.0.0/16"]
      destination_ports     = ["1521", "1522"]
    }
  }
}

# Network Rule Collection Group for Exascale connectivity
resource "azurerm_firewall_policy_rule_collection_group" "application_rules" {
  name               = "DefaultApplicationRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 300

  application_rule_collection {
    name     = "AzureArcRuleCollection"
    priority = 1000
    action   = "Allow"

    rule {
      name = "download.microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["download.microsoft.com"]
    }

    rule {
      name = "packages.microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["packages.microsoft.com"]
    }

    rule {
      name = "login.microsoftonline.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["login.microsoftonline.com"]
    }

    rule {
      name = "*.login.microsoftonline.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.login.microsoftonline.com"]
    }

    rule {
      name = "*.oracle.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.oracle.com"]
    }

    rule {
      name = "pas.windows.net"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["pas.windows.net"]
    }

    rule {
      name = "management.azure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["management.azure.com"]
    }

    rule {
      name = "*.his.arc.azure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.his.arc.azure.com"]
    }

    rule {
      name = "*.guestconfiguration.azure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.guestconfiguration.azure.com"]
    }

    rule {
      name = "*.guestnotificationservice.azure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.guestnotificationservice.azure.com"]
    }

    rule {
      name = "guestnotificationservice.azure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["guestnotificationservice.azure.com"]
    }

    rule {
      name = "*.servicebus.windows.net"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.servicebus.windows.net"]
    }

    rule {
      name = "*.waconazure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.waconazure.com"]
    }

    rule {
      name = "*.blob.core.windows.net"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.blob.core.windows.net"]
    }

    rule {
      name = "dc.services.visualstudio.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["dc.services.visualstudio.com"]
    }

    rule {
      name = "*.arcdataservices.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.arcdataservices.com"]
    }

    rule {
      name = "www.microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["www.microsoft.com"]
    }

    rule {
      name = "dls.microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["dls.microsoft.com"]
    }

    rule {
      name = "*.login.microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.login.microsoft.com"]
    }

    rule {
      name = "*.githubusercontent.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.githubusercontent.com"]
    }

    rule {
      name = "*.endpoint.security.microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.endpoint.security.microsoft.com"]
    }

    rule {
      name = "*.control.monitor.azure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.control.monitor.azure.com"]
    }

    rule {
      name = "*.opinsights.azure.com"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.opinsights.azure.com"]
    }
  }
}


