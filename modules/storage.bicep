// ============================================================
// Storage Module
// Creates the Storage Account, private Blob container,
// RBAC assignment, Private Endpoint, and Private DNS
// configuration used by the web VM.
// ============================================================


// ------------------------------------------------------------
// Parameters
// Values passed into this module from main.bicep.
// ------------------------------------------------------------

param location string
param environment string
param vnetId string
param privateEndpointSubnetId string
param webVmName string
param webVmPrincipalId string


// ------------------------------------------------------------
// Resource Naming and Role IDs
// Builds consistent resource names and defines the built-in
// Storage Blob Data Reader role used by the web VM.
// ------------------------------------------------------------

var storageAccountName = 'stproject1${uniqueString(resourceGroup().id)}'
var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var privateEndpointName = 'pe-storage-blob-${environment}'
var privateDnsZoneName = 'privatelink.blob.${az.environment().suffixes.storage}'
var vnetName = 'vnet-project1-${environment}'


// ============================================================
// Storage Account
// Creates the project's StorageV2 account with public network
// access disabled and secure transport requirements enabled.
// ============================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location

  sku: {
    name: 'Standard_LRS'
  }

  kind: 'StorageV2'

  properties: {
    // Requires HTTPS and TLS 1.2 for supported connections.
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'

    // Prevents anonymous Blob access and blocks public network access.
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
  }
}


// ============================================================
// Blob Service
// Creates the default Blob service under the Storage Account.
// ============================================================

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}


// ============================================================
// Blob Container
// Creates the private container used by the project.
// ============================================================

resource projectContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'project1-data'

  properties: {
    // Prevents anonymous public access to container data.
    publicAccess: 'None'
  }
}


// ============================================================
// Storage RBAC Assignment
// Grants the web VM's managed identity read-only access to
// Blob data within the project container.
// ============================================================

resource blobReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    projectContainer.id,
    resourceId('Microsoft.Compute/virtualMachines', webVmName),
    storageBlobDataReaderRoleId
  )

  // Limits the RBAC assignment to this specific container.
  scope: projectContainer

  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataReaderRoleId
    )

    principalId: webVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}


// ============================================================
// Private DNS Zone
// Provides private DNS resolution for Azure Blob Storage
// Private Endpoints inside the VNet.
// ============================================================

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}


// ============================================================
// Private DNS VNet Link
// Links the private Blob DNS zone to the project VNet so
// resources inside the VNet can resolve Storage privately.
// ============================================================

resource blobDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: blobPrivateDnsZone
  name: 'link-${vnetName}'
  location: 'global'

  properties: {
    registrationEnabled: false

    virtualNetwork: {
      id: vnetId
    }
  }
}


// ============================================================
// Storage Private Endpoint
// Creates a private network interface for the Blob service
// inside the dedicated PrivateEndpoints subnet.
// ============================================================

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateEndpointName
  location: location

  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }

    privateLinkServiceConnections: [
      {
        name: 'blob-connection'

        properties: {
          privateLinkServiceId: storageAccount.id

          // Connects specifically to the Storage Blob service.
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}


// ============================================================
// Private DNS Zone Group
// Associates the Blob Private Endpoint with the private DNS
// zone so the Storage hostname resolves to its private IP.
// ============================================================

resource storagePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: storagePrivateEndpoint
  name: 'default'

  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-dns-config'

        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}


// ------------------------------------------------------------
// Outputs
// Makes the Storage Account name and resource ID available
// to the parent deployment or other modules.
// ------------------------------------------------------------

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
