#!/bin/bash
# Removes KDrop for the current user. Settings in ~/.config/kdrop.json are kept.
systemctl --user stop kdrop-send kdrop-receive kdrop-browse kdrop-radio-off.timer kdrop-radio 2>/dev/null
kpackagetool6 -t Plasma/Applet -r io.github.erdeemaydin.kdrop
rm -f "$HOME/.local/bin/kdrop" "$HOME/.local/share/kio/servicemenus/kdrop.desktop"
echo "KDrop removed. Delete ~/.config/kdrop.json too if you want to forget its settings."
