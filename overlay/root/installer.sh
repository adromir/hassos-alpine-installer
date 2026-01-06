#!/bin/bash

# ---
# File: installer.sh
# Description: TUI-based installer for HassOS with WiFi handover and data injection.
# Author: Adromir
# License: MIT
# ---

TITLE="HassOS Ultimate Provisioner"
CONFIG_DIR="/mnt/usb/hassos-config"
FINAL_SSID=""
FINAL_PSK=""

# ---
# Function: install_local_pkgs
# Description: Installs APKs from a local directory.
# ---
install_local_pkgs() {
	local dir=$1
	echo "Installing packages from $dir..."
	apk add --allow-untrusted --no-cache "$dir"/*.apk > /dev/null 2>&1
}

# ---
# Function: prepare_env
# Description: Installs core tools from local cache.
# ---
prepare_env() {
	# Clear screen for a fresh start
	clear
	echo "Initializing installer environment..."
	# Install core tools first (whiptail/newt, curl, etc.)
	if [ -d "/pkg/core" ]; then
		install_local_pkgs "/pkg/core"
	else
		echo "Error: Core packages not found in /pkg/core!"
		# Fallback attempt
		apk update && apk add bash newt curl xz lsblk wireless-tools wpa_supplicant parted util-linux
	fi
}

# ---
# Function: mount_usb_source
# Description: Detects and mounts the USB source (Ventoy or standard USB).
# ---
mount_usb_source() {
	USB_PART=$(lsblk -lo NAME,LABEL | grep -i "Ventoy" | awk '{print $1}' | head -n 1)
	if [ -z "$USB_PART" ]; then
		USB_PART=$(lsblk -lo NAME,FSTYPE | grep -E "vfat|exfat|ntfs" | awk '{print $1}' | head -n 1)
	fi

	mkdir -p /mnt/usb
	if [ -n "$USB_PART" ]; then
		mount "/dev/$USB_PART" /mnt/usb 2>/dev/null
	fi
}

# ---
# Function: check_internet
# Description: Checks internet connectivity.
# ---
check_internet() {
	ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1
}

# ---
# Function: check_wifi_drivers
# Description: Checks for WiFi interface and prompts for driver installation if missing.
# ---
check_wifi_drivers() {
	if [ -z "$(iw dev | grep Interface)" ]; then
		if (whiptail --title "Missing WiFi" --yesno "No WiFi interface detected.\n\nDo you want to install additional firmware/drivers?\n(This requires the provided offline packages)" 12 60); then
			whiptail --title "Installing Drivers" --infobox "Installing firmware packages...\nPlease wait..." 8 50
			if [ -d "/pkg/drivers" ]; then
				install_local_pkgs "/pkg/drivers"
				mdev -s
				sleep 2
			else
				whiptail --title "Error" --msgbox "Driver package directory (/pkg/drivers) not found!" 8 50
			fi
			
			if [ -n "$(iw dev | grep Interface)" ]; then
				whiptail --title "Success" --msgbox "WiFi interface detected!" 8 40
			else
				whiptail --title "Warning" --msgbox "Still no WiFi detected after driver installation.\nA reboot might be required, or the hardware is not supported." 10 60
			fi
		fi
	fi
}

# ---
# Function: configure_wifi
# Description: Scans for WiFi networks and connects.
# ---
configure_wifi() {
	WLAN_IFACE=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
	if [ -z "$WLAN_IFACE" ]; then
		whiptail --title "Error" --msgbox "No WiFi interface found." 8 40
		return 1
	fi

	ip link set "$WLAN_IFACE" up
	whiptail --title "$TITLE" --infobox "Scanning for networks..." 8 40
	
	SSID_LIST=$(iwlist "$WLAN_IFACE" scanning | grep 'ESSID' | cut -d'"' -f2 | grep -v '^$' | awk '{print $1 " - off"}')
	SELECTED_SSID=$(whiptail --title "Select WiFi" --radiolist "Available networks:" 15 60 6 $SSID_LIST 3>&1 1>&2 2>&3)

	if [ -z "$SELECTED_SSID" ]; then return 1; fi

	WIFI_PASS=$(whiptail --title "Password" --passwordbox "Enter password for $SELECTED_SSID:" 10 50 3>&1 1>&2 2>&3)

	wpa_passphrase "$SELECTED_SSID" "$WIFI_PASS" > /etc/wpa_supplicant.conf
	killall wpa_supplicant 2>/dev/null
	wpa_supplicant -B -i "$WLAN_IFACE" -c /etc/wpa_supplicant.conf
	udhcpc -i "$WLAN_IFACE" -n -t 5

	if check_internet; then
		FINAL_SSID="$SELECTED_SSID"
		FINAL_PSK="$WIFI_PASS"
		whiptail --title "Success" --msgbox "Connected to $SELECTED_SSID!" 8 40
		return 0
	else
		whiptail --title "Failure" --msgbox "Connection failed or no internet access." 8 40
		return 1
	fi
}

# ---
# Function: wipe_disk_menu
# Description: Menu interaction to completely wipe a disk.
# ---
wipe_disk_menu() {
	DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1 " [" $2 " - " $3 " " $4 "]" " off"}')
	TARGET_DRIVE=$(whiptail --title "Wipe Disk" --radiolist "Select drive to WIPE COMPLETELY:" 15 70 5 $DISK_LIST 3>&1 1>&2 2>&3)
	
	if [ -z "$TARGET_DRIVE" ]; then return; fi
	
	TARGET_DEV="/dev/$TARGET_DRIVE"
	
	if ! (whiptail --title "DANGER" --yesno "WARNING: ALL DATA ON $TARGET_DEV WILL BE DESTROYED.\n\nThis action cannot be undone.\nAre you absolutely sure?" 12 60); then
		return
	fi

	(
		echo 10
		# 1. Wipe Filesystem Signatures
		wipefs --all --force "$TARGET_DEV" >/dev/null 2>&1
		echo 30
		
		# 2. Wipe Start of Disk (MBR/GPT)
		dd if=/dev/zero of="$TARGET_DEV" bs=1M count=100 conv=fsync status=none
		echo 60
		
		# 3. Wipe End of Disk (Backup GPT)
		# Get size in bytes
		SIZE_BYTES=$(lsblk -b -d -n -o SIZE "$TARGET_DEV")
		# Convert to MB
		SIZE_MB=$((SIZE_BYTES / 1024 / 1024))
		# Start wiping 100MB before end
		SEEK_MB=$((SIZE_MB - 100))
		if [ "$SEEK_MB" -gt 0 ]; then
			dd if=/dev/zero of="$TARGET_DEV" bs=1M seek="$SEEK_MB" count=100 conv=fsync status=none
		fi
		echo 90
		
		# 4. Refresh partitions
		partprobe "$TARGET_DEV" >/dev/null 2>&1
		mdev -s
		echo 100
	) | whiptail --title "Wiping" --gauge "Cleaning disk $TARGET_DEV..." 10 70 0
	
	whiptail --title "Success" --msgbox "Disk $TARGET_DEV has been wiped." 8 40
}

# ---
# Function: install_hassos
# Description: Main installation logic.
# ---
install_hassos() {
	# Check Internet first
	if ! check_internet; then
		if (whiptail --title "No Internet" --yesno "Internet access is required to download HassOS.\nConfigure WiFi now?" 10 50); then
			configure_wifi
			if ! check_internet; then return; fi
		else
			return
		fi
	fi

	DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1 " [" $2 " - " $3 " " $4 "]" " off"}')
	TARGET_DRIVE=$(whiptail --title "Install HassOS" --radiolist "Select target drive:" 15 70 5 $DISK_LIST 3>&1 1>&2 2>&3)
	
	if [ -z "$TARGET_DRIVE" ]; then return; fi
	TARGET_DEV="/dev/$TARGET_DRIVE"

	whiptail --title "Final Warning" --yesno "Write HassOS to $TARGET_DEV?\nAll data will be lost!" 10 50 || return 1
	
	IMAGE_URL=$(curl -s https://api.github.com/repos/home-assistant/operating-system/releases/latest | grep "browser_download_url" | grep "haos_generic-x86-64" | grep ".img.xz" | head -n 1 | cut -d '"' -f 4)
	
	(
		curl -L "$IMAGE_URL" | xz -d | dd of="$TARGET_DEV" bs=4M conv=fsync status=none
		echo 100
	) | whiptail --title "Installing" --gauge "Downloading and writing HassOS..." 10 70 0
	
	inject_data "$TARGET_DEV"
	whiptail --title "Success" --msgbox "HassOS installed and provisioned.\nRemove USB stick and reboot." 12 60
	reboot
}

# ---
# Function: inject_data
# Description: Injects WiFi config, SSH keys, and backups.
# ---
inject_data() {
	local target_disk=$1
	whiptail --title "$TITLE" --infobox "Injecting configurations..." 8 50
	
	partprobe "$target_disk"
	sleep 3

	DATA_PART=$(lsblk -lo NAME,LABEL "${target_disk}" | grep "HassOS-data" | awk '{print $1}')
	BOOT_PART=$(lsblk -lo NAME,LABEL "${target_disk}" | grep "HassOS-boot" | awk '{print $1}')

	mkdir -p /mnt/data /mnt/boot
	mount "/dev/$DATA_PART" /mnt/data
	mount "/dev/$BOOT_PART" /mnt/boot
	
	# ... (Injection logic same as before) ...
	if [ -n "$FINAL_SSID" ]; then
		mkdir -p /mnt/data/supervisor/system-connections
		cat <<EOF > /mnt/data/supervisor/system-connections/default-wifi
[connection]
id=Default-WiFi
type=wifi

[wifi]
mode=infrastructure
ssid=$FINAL_SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$FINAL_PSK

[ipv4]
method=auto

[ipv6]
addr-gen-mode=stable-privacy
method=auto
EOF
		chmod 600 /mnt/data/supervisor/system-connections/default-wifi
	fi

	if [ -f "$CONFIG_DIR/authorized_keys" ]; then
		cp "$CONFIG_DIR/authorized_keys" /mnt/boot/authorized_keys
		chmod 600 /mnt/boot/authorized_keys
	fi

	mkdir -p /mnt/data/supervisor/backup
	mkdir -p /mnt/data/supervisor/homeassistant
	[ -f "$CONFIG_DIR/configuration.yaml" ] && cp "$CONFIG_DIR/configuration.yaml" /mnt/data/supervisor/homeassistant/
	cp "$CONFIG_DIR"/*.tar /mnt/data/supervisor/backup/ 2>/dev/null

	umount /mnt/data /mnt/boot
}

# --- Main Execution Loop ---

prepare_env
mount_usb_source
check_wifi_drivers

while true; do
	CHOICE=$(whiptail --title "$TITLE" --menu "Main Menu" 15 60 4 \
		"1" "Install HassOS" \
		"2" "Configure WiFi" \
		"3" "Wipe & Prepare Disk" \
		"4" "Exit / Shell" 3>&1 1>&2 2>&3)
	
	if [ $? -ne 0 ]; then break; fi # Cancel/Esc

	case "$CHOICE" in
		"1") install_hassos ;;
		"2") configure_wifi ;;
		"3") wipe_disk_menu ;;
		"4") break ;;
	esac
done

clear
echo "Exiting installer. Type 'reboot' to restart."
