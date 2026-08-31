using './main.bicep'

// Required PowerShell environment variables:
// $env:PROJECT1_ADMIN_IP
// $env:PROJECT1_WEB_SSH_KEY
// $env:PROJECT1_MGMT_SSH_KEY
// $env:PROJECT1_ALERT_EMAIL

// Example setup in PowerShell:
//
// $env:PROJECT1_ADMIN_IP = "192.1.1.1"
// $env:PROJECT1_WEB_SSH_KEY = (Get-Content "$HOME\.ssh\project1-iac.pub" -Raw).Trim()
// $env:PROJECT1_MGMT_SSH_KEY = (Get-Content "$HOME\.ssh\project1-iac-mgmt.pub" -Raw).Trim()
// $env:PROJECT1_ALERT_EMAIL = "your-email@example.com"

param adminPublicIp = readEnvironmentVariable('PROJECT1_ADMIN_IP')
param webSshPublicKey = readEnvironmentVariable('PROJECT1_WEB_SSH_KEY')
param mgmtSshPublicKey = readEnvironmentVariable('PROJECT1_MGMT_SSH_KEY')
param alertEmail = readEnvironmentVariable('PROJECT1_ALERT_EMAIL')

// Deploy with:
// az deployment group create --name project1-deployment --resource-group rg-project1-iac-test --parameters main.dev.bicepparam
