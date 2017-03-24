#!/bin/bash
cd "$(dirname "$BASH_SOURCE")"
sudo -sk <<EOF
mkdir -p /usr/local/JLIVECD
cp -R ./* /usr/local/JLIVECD/
chmod -R 777 /usr/local/JLIVECD
chmod 755 /usr/local/JLIVECD/JLstart /usr/local/JLIVECD/JLopt /usr/local/JLIVECD/main/custom_desktop /usr/local/JLIVECD/main/preparechroot /usr/local/JLIVECD/main/help
ln -sf /usr/local/JLIVECD/JLstart /bin
ln -sf /usr/local/JLIVECD/JLopt /bin
echo "[Desktop Entry]
Name=JLIVECD
Type=Application
Exec=JLstart
Terminal=true
Icon=/usr/local/JLIVECD/main/48.png
Categories=System;
Comment=Live CD/DVD customization tool (CLI)" > /usr/share/applications/JLIVECD.desktop
echo ".......Install complete!"
echo ".......See the readme file provided with this software for instructions on how to use it......"
EOF
