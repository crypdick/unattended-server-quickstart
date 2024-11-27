#!/bin/bash

echo "Starting setup of unattended server"

# makes whole script fail if any individual cmds fail
set -euo pipefail

LOGFILE="/var/log/unattended_setup.log"
exec 1> >(tee -a "$LOGFILE") 2>&1

# Add trap for cleanup
trap 'cleanup' EXIT
cleanup() {
    rm -f "${CONFIG_FILE}.origins"
    if [ $? -ne 0 ]; then
        echo "Setup failed. Check $LOGFILE for details"
        exit 1
    fi
    echo "Setup completed successfully. Check $LOG for details"

CONFIG_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"

# Function to check if command succeeded
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "Updating package lists and installing unattended-upgrades package"
apt update && apt install -y unattended-upgrades
check_error "Failed to install unattended-upgrades"

echo "Configuring unattended-upgrades in $CONFIG_FILE"

# Backup original config
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
check_error "Failed to create backup"

# Function to uncomment and set configuration
configure_setting() {
    local pattern="$1"
    local replacement="$2"
    
    # Use grep to find the line and sed to replace it
    if grep -q "$pattern" "$CONFIG_FILE"; then
        sed -i "s|^//\s*$pattern|$replacement|" "$CONFIG_FILE"
        check_error "Failed to configure $pattern"
    else
        echo "$replacement" >> "$CONFIG_FILE"
        check_error "Failed to add $replacement"
    fi
}

# Configure all settings
configure_setting 'Unattended-Upgrade::Remove-Unused-Dependencies' 'Unattended-Upgrade::Remove-Unused-Dependencies "true";'
configure_setting 'Unattended-Upgrade::Remove-Unused-Kernel-Packages' 'Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";'
configure_setting 'Unattended-Upgrade::Remove-New-Unused-Dependencies' 'Unattended-Upgrade::Remove-New-Unused-Dependencies "true";'
configure_setting 'Unattended-Upgrade::Automatic-Reboot' 'Unattended-Upgrade::Automatic-Reboot "true";'
configure_setting 'Unattended-Upgrade::SyslogEnable' 'Unattended-Upgrade::SyslogEnable "true";'
configure_setting 'Unattended-Upgrade::AutoFixInterruptedDpkg' 'Unattended-Upgrade::AutoFixInterruptedDpkg "true";'
configure_setting 'Unattended-Upgrade::MinimalSteps' 'Unattended-Upgrade::MinimalSteps "true";'
configure_setting 'Unattended-Upgrade::Automatic-Reboot-WithUsers' 'Unattended-Upgrade::Automatic-Reboot-WithUsers "true";'

# Enable all security updates in Allowed-Origins
{
    echo 'Unattended-Upgrade::Allowed-Origins {
	"${distro_id}:${distro_codename}";
	"${distro_id}:${distro_codename}-security";
	\/\/ Extended Security Maintenance; doesn't necessarily exist for
	\/\/ every release and this system may not have it installed, but if
	\/\/ available, the policy for updates is such that unattended-upgrades
	\/\/ should also install from here by default.
	"${distro_id}ESMApps:${distro_codename}-apps-security";
	"${distro_id}ESM:${distro_codename}-infra-security";
	"${distro_id}:${distro_codename}-updates";
	\/\/ Uncomment the following lines to enable automatic upgrades from proposed and backports
	\/\/"${distro_id}:${distro_codename}-proposed";
	\/\/"${distro_id}:${distro_codename}-backports";
};' 
} > "${CONFIG_FILE}.origins"
check_error "Failed to create origins file"

# Replace the Allowed-Origins section
sed -i '/^Unattended-Upgrade::Allowed-Origins {/,/^};/!b;r '${CONFIG_FILE}.origins'' "$CONFIG_FILE"
check_error "Failed to update Allowed-Origins"
rm "${CONFIG_FILE}.origins"

echo "Configuration of unattended-upgrades complete"
echo "Original configuration backed up to ${CONFIG_FILE}.backup"

# Verify the service is enabled and running
systemctl enable unattended-upgrades
systemctl restart unattended-upgrades
check_error "Failed to enable/restart unattended-upgrades service"

echo "Unattended-upgrades service is now running and configured"


echo "Installing and configuring NTP for time synchronization"
apt install -y systemd-timesyncd
check_error "Failed to install systemd-timesyncd"

# Enable and start the time sync service
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd
check_error "Failed to enable/start systemd-timesyncd service"

# Verify time sync is working
timedatectl set-ntp true
check_error "Failed to enable NTP synchronization"

echo "Time synchronization (NTP) is now configured and running"
