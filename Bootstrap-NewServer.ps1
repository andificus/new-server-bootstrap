<#
.SYNOPSIS
    Automates the initial setup and configuration of a new Windows Server.

.DESCRIPTION
    Performs all standard build steps for a new Windows Server including
    hostname, IP configuration, security baseline, domain join, and
    monitoring agent installation. Logs all actions to a build log.

.PARAMETER Hostname
    The hostname to assign to the server.

.PARAMETER IPAddress
    The static IP address to assign.

.PARAMETER SubnetPrefix
    The subnet prefix length. Example: 24 for a /24 subnet.

.PARAMETER Gateway
    The default gateway IP address.

.PARAMETER DNSServer
    The DNS server IP address.

.PARAMETER DomainName
    The Active Directory domain to join.

.PARAMETER NTPServer
    The NTP server to sync time from. Defaults to the DNS server.

.PARAMETER LogPath
    Path to write the build log. Defaults to .\ServerBuild.log

.EXAMPLE
    .\Bootstrap-NewServer.ps1 `
        -Hostname "SERVER01" `
        -IPAddress "10.0.20.14" `
        -SubnetPrefix 24 `
        -Gateway "10.0.20.1" `
        -DNSServer "10.0.20.10" `
        -DomainName "lab.local" `
        -NTPServer "10.0.20.10"

.NOTES
    Run as Administrator.
    Server will restart automatically after domain join.
    Tested on Windows Server 2019 and 2022.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Hostname,

    [Parameter(Mandatory = $true)]
    [string]$IPAddress,

    [Parameter(Mandatory = $true)]
    [int]$SubnetPrefix,

    [Parameter(Mandatory = $true)]
    [string]$Gateway,

    [Parameter(Mandatory = $true)]
    [string]$DNSServer,

    [Parameter(Mandatory = $true)]
    [string]$DomainName,

    [string]$NTPServer = $DNSServer,
    [string]$LogPath = ".\ServerBuild.log"
)

# --- Logging Function ---
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $entry
    switch ($Level) {
        "INFO"    { Write-Host $entry -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        "WARNING" { Write-Host $entry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $entry -ForegroundColor Red }
    }
}

# --- Check Admin ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Log "Script must be run as Administrator." "ERROR"
    exit 1
}

Write-Log "========================================"
Write-Log "Starting server bootstrap for: $Hostname"
Write-Log "========================================"

# --- Step 1: Set Hostname ---
Write-Log "Setting hostname to $Hostname..."
try {
    Rename-Computer -NewName $Hostname -Force -ErrorAction Stop
    Write-Log "Hostname set to $Hostname" "SUCCESS"
} catch {
    Write-Log "Failed to set hostname — $($_.Exception.Message)" "ERROR"
}

# --- Step 2: Configure Static IP ---
Write-Log "Configuring static IP $IPAddress..."
try {
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $IPAddress -PrefixLength $SubnetPrefix -DefaultGateway $Gateway -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $DNSServer -ErrorAction Stop
    Write-Log "Static IP configured: $IPAddress / $SubnetPrefix — Gateway: $Gateway — DNS: $DNSServer" "SUCCESS"
} catch {
    Write-Log "Failed to configure IP — $($_.Exception.Message)" "ERROR"
}

# --- Step 3: Set Timezone ---
Write-Log "Setting timezone to Central Standard Time..."
try {
    Set-TimeZone -Name "Central Standard Time" -ErrorAction Stop
    Write-Log "Timezone set" "SUCCESS"
} catch {
    Write-Log "Failed to set timezone — $($_.Exception.Message)" "ERROR"
}

# --- Step 4: Configure NTP ---
Write-Log "Configuring NTP to sync from $NTPServer..."
try {
    w32tm /config /manualpeerlist:$NTPServer /syncfromflags:manual /update | Out-Null
    Restart-Service w32tm -Force
    Write-Log "NTP configured" "SUCCESS"
} catch {
    Write-Log "Failed to configure NTP — $($_.Exception.Message)" "ERROR"
}

# --- Step 5: Security Baseline ---
Write-Log "Applying security baseline..."

# Disable Guest account
try {
    Disable-LocalUser -Name "Guest" -ErrorAction Stop
    Write-Log "Guest account disabled" "SUCCESS"
} catch {
    Write-Log "Failed to disable Guest account — $($_.Exception.Message)" "WARNING"
}

# Rename Administrator account
try {
    Rename-LocalUser -Name "Administrator" -NewName "localadmin" -ErrorAction Stop
    Write-Log "Administrator account renamed to localadmin" "SUCCESS"
} catch {
    Write-Log "Failed to rename Administrator — $($_.Exception.Message)" "WARNING"
}

# Enable SMB signing
try {
    Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop
    Write-Log "SMB signing enabled" "SUCCESS"
} catch {
    Write-Log "Failed to enable SMB signing — $($_.Exception.Message)" "WARNING"
}

# Disable SMBv1
try {
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
    Write-Log "SMBv1 disabled" "SUCCESS"
} catch {
    Write-Log "Failed to disable SMBv1 — $($_.Exception.Message)" "WARNING"
}

# Enable Windows Firewall
try {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction Stop
    Write-Log "Windows Firewall enabled on all profiles" "SUCCESS"
} catch {
    Write-Log "Failed to enable Windows Firewall — $($_.Exception.Message)" "WARNING"
}

# --- Step 6: Install Windows Exporter ---
Write-Log "Installing Windows Exporter for Prometheus monitoring..."
try {
    winget install prometheus-community.windows_exporter --silent --accept-package-agreements --accept-source-agreements
    Write-Log "Windows Exporter installed" "SUCCESS"
} catch {
    Write-Log "Failed to install Windows Exporter — $($_.Exception.Message)" "WARNING"
}

# --- Step 7: Domain Join ---
Write-Log "Joining domain $DomainName — you will be prompted for credentials..."
try {
    Add-Computer -DomainName $DomainName -Credential (Get-Credential) -Restart -Force -ErrorAction Stop
    Write-Log "Domain join initiated — server will restart" "SUCCESS"
} catch {
    Write-Log "Failed to join domain — $($_.Exception.Message)" "ERROR"
}

Write-Log "========================================"
Write-Log "Bootstrap complete. Check log for any warnings or errors."
Write-Log "Log saved to: $LogPath"
Write-Log "========================================"