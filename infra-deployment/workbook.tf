# Azure Workbook for monitoring denied traffic in Azure Firewall
# This workbook provides visualization of blocked connections and denied rules

resource "azurerm_application_insights_workbook" "firewall_denied_traffic" {
  count = var.enable_log_analytics_logging ? 1 : 0

  name                = uuid()
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Azure Firewall - Denied Traffic Monitor"
  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "## Azure Firewall - Denied Traffic Analysis\n\nThis workbook shows all denied traffic by the Azure Firewall, including network rules and application rules that were blocked."
        }
        name = "text - header"
      },
      {
        type = 9
        content = {
          version = "KqlParameterItem/1.0"
          parameters = [
            {
              id         = "timerange-parameter"
              version    = "KqlParameterItem/1.0"
              name       = "TimeRange"
              label      = "Time Range"
              type       = 4
              isRequired = true
              value = {
                durationMs = 3600000
              }
              typeSettings = {
                selectableValues = [
                  {
                    durationMs            = 1800000
                    createdTime           = "2023-01-01T00:00:00.000Z"
                    isInitialTime         = false
                    grain                 = 1
                    useDashboardTimeRange = false
                  },
                  {
                    durationMs            = 3600000
                    createdTime           = "2023-01-01T00:00:00.000Z"
                    isInitialTime         = false
                    grain                 = 1
                    useDashboardTimeRange = false
                  },
                  {
                    durationMs            = 43200000
                    createdTime           = "2023-01-01T00:00:00.000Z"
                    isInitialTime         = false
                    grain                 = 1
                    useDashboardTimeRange = false
                  },
                  {
                    durationMs            = 86400000
                    createdTime           = "2023-01-01T00:00:00.000Z"
                    isInitialTime         = false
                    grain                 = 1
                    useDashboardTimeRange = false
                  },
                  {
                    durationMs            = 604800000
                    createdTime           = "2023-01-01T00:00:00.000Z"
                    isInitialTime         = false
                    grain                 = 1
                    useDashboardTimeRange = false
                  },
                  {
                    durationMs            = 2592000000
                    createdTime           = "2023-01-01T00:00:00.000Z"
                    isInitialTime         = false
                    grain                 = 1
                    useDashboardTimeRange = false
                  }
                ]
                allowCustom = true
              }
            }
          ]
          style        = "pills"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
        }
        name = "parameters - time range"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = "AzureDiagnostics\n| where TimeGenerated {TimeRange}\n| where Category == \"AzureFirewallApplicationRule\" or Category == \"AzureFirewallNetworkRule\"\n| where msg_s contains \"Deny\" or msg_s contains \"DENY\"\n| summarize DeniedCount = count() by bin(TimeGenerated, 1h)\n| render timechart"
          size                     = 0
          title                    = "Denied Traffic Over Time"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [
            azurerm_log_analytics_workspace.main[0].id
          ]
        }
        name = "query - denied traffic timeline"
      },
      {
        type = 1
        content = {
          json = "---\n### 📊 Detailed Traffic Analysis\nView the latest denied connections and analyze patterns. [Open in Log Analytics](https://portal.azure.com/#blade/Microsoft_Azure_Monitoring_Logs/LogsBlade/resourceId/%2Fsubscriptions%2F${data.azurerm_client_config.current.subscription_id}%2FresourceGroups%2F${azurerm_resource_group.main.name}%2Fproviders%2FMicrosoft.OperationalInsights%2Fworkspaces%2F${azurerm_log_analytics_workspace.main[0].name}/source/LogsBlade.AnalyticsShareLinkToQuery/q/AzureDiagnostics%0A%7C%20where%20Category%20%3D%3D%20%22AzureFirewallNetworkRule%22%20or%20Category%20%3D%3D%20%22AzureFirewallApplicationRule%22%0A%7C%20where%20msg_s%20contains%20%22Deny%22%20or%20msg_s%20contains%20%22DENY%22%0A%7C%20project%20TimeGenerated%2C%20Category%2C%20msg_s%0A%7C%20order%20by%20TimeGenerated%20desc%0A%7C%20take%20100)"
        }
        name = "text - log analytics link"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = "AzureDiagnostics\n| where TimeGenerated {TimeRange}\n| where Category == \"AzureFirewallNetworkRule\" or Category == \"AzureFirewallApplicationRule\"\n| where msg_s contains \"Deny\" or msg_s contains \"DENY\"\n| project TimeGenerated, Category, msg_s\n| order by TimeGenerated desc\n| take 100"
          size                     = 0
          title                    = "Latest 100 Denied Traffic Logs"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [
            azurerm_log_analytics_workspace.main[0].id
          ]
        }
        name = "query - latest denied logs"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = "AzureDiagnostics\n| where TimeGenerated {TimeRange}\n| where Category == \"AzureFirewallNetworkRule\"\n| where msg_s contains \"Deny\" or msg_s contains \"DENY\"\n| parse msg_s with * \"from \" SourceIP \":\" SourcePort \" to \" DestinationIP \":\" DestinationPort \". Action: \" Action \".\" *\n| where Action == \"Deny\"\n| summarize DeniedCount = count() by SourceIP, DestinationIP, DestinationPort\n| order by DeniedCount desc\n| take 50"
          size                     = 0
          title                    = "Top 50 Denied Network Connections"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [
            azurerm_log_analytics_workspace.main[0].id
          ]
        }
        name = "query - denied network rules"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = "AzureDiagnostics\n| where TimeGenerated {TimeRange}\n| where Category == \"AzureFirewallApplicationRule\"\n| where msg_s contains \"Deny\" or msg_s contains \"DENY\"\n| parse msg_s with * \"from \" SourceIP \":\" SourcePort \" to \" Fqdn \":\" DestinationPort \". Action: \" Action \".\" *\n| where Action == \"Deny\"\n| summarize DeniedCount = count() by SourceIP, Fqdn, DestinationPort\n| order by DeniedCount desc\n| take 50"
          size                     = 0
          title                    = "Top 50 Denied Application Requests (FQDNs)"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [
            azurerm_log_analytics_workspace.main[0].id
          ]
        }
        name = "query - denied application rules"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = "AzureDiagnostics\n| where TimeGenerated {TimeRange}\n| where Category == \"AzureFirewallNetworkRule\" or Category == \"AzureFirewallApplicationRule\"\n| where msg_s contains \"Deny\" or msg_s contains \"DENY\"\n| parse msg_s with * \"from \" SourceIP \":\" *\n| summarize DeniedCount = count() by SourceIP\n| order by DeniedCount desc\n| take 20\n| render piechart"
          size                     = 0
          title                    = "Top 20 Source IPs with Denied Traffic"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [
            azurerm_log_analytics_workspace.main[0].id
          ]
        }
        name = "query - source IPs"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = "AzureDiagnostics\n| where TimeGenerated {TimeRange}\n| where Category == \"AzureFirewallNetworkRule\"\n| where msg_s contains \"Deny\" or msg_s contains \"DENY\"\n| parse msg_s with * \"to \" DestinationIP \":\" DestinationPort \". Action: \" Action \".\" *\n| where Action == \"Deny\"\n| summarize DeniedCount = count() by DestinationPort\n| order by DeniedCount desc\n| take 20\n| render barchart"
          size                     = 0
          title                    = "Top 20 Denied Destination Ports"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [
            azurerm_log_analytics_workspace.main[0].id
          ]
        }
        name = "query - destination ports"
      }
    ]
    styleSettings  = {}
    fromTemplateId = "sentinel-UserWorkbook"
  })

  tags = var.tags
}
