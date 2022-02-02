#
# Script for creating local development environment
# Please do not modify this script as it will be auto-updated from the AL-Go Template
# Recommended approach is to use as is or add a script (freddyk-devenv.ps1), which calls this script with the user specific parameters
#
Param(
    [string] $containerName = "",
    [string] $auth = "",
    [pscredential] $credential = $null,
    [string] $licenseFileUrl = "",
    [string] $insiderSasToken = ""
)

$ErrorActionPreference = "stop"
Set-StrictMode -Version 2.0

$ALGoHelperPath = "$([System.IO.Path]::GetTempFileName()).ps1"
$webClient = New-Object System.Net.WebClient
$webClient.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy -argumentList ([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
$webClient.Encoding = [System.Text.Encoding]::UTF8
$webClient.DownloadFile('https://raw.githubusercontent.com/microsoft/AL-Go-Actions/v0.1/AL-Go-Helper.ps1', $ALGoHelperPath)
. $ALGoHelperPath -local

$baseFolder = Join-Path $PSScriptRoot ".." -Resolve

Clear-Host
Write-Host -ForegroundColor Yellow @'
  _                     _   _____             ______            
 | |                   | | |  __ \           |  ____|           
 | |     ___   ___ __ _| | | |  | | _____   __ |__   _ ____   __
 | |    / _ \ / __/ _` | | | |  | |/ _ \ \ / /  __| | '_ \ \ / /
 | |____ (_) | (__ (_| | | | |__| |  __/\ V /| |____| | | \ V / 
 |______\___/ \___\__,_|_| |_____/ \___| \_/ |______|_| |_|\_/  
                                                                
'@

Write-Host @'
This script will create a docker based local development environment for your project.
All apps and test apps will be compiled and published to the environment in the development scope.
The script will also modify launch.json to have a Local Sandbox configuration point to your environment.

'@

$settings = ReadSettings -baseFolder $baseFolder -userName $env:USERNAME

Write-Host "Checking System Requirements"
$dockerService = Get-Service docker -ErrorAction SilentlyContinue
if (-not $dockerService -or $dockerService.Status -ne "Running") {
    throw "Creating a local development enviroment requires you to have Docker installed and running."
}

if ($settings.keyVaultName) {
    if (-not (Get-Module -ListAvailable -Name 'Az.KeyVault')) {
        throw "A keyvault name is defined in Settings, you need to have the Az.KeyVault PowerShell module installed (use Install-Module az) or you can set the keyVaultName to an empty string in the user settings file ($($ENV:UserName).Settings.json)."
    }
}

Write-Host

if (-not $containerName) {
    $containerName = Enter-Value `
        -title "Container name" `
        -question "Please enter the name of the container to create" `
        -default "bcserver"
}

if (-not $auth) {
    $auth = Select-Value `
        -title "Authentication mechanism for container" `
        -options @{ "Windows" = "Windows Authentication"; "UserPassword" = "Username/Password authentication" } `
        -question "Select authentication mechanism for container" `
        -default "UserPassword"
}

if (-not $credential) {
    if ($auth -eq "Windows") {
        $credential = Get-Credential -Message "Please enter your Windows Credentials" -UserName $env:USERNAME
        $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
        $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$credential.UserName,$credential.GetNetworkCredential().password)
        if ($null -eq $domain.name) {
            Write-Host -ForegroundColor Red "Unable to verify your Windows Credentials, you might not be able to authenticate to your container"
        }
    }
    else {
        $credential = Get-Credential -Message "Please enter username and password for your container" -UserName "admin"
    }
}

if (-not $licenseFileUrl) {
    if ($settings.type -eq "AppSource App") {
        $description = "When developing AppSource Apps, your local development environment needs the developer licensefile with permissions to your AppSource app object IDs"
        $default = ""
    }
    else {
        $description = "When developing PTEs, you can optionally specify a developer licensefile with permissions to object IDs of your dependant apps"
        $default = "none"
    }

    $licenseFileUrl = Enter-Value `
        -title "LicenseFileUrl" `
        -description $description `
        -question "Local path or a secure download URL to license file " `
        -default $default

    if ($licenseFileUrl -eq "none") {
        $licenseFileUrl = ""
    }
}

CreateDevEnv `
    -kind local `
    -caller local `
    -containerName $containerName `
    -baseFolder $baseFolder `
    -auth $auth `
    -credential $credential `
    -LicenseFileUrl $licenseFileUrl `
    -InsiderSasToken $insiderSasToken
