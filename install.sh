#!/bin/bash
cd "$(dirname "$BASH_SOURCE")"
sudo -s bash <<EOF
mkdir -p /usr/local/JLIVECD
cp -R ./* /usr/local/JLIVECD/
cp -R ./.[^.g]* /usr/local/JLIVECD/
chmod -R 777 /usr/local/JLIVECD
cd /usr/local/JLIVECD
chmod 755 updarp JLstart JLopt main/custom_desktop main/preparechroot main/help funcs.sh install.sh main/JLRefreshNetwork defconf.sh
ln -sf /usr/local/JLIVECD/JLstart /bin/JLstart
ln -sf /usr/local/JLIVECD/JLstart /usr/bin/jlstart
ln -sf /usr/local/JLIVECD/JLopt /bin/JLopt
ln -sf /usr/local/JLIVECD/JLopt /usr/bin/jlopt
ln -sf /usr/local/JLIVECD/updarp /usr/bin/updarp
echo "[Desktop Entry]
Name=JLIVECD
Type=Application
Exec=JLstart
Terminal=true
Icon=/usr/local/JLIVECD/main/48.png
Categories=Development;
Comment=Live CD/DVD customization tool (CLI)" > /usr/share/applications/JLIVECD.desktop
echo ".......Install complete!"
echo ".......See the readme file provided with this software for instructions on how to use it......"
EOF
