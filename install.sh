#!/bin/bash
# Installs KDrop for the current user. No root needed (owly itself must be installed).
# Re-run to update.
set -e
cd "$(dirname "$0")"
ID=io.github.erdeemaydin.kdrop

command -v owly >/dev/null || echo "Note: owly is not installed yet. See https://github.com/t4t5/owly#install"

install -Dm755 kdrop "$HOME/.local/bin/kdrop"
kpackagetool6 -t Plasma/Applet -r "$ID" >/dev/null 2>&1 || true
kpackagetool6 -t Plasma/Applet -i plasmoid >/dev/null
"$HOME/.local/bin/kdrop" refresh-menu        # Dolphin "Send via AirDrop" menu

# Clean up the pre-rename "Owly Drop" prototype, keeping its settings (kdrop reads them).
if [ -e "$HOME/.local/bin/owlydrop" ] || [ -d "$HOME/.local/share/plasma/plasmoids/local.owlydrop" ]; then
    systemctl --user stop owlydrop-send owlydrop-receive owlydrop-browse owlydrop-radio 2>/dev/null || true
    kpackagetool6 -t Plasma/Applet -r local.owlydrop >/dev/null 2>&1 || true
    rm -f "$HOME/.local/bin/owlydrop" "$HOME/.local/share/kio/servicemenus/owlydrop.desktop"
    [ -e "$HOME/.config/kdrop.json" ] || { [ -e "$HOME/.config/owlydrop.json" ] && cp "$HOME/.config/owlydrop.json" "$HOME/.config/kdrop.json"; }
    echo "Removed the old Owly Drop widget (settings carried over)."
fi

echo "KDrop installed."
echo "Add it: right-click the panel → Add Widgets… → KDrop."
echo "After an update, reload Plasma: systemctl --user restart plasma-plasmashell"
