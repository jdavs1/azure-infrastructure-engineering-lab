// ============================================================
// Backup Module
// Creates a Recovery Services Vault, defines an Enhanced VM
// backup policy, and protects the web VM with that policy.
// ============================================================


// ------------------------------------------------------------
// Parameters
// Values passed into this module from main.bicep.
// ------------------------------------------------------------

param location string
param environment string
param webVmName string
param webVmId string


// ------------------------------------------------------------
// Resource Naming
// Builds consistent resource names using the environment value.
// ------------------------------------------------------------

var recoveryServicesVaultName = 'rsv-project1-${environment}'
var enhancedBackupPolicyName = 'policy-web-enhanced-${environment}'

// Azure Backup fabric used for Azure-hosted virtual machines.
var backupFabricName = 'Azure'

// Required Azure Backup naming format for the VM protection
// container and protected item.
var webVmProtectionContainerName = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${webVmName}'
var webVmProtectedItemName = 'VM;iaasvmcontainerv2;${resourceGroup().name};${webVmName}'


// ============================================================
// Recovery Services Vault
// Central resource used to manage VM backups and recovery points.
// ============================================================

resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2025-08-01' = {
  name: recoveryServicesVaultName
  location: location

  sku: {
    name: 'RS0'
    tier: 'Standard'
  }

  properties: {
    publicNetworkAccess: 'Enabled'

    // Uses locally redundant storage for backup data.
    // Cross-region restore is disabled for this lab environment.
    redundancySettings: {
      standardTierStorageRedundancy: 'LocallyRedundant'
      crossRegionRestore: 'Disabled'
    }
  }
}


// ============================================================
// Enhanced VM Backup Policy
// Defines when the VM is backed up and how long recovery points
// are retained.
// ============================================================

resource enhancedVmBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2025-08-01' = {
  parent: recoveryServicesVault
  name: enhancedBackupPolicyName

  properties: {
    backupManagementType: 'AzureIaasVM'
    policyType: 'V2'

    // Keeps instant recovery snapshots available for seven days.
    instantRpRetentionRangeInDays: 7

    // Runs the backup once per day at 10:00 UTC.
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'

      dailySchedule: {
        scheduleRunTimes: [
          '2026-01-01T10:00:00Z'
        ]
      }
    }

    // Retains daily recovery points for 30 days.
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'

      dailySchedule: {
        retentionTimes: [
          '2026-01-01T10:00:00Z'
        ]

        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
    }

    // Uses crash-consistent snapshots for the protected VM.
    snapshotConsistencyType: 'OnlyCrashConsistent'
    timeZone: 'UTC'
  }
}


// ============================================================
// VM Backup Protection
// Associates the web VM with the Recovery Services Vault and
// Enhanced backup policy.
// ============================================================

resource webVmBackupProtection 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2025-08-01' = {
  name: '${recoveryServicesVault.name}/${backupFabricName}/${webVmProtectionContainerName}/${webVmProtectedItemName}'

  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: enhancedVmBackupPolicy.id
    sourceResourceId: webVmId
  }
}


// ------------------------------------------------------------
// Outputs
// Makes key backup resource names available to other modules
// or the parent deployment.
// ------------------------------------------------------------

output recoveryServicesVaultName string = recoveryServicesVault.name
output backupPolicyName string = enhancedVmBackupPolicy.name
