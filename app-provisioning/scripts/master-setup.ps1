<#
master-setup.ps1
Run as Administrator.
#>

Set-StrictMode -Version Latest

function Assert-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Please run this script from an elevated (Administrator) PowerShell."
        exit 1
    }
}

Assert-Admin

# --------- User-configurable values ----------
$ExternalDriveLetter = "D"                     # Change if your external NVMe is different
$WSL_ExportPath = "$($ExternalDriveLetter):\WSL" # Folder on external drive where WSL images will live
$WslMemory = "12GB"
$WslProcessors = 4
$WslSwap = "8GB"
# --------------------------------------------

Write-Host "Starting master setup..." -ForegroundColor Cyan

# ----------------- Enable windows features -----------------
Write-Host "Enabling WSL and Virtual Machine features..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
# Optional Hyper-V
dism.exe /online /enable-feature /featurename:HypervisorPlatform /all /norestart | Out-Null

# ----------------- Install or update WSL -----------------
Write-Host "Installing WSL and default distro(s)..."
wsl --install 2>$null

# Install specific distros (Ubuntu + Kali). If already installed this will be skipped with an error; that's okay.
try {
    wsl --install -d Ubuntu 2>$null
} catch { Write-Host "Ubuntu may already be installed or requires a reboot." -ForegroundColor Yellow }

try {
    wsl --install -d kali-linux 2>$null
} catch { Write-Host "Kali may already be installed or requires a reboot." -ForegroundColor Yellow }

# ----------------- Write .wslconfig -----------------
$wslconfigPath = "$env:USERPROFILE\.wslconfig"
$wslConfigContent = @"
[wsl2]
memory=$WslMemory
processors=$WslProcessors
swap=$WslSwap
swapFile=${ExternalDriveLetter}:\\WSL\\swap.vhdx
localhostForwarding=true
guiApplications=true
pageReporting=false
nestedVirtualization=true
"@
Write-Host "Writing .wslconfig to $wslconfigPath"
$wslConfigContent | Out-File -FilePath $wslconfigPath -Encoding UTF8

# Create external WSL folder
if (-not (Test-Path -Path "$WSL_ExportPath")) {
    Write-Host "Creating external WSL folder at $WSL_ExportPath"
    New-Item -ItemType Directory -Path $WSL_ExportPath -Force | Out-Null
}

# ----------------- Debloat — safe removals -----------------
Write-Host "Removing common built-in apps (safe list)..."
$removeApps = @(
    "*Xbox*",
    "*3DBuilder*",
    "*ZuneMusic*",
    "*ZuneVideo*",
    "*MicrosoftSolitaireCollection*",
    "*Microsoft.BingNews*",
    "*Microsoft.GetHelp*",
    "*Microsoft.Getstarted*"
)
foreach ($pattern in $removeApps) {
    Get-AppxPackage -Name $pattern -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $pattern | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName } 2>$null
}

# Disable hibernation (saves disk, improves sleep handling)
Write-Host "Disabling hibernation..."
powercfg -h off

# Performance registry tweaks
Write-Host "Applying registry performance tweaks..."
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SystemResponsiveness /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v WaitToKillServiceTimeout /t REG_SZ /d 2000 /f

# ----------------- Install winget packages (Docker Desktop, VSCode, Git) -----------------
Write-Host "Installing essential applications via winget (Docker Desktop, VS Code, Git)..."
try {
    winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
    winget install --id Microsoft.VisualStudioCode -e --accept-package-agreements --accept-source-agreements
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
} catch {
    Write-Host "winget install encountered an error. Please install Docker Desktop, VSCode, and Git manually via https://winget.run or their sites." -ForegroundColor Yellow
}

# ----------------- Install PowerShell modules for cloud automation -----------------
Write-Host "Installing PowerShell modules: Az, Microsoft.Graph, PartnerCenter (may ask for NuGet provider)..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
Install-Module -Name Az -Repository PSGallery -Force -Scope AllUsers
Install-Module -Name Microsoft.Graph -Repository PSGallery -Force -Scope AllUsers
try {
    Install-Module -Name PartnerCenter -Repository PSGallery -Force -Scope AllUsers -ErrorAction Stop
} catch {
    Write-Host "PartnerCenter module not available via PSGallery in your environment; you'll be able to use the Partner Center REST APIs or Microsoft.Graph for many tasks." -ForegroundColor Yellow
}

# ----------------- Generate SSH Key for GitHub / Azure -----------------
$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
$sshKeyPath = "$sshDir\id_ed25519"
if (-not (Test-Path $sshKeyPath)) {
    Write-Host "Generating ed25519 SSH keypair for GitHub/Azure..."
    ssh-keygen -t ed25519 -f $sshKeyPath -C "$env:USERNAME@$(hostname)" -N "" | Out-Null
    Write-Host "SSH public key:"
    Get-Content "$sshKeyPath.pub"
} else {
    Write-Host "SSH key already exists at $sshKeyPath"
}

# ----------------- Create WSL init script file to drop into new distros -----------------
$wslInitPathWin = "$env:USERPROFILE\Downloads\wsl-init.sh"
$wslInitContent = @"
#!/bin/bash
set -e

# This script is intended to be run inside WSL (Ubuntu or Kali) by the user.
# It installs common dev stacks and applies performance tweaks.

sudo apt update && sudo apt upgrade -y

sudo apt install -y git build-essential curl wget unzip zip apt-transport-https ca-certificates gnupg lsb-release

# Dotnet (Debian/Ubuntu placeholder; check versions & repo for your distro)
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb || true
sudo dpkg -i packages-microsoft-prod.deb || true
sudo apt update
sudo apt install -y dotnet-sdk-8.0 || true

# Node (using distro packages for simplicity)
sudo apt install -y nodejs npm || true

# Python
sudo apt install -y python3 python3-pip || true

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash || true

# GitHub CLI
type -p curl >/dev/null || sudo apt install -y curl
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh || true

# Docker Engine in WSL (optional: Docker Desktop integrates with WSL on the Windows side)
sudo apt install -y docker.io || true
sudo usermod -aG docker \$USER || true

# Dev Containers CLI
sudo apt install -y npm
sudo npm install -g @devcontainers/cli || true

# Performance tuning inside WSL
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p || true

echo "WSL init complete. Reboot WSL with: wsl --shutdown (run from Windows), then launch your distro."
"@
$wslInitContent | Out-File -FilePath $wslInitPathWin -Encoding UTF8
# Make copies to external drive (if exists)
try {
    Copy-Item $wslInitPathWin -Destination "$WSL_ExportPath\wsl-init.sh" -Force -ErrorAction SilentlyContinue
} catch { }

# ----------------- Create helper scripts for exporting/importing WSL to external drive -----------------
$exportScript = @"
# Export WSL distro to external drive.
# Usage: Run from PowerShell (Admin).
param(
    [string]`$distro = 'Ubuntu',
    [string]`$outPath = '${WSL_ExportPath}\`$distro.tar'
)
wsl --export `$distro `$outPath
Write-Host "Exported `$distro to `$outPath"
"@
$exportScriptPath = "$env:USERPROFILE\Downloads\wsl-export.ps1"
$exportScript | Out-File -FilePath $exportScriptPath -Encoding UTF8

$importScript = @"
# Import WSL distro from external drive to a new installation path on external drive.
# Usage: Run from PowerShell (Admin).
param(
    [string]`$distro = 'Ubuntu',
    [string]`$installPath = '${WSL_ExportPath}\RootFS',
    [string]`$tarPath = '${WSL_ExportPath}\Ubuntu.tar'
)
if (-not (Test-Path -Path `$installPath)) { mkdir `$installPath -Force | Out-Null }
wsl --import `$distro `$installPath `$tarPath --version 2
Write-Host "Imported `$distro to `$installPath"
"@
$importScriptPath = "$env:USERPROFILE\Downloads\wsl-import.ps1"
$importScript | Out-File -FilePath $importScriptPath -Encoding UTF8

# Provide a one-line helper to import and set swapFile location if using external drive
$swapHelper = "Note: swap.vhdx will be created automatically when WSL needs swap. `.wslconfig` points to ${ExternalDriveLetter}:\WSL\swap.vhdx"

Write-Host "Master setup actions completed. You should:"
Write-Host "  1) Reboot Windows now to finish enabling virtualization features."
Write-Host "  2) After reboot, run the following to finish WSL configuration:" -ForegroundColor Yellow
Write-Host "     wsl --shutdown"
Write-Host "     # Launch your distro from Start menu one time and set a user account"
Write-Host "  3) Copy the wsl-init.sh into your WSL home and run it inside each distro: (from Windows PowerShell):"
Write-Host "     wsl -d Ubuntu -- bash -lc 'mkdir -p ~/bin && cat > ~/wsl-init.sh' < $wslInitPathWin"
Write-Host "     wsl -d Ubuntu -- bash -lc 'chmod +x ~/wsl-init.sh && ~/wsl-init.sh'"
Write-Host ""
Write-Host "Export/import helper scripts saved to $env:USERPROFILE\Downloads (wsl-export.ps1, wsl-import.ps1)."
Write-Host ""
Write-Host "Cloud & Partner Center steps:"
Write-Host "  - Partner Center enrollment & acceptance of agreements must be done manually here: https://partner.microsoft.com"
Write-Host "  - Use 'Install-Module PartnerCenter' (done above) and register an App in Partner Center (manual step) to use APIs."
Write-Host "  - Use 'Connect-AzAccount' or 'az login' inside WSL for Azure work."
Write-Host ""
Write-Host "If you want, reboot now. Run this PowerShell script again later to re-run any missing steps."
