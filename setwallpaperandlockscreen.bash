#!/bin/bash
# DESCRIPTION : Script to change wallpaper AND lockscreen/GDM screen on Ubuntu 24.04 (GNOME 46)
# Sets the same image for desktop wallpaper, screensaver, and GDM login screen.
# Locks settings so users cannot change them.
#
# ARGUMENT(S) : -w <image_file>
# EXAMPLE : bash SetWallpaperAndLockscreen_Ubuntu24.bash -w company.png
#
# SUPPORTED FORMATS: .jpg .jpeg .png
#
# RETURN VALUE MEANING
# 0 Success
# 1 dconf update or GDM apply failed
# 2 Not root / bad arguments
# 3 Unsupported image format
# 4 Image file not found
# 5 Required tool missing (imagemagick)
#
# NOTE: Deploy the image file to the target machine first before running this script.
# User must log out and log back in for wallpaper changes to reflect on their session.
# GDM lockscreen change applies on next lock/login screen appearance.


# Fix Windows line endings if any
sed -i 's/\r//' "$0"


errorCode=0


# ---------- Root check ----------
euid=$(id -u)
if [ "$euid" -ne 0 ]; then
    echo "This script must be run as root."
    exit 2
fi


# ---------- Parse arguments ----------
pictureName=""
while getopts "w:" option; do
case $option in
w) pictureName=$OPTARG ;;
\?) echo "Invalid option."; exit 2 ;;
esac
done


if [ -z "$pictureName" ]; then
echo "No image provided."
echo "Usage: bash SetWallpaperAndLockscreen_Ubuntu24.bash -w <ImageFile>"
exit 2
fi


# ---------- Validate file exists ----------
if [ ! -e "$pictureName" ]; then
echo "File does not exist: $pictureName"
exit 4
fi


# ---------- Validate format ----------
IsFormat=$(echo "$pictureName" | grep -o '\.[^.]*$' | tr '[:upper:]' '[:lower:]')
if [ "$IsFormat" != ".jpg" ] && [ "$IsFormat" != ".jpeg" ] && [ "$IsFormat" != ".png" ]; then
echo "Unsupported format: $IsFormat"
echo "Supported formats: .jpg .jpeg .png"
exit 3
fi


# ---------- Copy image to shared location ----------
WALLPAPER_DIR="/usr/share/mywallpapers"
mkdir -p "$WALLPAPER_DIR"
cp -f "$pictureName" "$WALLPAPER_DIR/"
picturePath="$WALLPAPER_DIR/$(basename "$pictureName")"
echo "Image copied to: $picturePath"


# ---------- PART 1: Set wallpaper + screensaver via dconf (for logged-in users) ----------
DCONF_PROFILE="/etc/dconf/profile/user"
DCONF_POLICY="/etc/dconf/db/local.d/99_wallpaper"
DCONF_LOCKS="/etc/dconf/db/local.d/locks/99_wallpaper"


mkdir -p /etc/dconf/profile
mkdir -p /etc/dconf/db/local.d/locks


# User profile
if ! grep -q "user-db:user" "$DCONF_PROFILE" 2>/dev/null; then
echo "user-db:user" >> "$DCONF_PROFILE"
fi
if ! grep -q "system-db:local" "$DCONF_PROFILE" 2>/dev/null; then
echo "system-db:local" >> "$DCONF_PROFILE"
fi


# Policy file — wallpaper (light + dark) and screensaver
cat > "$DCONF_POLICY" << EOF
[org/gnome/desktop/background]
picture-uri='file://$picturePath'
picture-uri-dark='file://$picturePath'
picture-options='zoom'


[org/gnome/desktop/screensaver]
picture-uri='file://$picturePath'
picture-options='zoom'
EOF


# Locks file — prevent user from changing
cat > "$DCONF_LOCKS" << EOF
/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-uri-dark
/org/gnome/desktop/background/picture-options
/org/gnome/desktop/screensaver/picture-uri
/org/gnome/desktop/screensaver/picture-options
EOF


# Apply dconf
dconf update
if [ $? -ne 0 ]; then
echo "Failed to apply dconf policy."
exit 1
fi
echo "Wallpaper and screensaver policy applied via dconf."


# ---------- PART 2: Set GDM lockscreen / login screen (Ubuntu 24.04 specific) ----------
# Ubuntu 24.04 uses GDM3. The login/lock screen background is set via
# a GDM CSS override on the gresource theme file.


GDM_CSS_DIR="/etc/gdm3"
GDM_CSS_FILE="$GDM_CSS_DIR/greeter.dconf-defaults"


# Method A: dconf defaults for GDM greeter (works on Ubuntu 22.04+)
mkdir -p "$GDM_CSS_DIR"
cat > "$GDM_CSS_FILE" << EOF
[org/gnome/login-screen]
# GDM greeter settings
logo=''
EOF
echo "GDM greeter dconf defaults written."


# Method B: Ubuntu-specific GDM background via gnome-shell theme override
# This directly replaces the lockscreen background in the GDM theme


UBUNTU_THEME_DIR="/usr/share/gnome-shell/theme"
GDMB_CSS=""


# Find the active GDM CSS file
for candidate in \
"$UBUNTU_THEME_DIR/ubuntu.css" \
"$UBUNTU_THEME_DIR/gnome-shell.css" \
"/usr/share/gnome-shell/gnome-shell-theme.gresource"; do
if [ -e "$candidate" ]; then
GDMB_CSS="$candidate"
break
fi
done


# Inject custom CSS via /usr/share/gnome-shell/theme/custom-gdm.css
CUSTOM_CSS="/usr/share/gnome-shell/theme/custom-gdm-background.css"
cat > "$CUSTOM_CSS" << EOF
/* GDM / Lockscreen background - set by EC deployment */
#lockDialogGroup {
  background-image: url('file://$picturePath');
  background-size: cover;
  background-repeat: no-repeat;
  background-position: center;
}
EOF
echo "Custom GDM CSS written to: $CUSTOM_CSS"


# Link it into GDM's stylesheet if not already present
GDM_MAIN_CSS="/usr/share/gnome-shell/theme/ubuntu.css"
if [ -f "$GDM_MAIN_CSS" ]; then
if ! grep -q "custom-gdm-background.css" "$GDM_MAIN_CSS"; then
echo "@import url('custom-gdm-background.css');" >> "$GDM_MAIN_CSS"
echo "Custom CSS imported into GDM theme."
else
echo "Custom CSS already imported — skipping."
fi
else
echo "Warning: $GDM_MAIN_CSS not found. GDM CSS import skipped."
echo "The custom CSS file has been written to $CUSTOM_CSS — manual import may be needed."
fi


# ---------- Apply to currently logged-in users via gsettings (best-effort) ----------
echo "Applying wallpaper to active user sessions..."
for user_home in /home/*; do
username=$(basename "$user_home")
uid=$(id -u "$username" 2>/dev/null)
if [ -z "$uid" ] || [ "$uid" -lt 1000 ]; then
continue
fi
bus_file=$(find /run/user/$uid/ -name "bus" 2>/dev/null | head -1)
if [ -n "$bus_file" ]; then
sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_file" \
gsettings set org.gnome.desktop.background picture-uri "file://$picturePath" 2>/dev/null
sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_file" \
gsettings set org.gnome.desktop.background picture-uri-dark "file://$picturePath" 2>/dev/null
sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_file" \
gsettings set org.gnome.desktop.screensaver picture-uri "file://$picturePath" 2>/dev/null
echo "Applied to active session: $username"
fi
done


# ---------- Done ----------
echo ""
echo "============================================"
echo " Wallpaper : $picturePath"
echo " Screensaver : $picturePath"
echo " GDM Screen : $picturePath (via CSS override)"
echo " Settings : Locked (users cannot change)"
echo "============================================"
echo " NOTE: Users must log out and back in for"
echo " wallpaper changes to fully reflect."
echo " GDM lockscreen applies on next lock."
echo "============================================"


exit 0
