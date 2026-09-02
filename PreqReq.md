## Prerequisites

This deployment guide assumes you are using **Windows 10 or Windows 11 with PowerShell**.

Before deploying the lab, install the following tools:

- Git
- Azure CLI
- Bicep
- OpenSSH Client

### 1. Verify Winget

The commands below use Windows Package Manager (`winget`).

```powershell
winget --version
```

If a version number is returned, continue to the next step.

---

### 2. Install Git

Check whether Git is already installed:

```powershell
git --version
```

If Git is not installed:

```powershell
winget install --id Git.Git -e
```

Close and reopen PowerShell after installation.

Verify:

```powershell
git --version
```

---

### 3. Install Azure CLI

Check whether Azure CLI is installed:

```powershell
az version
```

If Azure CLI is not installed:

```powershell
winget install --id Microsoft.AzureCLI -e
```

Close and reopen PowerShell after installation.

Verify:

```powershell
az version
```

---

### 4. Install Bicep

Bicep can be installed through Azure CLI.

Check whether Bicep is already installed:

```powershell
az bicep version
```

If Bicep is not installed:

```powershell
az bicep install
```

Verify:

```powershell
az bicep version
```

---

### 5. Verify OpenSSH

Check whether the Windows OpenSSH client is available:

```powershell
ssh -V
```

OpenSSH is included with most modern Windows installations.

If the `ssh` command is unavailable, install the OpenSSH Client from an Administrator PowerShell window:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

Then verify:

```powershell
ssh -V
```

---

### Verify Everything

Before continuing, the following commands should all return version information without errors:

```powershell
git --version
az version
az bicep version
ssh -V
```

Once these tools are installed, the environment is ready to begin the Azure deployment process.
