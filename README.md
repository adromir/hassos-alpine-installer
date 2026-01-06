# HassOS Ultimate Provisioner

![Alpine Linux](https://img.shields.io/badge/Base-Alpine_Linux-blue?style=for-the-badge&logo=alpine-linux)
![Platform](https://img.shields.io/badge/Platform-x86__64_%7C_RPi-orange?style=for-the-badge&logo=raspberry-pi)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)
![Build Status](https://github.com/adromir/hassos-alpine-installer/actions/workflows/build-overlay.yml/badge.svg?style=for-the-badge)

🚀 **The easiest way to flash Home Assistant OS (HassOS) directly from your hardware.**

This project eliminates the need for manual `dd` commands or booting complex live environments. Just boot this tool, and let it provide Home Assistant OS for you—complete with WiFi, SSH keys, and backups pre-injected!

---

## ✨ Features

- **💿 Plug & Play Media**: 
  - **PC (Intel/AMD)**: Bootable Hybrid ISO (Ventoy / Rufus compatible).
  - **Raspberry Pi**: Native Disk Image (RPi Imager compatible).
- **📶 Offline & Wireless**: 
  - Includes **offline drivers** for Intel, Realtek, Atheros, Broadcom (RPi), and Cypress WiFi.
  - Connect to WiFi **during installation**, and credentials are *automatically passed* to Home Assistant.
- **🧹 Clean Slate Protocol**: 
  - **Wipe & Prepare Disk** utility scrubs old RAID/ZFS/GPT signatures to ensure a perfect install.
- **💉 Auto-Injection**: 
  - Automatically injects **SSH Keys** (`authorized_keys`).
  - Pre-loads **Configuration** (`configuration.yaml`).
  - Restores **Backups** (`.tar` snapshots) automatically on first boot.

---

## 📥 Downloads

| Platform | Recommended For | File Type | Download |
| :--- | :--- | :--- | :--- |
| **x86_64** | Intel NUC, Mini PCs, Laptops | `.iso` | [**Download ISO**](https://github.com/adromir/hassos-alpine-installer/releases/latest/download/hassos-provisioner-x86_64.iso) |
| **aarch64** | Raspberry Pi 3, 4, 5 | `.img.gz` | [**Download IMG**](https://github.com/adromir/hassos-alpine-installer/releases/latest/download/hassos-provisioner-rpi.img.gz) |

*(Or visit the [Releases Page](https://github.com/adromir/hassos-alpine-installer/releases/latest))*

---

## 🛠️ Installation Guide

### Method A: Ventoy (Recommended for PC)
*Best for: Intel NUC, Mini PCs, Laptops*

1.  Install [**Ventoy**](https://www.ventoy.net/) onto a USB stick.
2.  Drop the `hassos-provisioner-x86_64.iso` file onto the USB stick.
3.  Boot your device and select the ISO.

### Method B: Rufus (Alternative for PC)
*Best for: Dedicated Installation Sticks*

1.  Open [**Rufus**](https://rufus.ie/).
2.  Select your USB Stick.
3.  Select `hassos-provisioner-x86_64.iso`.
4.  Click **START** (Write in ISO mode matches standard behavior).

### Method C: Raspberry Pi Imager
*Best for: Raspberry Pi 3 / 4 / 5*

1.  Open [**Raspberry Pi Imager**](https://www.raspberrypi.com/software/).
2.  **OS**: Choose `Use Custom` and select `hassos-provisioner-rpi.img.gz`.
3.  **Storage**: Select your SD Card or USB SSD.
4.  Click **WRITE**.

---

## ⚙️ Advanced: Auto-Configuration
You can pre-load your own data onto the installation media (or a second USB stick) to have it automatically injected into Home Assistant.

Create a folder named `hassos-config` on the root of the drive:

| File Name | Purpose |
| :--- | :--- |
| `authorized_keys` | Your public SSH key (for root access). |
| `configuration.yaml` | Starting configuration file. |
| `my-backup.tar` | Any Full Backup file to be restored. |

---

## ⚠️ Disclaimer
**DATA DESTRUCTION WARNING**: This tool is designed to **WIPE DRIVES**. 
The "Install" and "Wipe" functions will completely erase the selected target disk. Always ensure you have backups of important data before proceeding.

---

## 👨‍💻 Author
Created by **Adromir**.  
Project codebase: [https://github.com/adromir](https://github.com/adromir)
