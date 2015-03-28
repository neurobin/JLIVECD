BASEDIR=`dirname "${0}"`
cd "$BASEDIR"
sudo chmod -R 755 *
sudo rm -rf /usr/local/JLIVECD
sudo mkdir -p /usr/local/JLIVECD
sudo cp -R . /usr/local/JLIVECD
sudo chmod -R 755 /usr/local/JLIVECD
sudo cp JLstart /bin
sudo cp main/JLRefreshNetwork /bin
sudo -s <<EOF
echo -e "[Desktop Entry]\nName=JLIVECD\nType=Application\nExec=JLstart\nTerminal=true\nIcon=/usr/local/JLIVECD/main/48.png\nCategories=System;\nComment=Live CD/DVD customization tool (CLI)" > /usr/share/applications/JLIVECD.desktop
EOF
echo ".......Install complete!"
echo ".......See the readme file provided with this software for instructions to use it......"
