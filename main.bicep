// ============================================================
// Main Bicep Orchestrator
// Coordinates the deployment of networking, compute, storage,
// monitoring, and backup resources through separate modules.
// ============================================================


// ------------------------------------------------------------
// Global Parameters
// Values used across multiple modules.
// ------------------------------------------------------------

// Uses the current resource group's Azure region by default.
param location string = resourceGroup().location

// Environment identifier used in resource naming.
param environment string = 'dev'

// Administrator public IP used to restrict management SSH access.
param adminPublicIp string

// Administrative username configured on both Linux VMs.
param adminUsername string = 'jdbroncos1'

// SSH public key used by the web VM.
param webSshPublicKey string

// VM size used for the web server.
param webVmSize string = 'Standard_D2als_v7'

// SSH public key used by the management VM.
param mgmtSshPublicKey string

// VM size used for the management server.
param mgmtVmSize string = 'Standard_D2als_v7'

// Email address used by the Azure Monitor Action Group.
param alertEmail string


// ------------------------------------------------------------
// Shared Variables
// Values referenced by modules or used for consistent naming.
// ------------------------------------------------------------


var webVmName = 'vm-web01-${environment}'


// ============================================================
// Network Module
// Deploys the VNet, subnets, and Network Security Groups.
// ============================================================

module network './modules/network.bicep' = {
  name: 'networkDeployment'

  params: {
    location: location
    environment: environment
    adminPublicIp: adminPublicIp
  }
}


// ============================================================
// Compute Module
// Deploys the web and management VMs, NICs, public IPs,
// SSH configuration, and NGINX web server configuration.
// ============================================================

module compute './modules/compute.bicep' = {
  name: 'computeDeployment'

  params: {
    location: location
    environment: environment
    adminUsername: adminUsername
    webSshPublicKey: webSshPublicKey
    webVmSize: webVmSize
    mgmtSshPublicKey: mgmtSshPublicKey
    mgmtVmSize: mgmtVmSize

    // Subnet IDs are provided by the network module.
    computeSubnetId: network.outputs.computeSubnetId
    managementSubnetId: network.outputs.managementSubnetId
  }
}


// ============================================================
// Storage Module
// Deploys private Blob Storage, container-scoped RBAC,
// Private Endpoint, and Private DNS integration.
// ============================================================

module storage './modules/storage.bicep' = {
  name: 'storageDeployment'

  params: {
    location: location
    environment: environment

    // Networking values supplied by the network module.
    vnetId: network.outputs.vnetId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId

    // Web VM information supplied by the compute module.
    webVmName: webVmName
    webVmPrincipalId: compute.outputs.webVmPrincipalId
  }
}


// ============================================================
// Monitoring Module
// Deploys Log Analytics, Azure Monitor Agent, DCR,
// Action Group, and the high CPU alert for the web VM.
// ============================================================

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoringDeployment'

  params: {
    location: location
    environment: environment
    alertEmail: alertEmail

    // Monitoring targets the web VM created by compute.bicep.
    webVmName: webVmName
    webVmId: compute.outputs.webVmId
  }
}


// ============================================================
// Backup Module
// Deploys the Recovery Services Vault, Enhanced backup policy,
// and backup protection for the web VM.
// ============================================================

module backup './modules/backup.bicep' = {
  name: 'backupDeployment'

  params: {
    location: location
    environment: environment

    // Backup protection targets the web VM created by compute.bicep.
    webVmName: webVmName
    webVmId: compute.outputs.webVmId
  }
}

// ============================================================
// Resource Group Delete Lock
// Prevents accidental deletion of the resource group and
// resources within it while still allowing normal changes.
// ============================================================

resource resourceGroupDeleteLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'lock-project1-delete'
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of the Project 1 resource group.'
  }
}

// ============================================================
// Resource Group Tags
// Applies organizational metadata to the Project 1 resource
// group for identification and management.
// ============================================================

resource resourceGroupTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'

  properties: {
    tags: {
      Environment: 'Development'
      Project: 'Project1'
      Workload: 'AzureEngineeringLab'
      Owner: 'Jacob'
    }
  }
}
