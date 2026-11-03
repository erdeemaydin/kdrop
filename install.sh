#!/bin/bash
# Installs KDrop for the current user. No root needed (owly itself must be installed).
# Re-run to update.
set -e
cd "$(dirname "$0")"
ID=io.github.erdeemaydin.kdrop
BIN="$HOME/.local/bin/kdrop"
APPS="$HOME/.local/share/applications"

if ! command -v owly >/dev/null; then
    echo "owly is not installed yet. Install it first: https://github.com/t4t5/owly#install"
    echo "(KDrop is installed anyway; it starts working once owly is there.)"
fi

install -Dm755 kdrop "$BIN"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
install -Dm644 plasmoid/contents/icons/kdrop.svg "$ICON_DIR/$ID.svg"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

# Clean up the pre-rename "Owly Drop" prototype, keeping its settings (kdrop reads them).
if [ -e "$HOME/.local/bin/owlydrop" ] || [ -d "$HOME/.local/share/plasma/plasmoids/local.owlydrop" ]; then
    systemctl --user stop owlydrop-send owlydrop-receive owlydrop-browse owlydrop-radio 2>/dev/null || true
    command -v kpackagetool6 >/dev/null && kpackagetool6 -t Plasma/Applet -r local.owlydrop >/dev/null 2>&1 || true
    rm -f "$HOME/.local/bin/owlydrop" "$HOME/.local/share/kio/servicemenus/owlydrop.desktop"
    [ -e "$HOME/.config/kdrop.json" ] || { [ -e "$HOME/.config/owlydrop.json" ] && cp "$HOME/.config/owlydrop.json" "$HOME/.config/kdrop.json"; }
    echo "Removed the old Owly Drop widget (settings carried over)."
fi

if command -v kpackagetool6 >/dev/null; then
    # KDE Plasma: the panel widget does everything.
    PLASMA=1
    kpackagetool6 -t Plasma/Applet -r "$ID" >/dev/null 2>&1 || true
    kpackagetool6 -t Plasma/Applet -i plasmoid >/dev/null
    rm -f "$APPS/kdrop-receive.desktop" "$APPS/kdrop-browse.desktop"
else
    # Other desktops: app-menu entries for receiving and searching; sending is in the
    # file manager's right-click menu. Progress shows up as notifications.
    PLASMA=0
    mkdir -p "$APPS"
    cat > "$APPS/kdrop-receive.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=KDrop: Receive files
Comment=Be visible to nearby iPhones, iPads and Macs for a few minutes
Exec="$BIN" receive --notify
Icon=$ID
Terminal=false
Categories=Network;FileTransfer;
Actions=s30;m1;m5;m10;

[Desktop Action s30]
Name=Receive for 30 seconds
Exec="$BIN" receive 30s --notify

[Desktop Action m1]
Name=Receive for 1 minute
Exec="$BIN" receive 1m --notify

[Desktop Action m5]
Name=Receive for 5 minutes
Exec="$BIN" receive 5m --notify

[Desktop Action m10]
Name=Receive for 10 minutes
Exec="$BIN" receive 10m --notify
DESKTOP
    cat > "$APPS/kdrop-browse.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=KDrop: Find devices
Comment=Look for nearby iPhones, iPads and Macs to send files to
Exec="$BIN" browse --notify
Icon=$ID
Terminal=false
Categories=Network;FileTransfer;
DESKTOP
    command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true
fi
"$BIN" refresh-menu        # right-click "Send via AirDrop" in Dolphin, Files, Nemo, Caja

# Let AirDrop through firewalld, on the AirDrop interface only. Needs root once.
if command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld \
   && ! firewall-cmd --get-zones 2>/dev/null | grep -qw awdl; then
    echo
    echo "Your firewall would block files sent to this computer."
    read -r -p "Open AirDrop's port (TCP 8771, AirDrop interface only)? You'll be asked for your password. [Y/n] " a
    if [[ ! "$a" =~ ^[Nn] ]]; then
        pkexec sh -c 'firewall-cmd -q --permanent --new-zone=awdl &&
            firewall-cmd -q --permanent --zone=awdl --add-interface=awdl0 &&
            firewall-cmd -q --permanent --zone=awdl --add-port=8771/tcp &&
            firewall-cmd -q --permanent --zone=awdl --add-service=mdns &&
            firewall-cmd -q --reload' && echo "Firewall set up." \
            || echo "Firewall not changed. See README → Install for the commands."
    fi
fi

echo
echo "KDrop installed."
if [ "$PLASMA" = 1 ]; then
    # Puts KDrop where the saved setting says: in the panel (default) or in the app menu.
    if "$BIN" apply-mode; then
        if [ "$("$BIN" settings | grep -o '"mode": "[a-z]*"')" = '"mode": "app"' ]; then
            echo "Open KDrop from your app menu."
        else
            echo "KDrop is in your panel. Click its icon to start."
        fi
    fi
    echo "(Settings → \"Run KDrop as\" switches between panel widget and separate app.)"
    echo "After an update, reload Plasma: systemctl --user restart plasma-plasmashell"
else
    echo "1. Set AirDrop on your iPhone/iPad to \"Everyone for 10 minutes\"."
    echo "2. Open \"KDrop: Find devices\" from your app menu."
    echo "3. Right-click files → Send via AirDrop → your device."
    echo "To receive, open \"KDrop: Receive files\"."
fi
