// ============================================================
// Compute Module
// Deploys the web VM and management VM, including their
// public IPs, NICs, SSH configuration, Trusted Launch settings,
// and the NGINX configuration for the web server.
// ============================================================


// ------------------------------------------------------------
// Parameters
// Values passed into this module from main.bicep.
// ------------------------------------------------------------

param location string
param environment string
param adminUsername string

param webSshPublicKey string
param webVmSize string

param mgmtSshPublicKey string
param mgmtVmSize string

param computeSubnetId string
param managementSubnetId string


// ------------------------------------------------------------
// Resource Naming
// Builds consistent names for web and management resources.
// ------------------------------------------------------------

var webVmName = 'vm-web01-${environment}'
var webPublicIpName = '${webVmName}-ip'
var webNicName = '${webVmName}-nic'

var mgmtVmName = 'vm-mgmt01-${environment}'
var mgmtPublicIpName = '${mgmtVmName}-ip'
var mgmtNicName = '${mgmtVmName}-nic'


// ============================================================
// Web VM Networking
// Creates the public IP and NIC used by the web server VM.
// ============================================================

resource webPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: webPublicIpName
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource webNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: webNicName
  location: location

  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'

        properties: {
          privateIPAllocationMethod: 'Dynamic'

          // Places the web VM NIC in the compute subnet.
          subnet: {
            id: computeSubnetId
          }

          publicIPAddress: {
            id: webPublicIp.id
          }
        }
      }
    ]
  }
}


// ============================================================
// Web VM
// Ubuntu VM that hosts the project's NGINX web server.
// Uses SSH authentication, Trusted Launch, and a system-assigned
// managed identity for access to other Azure resources.
// ============================================================

resource webVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: webVmName
  location: location

  // Provides the VM with an Azure-managed identity.
  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    hardwareProfile: {
      vmSize: webVmSize
    }

    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'

        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }

    osProfile: {
      computerName: webVmName
      adminUsername: adminUsername

      linuxConfiguration: {
        // Password authentication is disabled in favor of SSH keys.
        disablePasswordAuthentication: true

        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: webSshPublicKey
            }
          ]
        }
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: webNic.id
        }
      ]
    }

    // Trusted Launch provides Secure Boot and virtual TPM.
    securityProfile: {
      securityType: 'TrustedLaunch'

      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}


// ============================================================
// Management VM Networking
// Creates the public IP and NIC used by the management VM.
// ============================================================

resource mgmtPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: mgmtPublicIpName
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource mgmtNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: mgmtNicName
  location: location

  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'

        properties: {
          privateIPAllocationMethod: 'Dynamic'

          // Places the management VM NIC in the management subnet.
          subnet: {
            id: managementSubnetId
          }

          publicIPAddress: {
            id: mgmtPublicIp.id
          }
        }
      }
    ]
  }
}


// ============================================================
// Management VM
// Ubuntu VM used as the controlled SSH entry point for
// administration of internal resources such as the web VM.
// ============================================================

resource mgmtVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: mgmtVmName
  location: location

  properties: {
    hardwareProfile: {
      vmSize: mgmtVmSize
    }

    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'

        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }

    osProfile: {
      computerName: mgmtVmName
      adminUsername: adminUsername

      linuxConfiguration: {
        // Password authentication is disabled in favor of SSH keys.
        disablePasswordAuthentication: true

        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: mgmtSshPublicKey
            }
          ]
        }
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: mgmtNic.id
        }
      ]
    }

    // Trusted Launch provides Secure Boot and virtual TPM.
    securityProfile: {
      securityType: 'TrustedLaunch'

      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}


// ============================================================
// Web Server Configuration
// Uses the Azure Custom Script extension to install NGINX,
// enable the service, and deploy a simple project landing page.
// ============================================================

resource webConfig 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: webVm
  name: 'configure-web'
  location: location

  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true

    settings: {
      commandToExecute: 'bash -c "apt-get update && apt-get install -y nginx && systemctl enable nginx && systemctl start nginx && rm -f /var/www/html/index.html* && echo \'<h1>Project 1 - Bicep Deployment</h1><p>Deployed automatically with Azure Bicep.</p>\' > /var/www/html/index.html"'
    }
  }
}


// ------------------------------------------------------------
// Outputs
// Makes key VM resource IDs, names, and identity information
// available to main.bicep and other modules.
// ------------------------------------------------------------

output webVmId string = webVm.id
output webVmPrincipalId string = webVm.identity.principalId
output webVmName string = webVm.name
output webPublicIpId string = webPublicIp.id

output mgmtVmId string = mgmtVm.id
output mgmtVmName string = mgmtVm.name
output mgmtPublicIpId string = mgmtPublicIp.id
