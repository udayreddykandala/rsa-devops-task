param(
  [Parameter(Mandatory=$true)] [string]$OctopusUrl,
  [Parameter(Mandatory=$true)] [string]$ApiKey,
  [Parameter(Mandatory=$true)] [string]$Space,
  [Parameter(Mandatory=$true)] [string]$Environment,
  [Parameter(Mandatory=$true)] [string]$Roles
)

$ErrorActionPreference = 'Stop'

# Install IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools | Out-Null

# Install Chocolatey if missing
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install Octopus Tentacle
choco install octopusdeploy.tentacle -y --no-progress
$Tentacle = "C:\Program Files\Octopus Deploy\Tentacle\Tentacle.exe"
if (-not (Test-Path $Tentacle)) { throw "Tentacle not installed" }

New-Item -ItemType Directory -Path C:\Octopus -Force | Out-Null
& $Tentacle create-instance --instance "Tentacle" --config "C:\Octopus\Tentacle.config" --console | Write-Output
& $Tentacle new-certificate --instance "Tentacle" --if-blank --console | Write-Output
& $Tentacle configure --instance "Tentacle" --app "C:\Octopus\Applications" --noListen "True" --console | Write-Output
& $Tentacle service --instance "Tentacle" --install --start --console | Write-Output

# Register as Polling Tentacle on port 443
$displayName = $env:COMPUTERNAME
& $Tentacle register-with `
  --instance "Tentacle" `
  --server $OctopusUrl `
  --comms-style TentacleActive `
  --server-comms-port 443 `
  --name $displayName `
  --apiKey $ApiKey `
  --space $Space `
  --environment $Environment `
  --role $Roles `
  --force `
  --console | Write-Output
