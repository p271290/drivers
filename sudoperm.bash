#!/bin/bash
# DESCRIPTION  : Script to restrict specific dangerous sudo commands for a user
#                while keeping their general sudo access intact.
#                Blocks: rm -rf, apt upgrade, apt install, su -
#
# ARGUMENT(S)  : <username>
# EXAMPLE      : bash RestrictSudoCommands.bash testuser
#
# RETURN VALUE              MEANING
#       0         Restrictions applied successfully
#       1         Error applying restrictions
#       2         Invalid arguments / user not found
#
# NOTE: Deploy via Endpoint Central. No dependencies required.
 
# Fix Windows line endings
sed -i 's/\r//' "$0"
 
errorCode=0
 
# ---------- Root check ----------
euid=$(id -u)
if [ "$euid" -ne 0 ]; then
    echo "This script must be run as root."
    exit 2
fi
 
# ---------- Argument check ----------
if [ $# -lt 1 ]; then
    echo "Incorrect Usage: No arguments given."
    echo "Usage: bash RestrictSudoCommands.bash <username>"
    exit 2
fi
 
user=$1
 
# ---------- Check user exists ----------
doesUserExist=$(grep -c "^$user:" /etc/passwd)
if [ "$doesUserExist" -eq 0 ]; then
    echo "User: $user does not exist."
    exit 2
fi
 
echo "Applying sudo restrictions for user: $user"
 
# ---------- Remove existing sudoers entry for this user ----------
# Clean up any existing entry to avoid duplicates
sed -i "/^$user /d" /etc/sudoers
echo "Existing sudoers entry for $user removed."
 
# ---------- Write restricted sudoers rule ----------
# Allows all sudo EXCEPT the blocked commands
SUDOERS_ENTRY="$user ALL=(ALL:ALL) ALL, !/bin/rm, !/usr/bin/rm, !/usr/bin/apt, !/usr/bin/apt-get, !/bin/su, !/usr/bin/sudo"
 
echo "$SUDOERS_ENTRY" >> /etc/sudoers
 
if [ $? -eq 0 ]; then
    echo "Restricted sudoers rule added for: $user"
else
    echo "Error writing to /etc/sudoers"
    exit 1
fi
 
# ---------- Validate sudoers file ----------
visudo -c
if [ $? -ne 0 ]; then
    echo "ERROR: sudoers file validation failed. Rolling back..."
    sed -i "/^$user /d" /etc/sudoers
    echo "$user ALL=(ALL:ALL) ALL" >> /etc/sudoers
    echo "Rolled back to full sudo access for safety."
    exit 1
fi
 
# ---------- Confirm final rule ----------
echo ""
echo "============================================"
echo " User        : $user"
echo " Sudo access : Allowed (restricted)"
echo " Blocked commands:"
echo "   - rm / rm -rf        (!/bin/rm, !/usr/bin/rm)"
echo "   - apt upgrade        (!/usr/bin/apt)"
echo "   - apt install        (!/usr/bin/apt)"
echo "   - apt-get            (!/usr/bin/apt-get)"
echo "   - su -               (!/bin/su)"
echo "   - sudo               (!/usr/bin/sudo)"
echo "============================================"
echo " Sudoers entry applied:"
echo " $SUDOERS_ENTRY"
echo "============================================"
 
exit 0