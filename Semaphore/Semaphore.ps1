#Requires -RunAsAdministrator
Clear-Host
$ErrorActionPreference = "Stop"

$InstallScriptUrl = "https://raw.githubusercontent.com/GrupaEuro/POWERSHELL/refs/heads/main/install-semaphore.sh"

function Read-RequiredString {
    param(
        [string]$Prompt,
        [string]$Suggested
    )

    do {
        $Value = Read-Host "$Prompt [$Suggested]"

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = $Suggested
        }

        if (-not [string]::IsNullOrWhiteSpace($Value)) {
            return $Value.Trim()
        }

        Write-Host "The value cannot be empty. Please try again." -ForegroundColor Red
    } while ($true)
}

function Read-RequiredInt {
    param(
        [string]$Prompt,
        [int]$Suggested,
        [int]$Min,
        [int]$Max
    )

    do {
        $InputValue = Read-Host "$Prompt [$Suggested]"

        if ([string]::IsNullOrWhiteSpace($InputValue)) {
            $InputValue = $Suggested
        }

        $Parsed = 0

        if ([int]::TryParse($InputValue, [ref]$Parsed)) {
            if ($Parsed -ge $Min -and $Parsed -le $Max) {
                return $Parsed
            }
        }

        Write-Host "Invalid value. Enter a number from $Min to $Max." -ForegroundColor Red
    } while ($true)
}

function Read-RequiredChoice {
    param(
        [string]$Prompt,
        [string[]]$AllowedValues,
        [string]$Suggested
    )

    do {
        $Value = Read-Host "$Prompt [$Suggested]"

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = $Suggested
        }

        if ($AllowedValues -contains $Value) {
            return $Value
        }

        Write-Host "Invalid choice. Allowed values: $($AllowedValues -join ', ')" -ForegroundColor Red
    } while ($true)
}

function Read-IPAddressRequired {
    param(
        [string]$Prompt,
        [string]$Suggested = ""
    )

    do {
        if ([string]::IsNullOrWhiteSpace($Suggested)) {
            $Value = Read-Host $Prompt
        } else {
            $Value = Read-Host "$Prompt [$Suggested]"

            if ([string]::IsNullOrWhiteSpace($Value)) {
                $Value = $Suggested
            }
        }

        $Address = $null

        if ([System.Net.IPAddress]::TryParse($Value, [ref]$Address)) {
            return $Value.Trim()
        }

        Write-Host "Invalid IP address. Please try again." -ForegroundColor Red
    } while ($true)
}

function Read-DNSList {
    do {
        $DNS = Read-Host "Enter DNS servers separated by commas, for example: 1.1.1.1,8.8.8.8"

        if ([string]::IsNullOrWhiteSpace($DNS)) {
            Write-Host "You must enter at least one DNS server." -ForegroundColor Red
            continue
        }

        $DnsList = $DNS.Split(",") | ForEach-Object { $_.Trim() }
        $Valid = $true

        foreach ($Server in $DnsList) {
            $Address = $null

            if (-not [System.Net.IPAddress]::TryParse($Server, [ref]$Address)) {
                $Valid = $false
                break
            }
        }

        if ($Valid) {
            return ($DnsList -join ",")
        }

        Write-Host "An invalid DNS address was provided. Please try again." -ForegroundColor Red
    } while ($true)
}

function Read-RequiredUserName {
    param(
        [string]$Prompt,
        [string]$Suggested
    )

    do {
        $Value = Read-Host "$Prompt (for example: $Suggested)"

        if ([string]::IsNullOrWhiteSpace($Value)) {
            Write-Host "You must enter a username." -ForegroundColor Red
            continue
        }

        $Value = $Value.Trim()

        if ($Value.Length -lt 2 -or $Value.Length -gt 32) {
            Write-Host "The username must contain between 2 and 32 characters." -ForegroundColor Red
            continue
        }

        if ($Value -notmatch '^[a-z][-a-z0-9_]*$') {
            Write-Host "Only lowercase letters, numbers, '-' and '_' are allowed." -ForegroundColor Red
            Write-Host "The username must begin with a letter." -ForegroundColor Red
            continue
        }

        return $Value
    } while ($true)
}

function Read-RequiredFolderPath {
    param(
        [string]$Prompt,
        [string]$Example
    )

    do {
        $Path = Read-Host "$Prompt (for example: $Example)"

        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-Host "You must enter a folder path." -ForegroundColor Red
            continue
        }

        $Path = $Path.Trim().Trim('"')

        # The path must be absolute.
        if (-not [System.IO.Path]::IsPathRooted($Path)) {
            Write-Host "Enter a full path, for example: C:\VM." -ForegroundColor Red
            continue
        }

        # The path must begin with a drive letter.
        if ($Path -notmatch '^[A-Za-z]:\\') {
            Write-Host "The path must begin with a drive letter, for example: C:\VM." -ForegroundColor Red
            continue
        }

        # Check for invalid characters.
        if ($Path.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ge 0) {
            Write-Host "The path contains invalid characters." -ForegroundColor Red
            continue
        }

        try {
            $FullPath = [System.IO.Path]::GetFullPath($Path)
        }
        catch {
            Write-Host "Invalid path." -ForegroundColor Red
            continue
        }

        # The drive must exist.
        $Drive = $FullPath.Substring(0, 2)

        if (-not (Test-Path $Drive)) {
            Write-Host "Drive $Drive does not exist." -ForegroundColor Red
            continue
        }

        return $FullPath
    } while ($true)
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Hyper-V Semaphore Ubuntu Cloud VM"
Write-Host "======================================" -ForegroundColor Cyan

$ScriptDir = $PSScriptRoot
$Oscdimg = Join-Path $ScriptDir "oscdimg.exe"
$QemuImg = Join-Path $ScriptDir "qemu-img.exe"

if (-not (Test-Path $Oscdimg)) {
    Write-Error "oscdimg.exe was not found in the script directory."
    exit 1
}

if (-not (Test-Path $QemuImg)) {
    Write-Error "qemu-img.exe was not found in the script directory."
    exit 1
}

$VMName = Read-RequiredString "VM name" "Semaphore"
$Hostname = Read-RequiredString "Ubuntu hostname" "semaphore-vm"
$Username = Read-RequiredUserName "Ubuntu username" "admin"

do {
    $SecurePass = Read-Host "Ubuntu user password" -AsSecureString

    if ($SecurePass.Length -gt 0) {
        break
    }

    Write-Host "The password cannot be empty. Please try again." -ForegroundColor Red
} while ($true)

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$BaseFolder = Read-RequiredFolderPath "VM base folder" "C:\VM"
$ImageFolder = Read-RequiredFolderPath "Ubuntu Cloud image folder" "C:\ISO"

New-Item -ItemType Directory -Force -Path $BaseFolder | Out-Null
New-Item -ItemType Directory -Force -Path $ImageFolder | Out-Null

Write-Host ""
Write-Host "Select the Ubuntu version:" -ForegroundColor Yellow
Write-Host "1) Ubuntu Server 24.04 LTS Cloud Image"
Write-Host "2) Ubuntu Server 22.04 LTS Cloud Image"

$UbuntuChoice = Read-RequiredChoice "Selection" @("1", "2") "1"

switch ($UbuntuChoice) {
    "1" {
        $ImgName = "noble-server-cloudimg-amd64.img"
        $ImgUrl = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    }
    "2" {
        $ImgName = "jammy-server-cloudimg-amd64.img"
        $ImgUrl = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    }
}

$CloudImg = Join-Path $ImageFolder $ImgName

if (-not (Test-Path $CloudImg)) {
    Write-Host "Downloading Ubuntu Cloud Image: $ImgName" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $ImgUrl -OutFile $CloudImg
} else {
    Write-Host "The cloud image already exists: $CloudImg" -ForegroundColor Green
}

Write-Host ""
Write-Host "Available Hyper-V switches:" -ForegroundColor Yellow

$Switches = @(Get-VMSwitch)

if ($Switches.Count -eq 0) {
    Write-Error "No Hyper-V switches were found."
    exit 1
}

for ($i = 0; $i -lt $Switches.Count; $i++) {
    Write-Host "$($i + 1)) $($Switches[$i].Name) [$($Switches[$i].SwitchType)]"
}

$SwitchChoice = Read-RequiredInt "Select a switch number" 1 1 $Switches.Count
$SwitchIndex = $SwitchChoice - 1
$SwitchName = $Switches[$SwitchIndex].Name

$ComputerSystem = Get-CimInstance Win32_ComputerSystem
$HostCPU = [int]$ComputerSystem.NumberOfLogicalProcessors
$HostRAMGB = [int][math]::Floor($ComputerSystem.TotalPhysicalMemory / 1GB)

Write-Host ""
Write-Host "Host resources:" -ForegroundColor Cyan
Write-Host "Maximum number of logical CPUs: $HostCPU"
Write-Host "Maximum amount of RAM: $HostRAMGB GB"

$SuggestedCPU = [math]::Min(2, $HostCPU)
$SuggestedRAMGB = [math]::Min(2, $HostRAMGB)

$CPU = Read-RequiredInt "Number of CPUs, maximum $HostCPU" $SuggestedCPU 1 $HostCPU
$RAMGB = Read-RequiredInt "RAM in GB, maximum $HostRAMGB" $SuggestedRAMGB 1 $HostRAMGB
$DiskGB = Read-RequiredInt "Disk size in GB" 20 8 2048

$UseDHCP = Read-RequiredChoice "Use DHCP? Y/N" @("Y", "y", "N", "n") "N"

if ($UseDHCP -match "^[Yy]") {
    $NetworkConfig = @"
version: 2
ethernets:
  eth0:
    match:
      name: "e*"
    set-name: eth0
    dhcp4: true
    dhcp-identifier: mac
"@
    $IPInfo = "DHCP"
} else {
    $IP = Read-IPAddressRequired "VM IP address, for example: 192.168.108.150"
    $Prefix = Read-RequiredInt "Subnet prefix length" 24 1 32
    $Gateway = Read-IPAddressRequired "Gateway, for example: 192.168.108.1"
    $DNS = Read-DNSList

    $NetworkConfig = @"
version: 2
ethernets:
  eth0:
    match:
      name: "e*"
    set-name: eth0
    dhcp4: false
    addresses:
      - $IP/$Prefix
    routes:
      - to: default
        via: $Gateway
    nameservers:
      addresses: [$DNS]
"@
    $IPInfo = $IP
}

$VMFolder = Join-Path $BaseFolder $VMName
$VhdFolder = Join-Path $VMFolder "Virtual Hard Disks"
$WorkDir = Join-Path $VMFolder "cloud-init"
$SeedISO = Join-Path $VMFolder "seed.iso"
$VHDPath = Join-Path $VhdFolder "$VMName.vhdx"

if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Error "A VM named '$VMName' already exists."
    exit 1
}

if (Test-Path $VMFolder) {
    Write-Error "The VM folder already exists: $VMFolder"
    exit 1
}

New-Item -ItemType Directory -Force -Path $VMFolder | Out-Null
New-Item -ItemType Directory -Force -Path $VhdFolder | Out-Null
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

$userData = @"
#cloud-config
hostname: $Hostname
fqdn: $Hostname
manage_etc_hosts: true

users:
  - name: $Username
    gecos: $Username
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false

chpasswd:
  list: |
    $($Username):$PlainPassword
  expire: false

ssh_pwauth: true
disable_root: false

package_update: true
packages:
  - openssh-server
  - qemu-guest-agent
  - curl
  - wget
  - ca-certificates

growpart:
  mode: auto
  devices: ['/']
  ignore_growroot_disabled: false

resize_rootfs: true

runcmd:
  - systemctl enable ssh
  - systemctl restart ssh
  - systemctl enable qemu-guest-agent
  - systemctl restart qemu-guest-agent
  - curl -fsSL $InstallScriptUrl -o /root/install-semaphore.sh
  - chmod +x /root/install-semaphore.sh
  - /root/install-semaphore.sh

power_state:
  mode: poweroff
  timeout: 300
  condition: true
"@

$metaData = @"
instance-id: $VMName
local-hostname: $Hostname
"@

$userData | Set-Content -Encoding ASCII (Join-Path $WorkDir "user-data")
$metaData | Set-Content -Encoding ASCII (Join-Path $WorkDir "meta-data")
$NetworkConfig | Set-Content -Encoding ASCII (Join-Path $WorkDir "network-config")

[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
$PlainPassword = $null

Write-Host "Creating the cloud-init seed.iso file..." -ForegroundColor Yellow
& $Oscdimg -o -m -j2 -lCIDATA $WorkDir $SeedISO

if ($LASTEXITCODE -ne 0) {
    Write-Error "oscdimg exited with an error."
    exit 1
}

Write-Host "Converting the Ubuntu Cloud Image to VHDX..." -ForegroundColor Yellow
& $QemuImg convert `
    $CloudImg `
    -O vhdx `
    -o subformat=dynamic `
    $VHDPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "qemu-img exited with an error."
    exit 1
}

Write-Host "Removing the sparse flag from the VHDX file..." -ForegroundColor Yellow
& fsutil.exe sparse setflag $VHDPath 0 | Out-Null

Write-Host "Expanding the VHDX disk to $DiskGB GB..." -ForegroundColor Yellow
Resize-VHD -Path $VHDPath -SizeBytes ([int64]$DiskGB * 1GB)

Write-Host "Creating the VM..." -ForegroundColor Yellow

New-VM `
    -Name $VMName `
    -Generation 2 `
    -MemoryStartupBytes ([int64]$RAMGB * 1GB) `
    -VHDPath $VHDPath `
    -Path $BaseFolder `
    -SwitchName $SwitchName

Set-VMProcessor -VMName $VMName -Count ([int]$CPU)
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
Set-VMComPort -VMName $VMName -Number 2 -Path "\\.\pipe\$VMName-com2"

Add-VMDvdDrive -VMName $VMName -Path $SeedISO

$HardDrive = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $HardDrive

Start-VM $VMName

Write-Host ""
Write-Host "Waiting for cloud-init to finish configuring the VM and power it off..." -ForegroundColor Yellow

do {
    Start-Sleep -Seconds 10
    $VMState = (Get-VM -Name $VMName).State
    Write-Host "VM state: $VMState"
} while ($VMState -ne "Off")

Write-Host "The VM is powered off. Detaching seed.iso and cleaning up cloud-init files..." -ForegroundColor Yellow

Get-VMDvdDrive -VMName $VMName |
    Where-Object { $_.Path -eq $SeedISO } |
    Remove-VMDvdDrive

Remove-Item -Path $SeedISO -Force -ErrorAction SilentlyContinue
Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Cleanup completed. Starting the VM again..." -ForegroundColor Yellow
Start-VM $VMName

Write-Host ""
Write-Host "Completed!" -ForegroundColor Green
Write-Host "VM: $VMName"
Write-Host "Hostname: $Hostname"
Write-Host "IP: $IPInfo"
Write-Host "Switch: $SwitchName"
Write-Host "CPU: $CPU / maximum $HostCPU"
Write-Host "RAM: $RAMGB GB / maximum $HostRAMGB GB"
Write-Host "Disk: $DiskGB GB"
Write-Host "VM folder: $VMFolder"
Write-Host "VHDX: $VHDPath"
Write-Host "The VM has been restarted."