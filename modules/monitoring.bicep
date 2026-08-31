// ============================================================
// Monitoring Module
// Configures centralized logging, Linux syslog collection,
// Azure Monitor Agent, alerting, and email notifications
// for the web VM.
// ============================================================


// ------------------------------------------------------------
// Parameters
// Values passed into this module from main.bicep.
// ------------------------------------------------------------

param location string
param environment string
param alertEmail string
param webVmName string
param webVmId string


// ------------------------------------------------------------
// Resource Naming
// Builds consistent names for monitoring resources.
// ------------------------------------------------------------

var logAnalyticsName = 'law-project1-${environment}'
var dcrName = 'dcr-linux-project1-${environment}'
var actionGroupName = 'ag-project1-${environment}'
var highCpuAlertName = 'alert-highcpu-web01-${environment}'


// ============================================================
// Existing Web VM Reference
// References the web VM created by the compute module so that
// monitoring resources can be attached to it.
// ============================================================

resource webVmExisting 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: webVmName
}


// ============================================================
// Log Analytics Workspace
// Central destination for logs collected from the web VM.
// ============================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location

  properties: {
    // Retains collected logs for 30 days.
    retentionInDays: 30

    sku: {
      name: 'PerGB2018'
    }
  }
}


// ============================================================
// Data Collection Rule
// Defines which Linux syslog events are collected and sends
// them to the Log Analytics workspace.
// ============================================================

resource dcr 'Microsoft.Insights/dataCollectionRules@2024-03-11' = {
  name: dcrName
  location: location

  properties: {
    dataSources: {
      syslog: [
        {
          name: 'linux-syslog'

          // Collects authentication and daemon-related logs.
          facilityNames: [
            'auth'
            'authpriv'
            'daemon'
          ]

          // Collects warning-level events and anything more severe.
          logLevels: [
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]

          streams: [
            'Microsoft-Syslog'
          ]
        }
      ]
    }

    // Sends collected data to the Log Analytics workspace.
    destinations: {
      logAnalytics: [
        {
          name: 'lawDestination'
          workspaceResourceId: logAnalytics.id
        }
      ]
    }

    // Connects the syslog stream to the Log Analytics destination.
    dataFlows: [
      {
        streams: [
          'Microsoft-Syslog'
        ]

        destinations: [
          'lawDestination'
        ]
      }
    ]
  }
}


// ============================================================
// Azure Monitor Agent
// Installs the Azure Monitor Agent on the web VM so the DCR
// can collect and forward monitoring data.
// ============================================================

resource azureMonitorAgent 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: webVmExisting
  name: 'AzureMonitorLinuxAgent'
  location: location

  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}


// ============================================================
// DCR Association
// Associates the web VM with the Linux Data Collection Rule.
// ============================================================

resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2024-03-11' = {
  scope: webVmExisting
  name: 'web01-dcr-association'

  properties: {
    dataCollectionRuleId: dcr.id
  }
}


// ============================================================
// Action Group
// Defines the notification destination used when an alert fires.
// ============================================================

resource actionGroup 'Microsoft.Insights/actionGroups@2021-09-01' = {
  name: actionGroupName
  location: 'global'

  properties: {
    groupShortName: 'Project1Dev'
    enabled: true

    emailReceivers: [
      {
        name: 'Project1Email'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}


// ============================================================
// High CPU Alert
// Monitors the web VM CPU and sends an alert through the
// Action Group when average CPU exceeds the configured threshold.
// ============================================================

resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: highCpuAlertName
  location: 'global'

  properties: {
    description: 'Alerts when vm-web01-dev average CPU exceeds 80 percent.'
    severity: 2
    enabled: true
    autoMitigate: true

    // Monitors the web VM created by the compute module.
    scopes: [
      webVmId
    ]

    // Evaluates the metric every minute over a five-minute window.
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'

    targetResourceType: 'Microsoft.Compute/virtualMachines'
    targetResourceRegion: location

    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'

      allOf: [
        {
          name: 'HighCPU'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'Percentage CPU'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          operator: 'GreaterThan'

          // Alert when average CPU is greater than 80 percent.
          threshold: 80
          timeAggregation: 'Average'
          dimensions: []
        }
      ]
    }

    // Sends triggered alerts to the configured Action Group.
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}


// ------------------------------------------------------------
// Outputs
// Makes key monitoring resource information available to the
// parent deployment or other modules.
// ------------------------------------------------------------

output logAnalyticsName string = logAnalytics.name
output logAnalyticsId string = logAnalytics.id
output actionGroupId string = actionGroup.id
output highCpuAlertName string = highCpuAlert.name
