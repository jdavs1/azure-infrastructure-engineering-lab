// ============================================================
// Network Module
// Creates the virtual network, subnet layout, and Network
// Security Groups used by the compute and management workloads.
// ============================================================


// ------------------------------------------------------------
// Parameters
// Values passed into this module from main.bicep.
// ------------------------------------------------------------

param location string
param environment string
param adminPublicIp string


// ------------------------------------------------------------
// Resource Naming
// Builds consistent names for the VNet and NSGs.
// ------------------------------------------------------------

var vnetName = 'vnet-project1-${environment}'
var computeNsgName = 'nsg-compute-${environment}'
var managementNsgName = 'nsg-management-${environment}'


// ============================================================
// Management NSG
// Restricts inbound SSH access to the administrator's
// explicitly allowed public IP address.
// ============================================================

resource managementNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: managementNsgName
  location: location

  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-MyIP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'

          // Only allows SSH from the administrator's public IP.
          sourceAddressPrefix: '${adminPublicIp}/32'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}


// ============================================================
// Compute NSG
// Controls inbound traffic to the web/compute subnet.
// Public web traffic is allowed, while SSH is restricted to
// the management subnet.
// ============================================================

resource computeNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: computeNsgName
  location: location

  properties: {
    securityRules: [
      {
        // Allows public HTTP traffic.
        name: 'Allow-HTTP-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        // Allows public HTTPS traffic.
        name: 'Allow-HTTPS-Internet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        // Allows SSH only from the management subnet.
        name: 'Allow-SSH-Management'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.2.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        // Blocks other inbound traffic originating from the VNet.
        name: 'Deny-Other-VNet-Inbound'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}


// ============================================================
// Virtual Network
// Creates the address space and separates workloads into
// compute, management, and private endpoint subnets.
// ============================================================

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location

  properties: {
    privateEndpointVNetPolicies: 'Disabled'

    // Overall VNet address space.
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }

    subnets: [
      {
        // Hosts the public-facing web/compute workload.
        name: 'ComputeResources'
        properties: {
          addressPrefix: '10.0.1.0/24'

          networkSecurityGroup: {
            id: computeNsg.id
          }
        }
      }
      {
        // Hosts the management VM used for administrative access.
        name: 'ManagementResources'
        properties: {
          addressPrefix: '10.0.2.0/24'

          networkSecurityGroup: {
            id: managementNsg.id
          }
        }
      }
      {
        // Dedicated subnet for Azure Private Endpoints.
        name: 'PrivateEndpoints'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }
}


// ------------------------------------------------------------
// Outputs
// Makes the VNet and subnet IDs available to other modules.
// ------------------------------------------------------------

output vnetId string = vnet.id
output vnetName string = vnet.name
output computeSubnetId string = vnet.properties.subnets[0].id
output managementSubnetId string = vnet.properties.subnets[1].id
output privateEndpointSubnetId string = vnet.properties.subnets[2].id
