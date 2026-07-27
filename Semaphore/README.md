# Hyper-V Ubuntu Cloud VM with Semaphore

Automatically deploy an Ubuntu Server Cloud Image virtual machine on Hyper-V with Cloud-Init and install Semaphore during the first boot.

## Features

- Automated Hyper-V VM creation
- Supports Ubuntu Server:
  - 24.04 LTS (Noble)
  - 22.04 LTS (Jammy)
- Automatic download of the latest Ubuntu Cloud Image
- Cloud-Init configuration generation
- Interactive configuration wizard
- DHCP or Static IP networking
- Automatic VHDX creation and resizing
- Automatic installation of:
  - OpenSSH Server
  - QEMU Guest Agent
  - Curl
  - Wget
  - CA Certificates
- Automatic Semaphore installation
- Automatic cleanup after the initial Cloud-Init provisioning

---

## Requirements

- Windows 10/11 Pro or Windows Server
- Hyper-V feature enabled
- PowerShell running as **Administrator**
- `qemu-img.exe`
- `oscdimg.exe`

Both executables must be located in the same directory as the PowerShell script. :contentReference[oaicite:0]{index=0}

---

## Supported Operating Systems

- Ubuntu Server 24.04 LTS Cloud Image
- Ubuntu Server 22.04 LTS Cloud Image

---

## What the Script Does

The script guides you through the VM creation process by asking for:

- Virtual machine name
- Ubuntu hostname
- Username and password
- VM storage location
- Ubuntu image storage location
- Hyper-V virtual switch
- Number of virtual CPUs
- Memory size
- Virtual disk size
- Network configuration (DHCP or Static IP)

It then automatically:

1. Downloads the Ubuntu Cloud Image (if necessary)
2. Creates Cloud-Init configuration files
3. Generates a `seed.iso`
4. Converts the Ubuntu image to VHDX
5. Expands the virtual disk
6. Creates a Generation 2 Hyper-V virtual machine
7. Boots the VM
8. Waits for Cloud-Init provisioning to complete
9. Removes temporary Cloud-Init files
10. Restarts the VM

The Cloud-Init configuration also downloads and executes the Semaphore installation script during the first boot. :contentReference[oaicite:1]{index=1}

---

## Installed Packages

During the first boot, Cloud-Init installs:

- OpenSSH Server
- QEMU Guest Agent
- Curl
- Wget
- CA Certificates

Afterward, it downloads and executes:

```text
install-semaphore.sh
```

from:

```text
[https://raw.githubusercontent.com/GrupaEuro/POWERSHELL/refs/heads/main/install-semaphore.sh](https://raw.githubusercontent.com/BitDevOne/Hyper-V/refs/heads/main/Semaphore/install-semaphore.sh)
```


---

## Usage

Run PowerShell as **Administrator** and execute:

```powershell
.\Create-HyperV-Semaphore.ps1
```

Follow the interactive prompts to configure your virtual machine.

---

## Project Structure

```
Project/
│
├── Create-HyperV-Semaphore.ps1
├── qemu-img.exe
├── oscdimg.exe
└── README.md
```

During execution, the script creates:

```
VM/
├── Virtual Hard Disks/
│   └── <VMName>.vhdx
└── cloud-init/
    ├── user-data
    ├── meta-data
    └── network-config
```

The temporary Cloud-Init files are automatically removed after the initial provisioning.

---

## Notes

- Secure Boot is disabled automatically for compatibility with Ubuntu Cloud Images.
- The VM is configured as a Generation 2 Hyper-V virtual machine.
- The root filesystem is automatically expanded on first boot.
- SSH password authentication is enabled by default.
- The VM powers off automatically after the initial Cloud-Init configuration and is restarted by the script.

---

## License

This project is provided as-is for educational and administrative purposes.
