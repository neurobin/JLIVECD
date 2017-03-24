
msg_out(){
	printf "\n*** $*\n" > /dev/stdout
}

err_out(){
	printf "\nE: $*\n" > /dev/stderr
}

wrn_out(){
	printf "\nW: $*\n" > /dev/stderr
}

err_exit(){
	err_out "$*"
	exit 1
}

finish(){
 rm -rf "$JL_lockF" 2>/dev/null
 rm -rf "$JL_logdirtmp" 2>/dev/null
 msg_out "cleaned temporary files"
}

chkroot(){
	if [ "$(id -u)" != "0" ]; then
	  err_out "root access required."
	  exit 1
	fi
}

chknorm(){
	if [ "$(id -u)" = "0" ] && ! $JL_debian; then
	  err_out "you need to run this as a normal user, not root."
	  exit 1
	fi
}

mode_select(){
	PS3='Please select a mode (#): '
	opts="Ubuntu Debian"
	select opt in $opts; do #must not double quote
		case $opt in
			Ubuntu)
				echo ubuntu >/dev/stdout
				break
				;;
			Debian)
				echo debian >/dev/stdout
				break
				;;
		esac
	done
}

get_yn(){
	#$1: msg
	#$2: timeout
	local msg="
	=== $(printf "$1")"
	msg=$(echo "$msg" |sed -e 's/^[[:blank:]]*//')
	local yn
	if [ "$2" = "" ]; then
		read -p "$msg" yn >/dev/null
	else
	    if ! echo "$timeout" |grep -E '^[0-9]+$' >/dev/null; then
	        err_exit "invalid timeout value: $timeout"
	    fi
		read -t "$2" -p "$msg" yn >/dev/null
	fi
	if [ "$yn" = y ]; then
		echo y > /dev/stdout
	else
		echo '' > /dev/stdout
	fi
}

get_input(){
	#$1: msg
	#$2: timeout
	local msg="
	=== $(printf "$1")"
	msg=$(echo "$msg" |sed -e 's/^[[:blank:]]*//')
	local inp
	if [ "$2" = "" ]; then
		read -p "$msg" inp >/dev/null
	else
	    if ! echo "$timeout" |grep -E '^[0-9]+$' >/dev/null; then
	        err_exit "invalid timeout value: $timeout"
	    fi
		read -t "$2" -p "$msg" inp >/dev/null
	fi
	echo "$inp" > /dev/stdout
}

sed_fxrs(){
	echo "$*" | sed -e 's/&/\&/g' -e 's#/#\\\/#g' > /dev/stdout
}

to_lower(){
	echo "$*" | tr '[:upper:]' '[:lower:]' > /dev/stdout
}

expand_path() {
  case "$1" in
    ~[+-]*)
      local content content_q
      printf -v content_q '%q' "${1:2}"
      eval "content=${1:0:2}${content_q}"
      printf '%s\n' "$content" > /dev/stdout
      ;;
    ~*)
      local content content_q
      printf -v content_q '%q' "${1:1}"
      eval "content=~${content_q}"
      printf '%s\n' "$content" > /dev/stdout
      ;;
    *)
      printf '%s\n' "$1" > /dev/stdout
      ;;
  esac
}

refresh_network(){
	if [ -f "$JLIVEdirF" ]; then
	  livedir="$(cat "$JLIVEdirF")"
	else
	  wrn_out "May be this is a new project, run JLstart instead"
	  exit 1
	fi
	cd "$livedir"
	msg_out "Preparing network connection for chroot in $livedir..."
	cp /etc/hosts edit/etc/
	rm edit/etc/resolv.conf
	cp -L /etc/resolv.conf edit/etc/
	msg_out "Network connection shlould be available in chroot now....."
}

fresh_start(){
	chknorm || exit 1
	maindir="$PWD"
	c=1
	d=1
	while [ $c -eq 1 ]
	do
	  c=2
	  livedir="$(get_input "Where do you want to save your project ? Choose a directory where you have full permission. Enter path: ")"
	  livedir="$(expand_path "$livedir")"
	  [ -d "$livedir" ] && wrn_out "$livedir exists, content will be overwritten" || mkdir -p "$livedir"
	  if [ ! -d "$livedir" ]; then
		c=1
		err_out "invalid directory name/path: $livedir"
	   fi
	done
	cd "$livedir"
	[ -d mnt ] && wrn_out "$livedir/mnt Exists, Content will be overwritten" || mkdir mnt
	while [ $d -eq 1 ]
	do
	  d=2
	  isopath="$(get_input "Enter the path to your base iso image: ")"
	  isopath="$(expand_path "$isopath")"
	  isofullpath=("${isopath}"*)
	  if [ -f "$isofullpath" ]; then
		iso="$(echo "$isofullpath" |tail -c 5)"
		iso="$(to_lower "$iso")"
		if [ "$iso" = ".iso" ]; then
		  msg_out "Found iso: $isofullpath"
		  echo "$isofullpath" > "$JLIVEisopathF"
		else
		  d=1
		  wrn_out "selected file isn't an ISO image: $isofullpath"
		fi
	  elif [ -f "$isofullpath.iso" ]; then
		msg_out "Found iso: $isofullpath.iso"
		echo "$isofullpath".iso > "$JLIVEisopathF"
	  else
		d=1
		wrn_out "couldn't find the iso"
	  fi
	done
	[ -d extracted ] && wrn_out "$livedir/extracted exists, content will be overwritten" || mkdir extracted
	rm -f "$JLIVEdirF"
	echo "$livedir" > "$JLIVEdirF"
	cd "$maindir"
}

rebuild_initrd(){
    initrd="$1"
    kerver="$2"
    mv edit/"$initrd" edit/"$initrd".old.link
    msg_out "Rebuilding initrd..."
    mount --bind /dev/ edit/dev
    chroot edit mount -t proc none /proc
    chroot edit mount -t sysfs none /sys
    chroot edit mount -t devpts none /dev/pts
    chroot edit mkinitramfs -o /"$initrd" "$kerver"
    chroot edit umount /proc || chroot edit umount -lf /proc
    chroot edit umount /sys
    chroot edit umount /dev/pts
    umount edit/dev || umount -lf edit/dev
    mv edit/"$initrd" extracted/"$JL_casper"/
    mv edit/"$initrd".old.link edit/"$initrd"
    msg_out "initrd rebuilt successfully!"
}

jl_clean(){
	kerver=$(uname -r)
	livedir="$(cat "$JLIVEdirF")"
	liveconfigfile="$livedir/.config"
	timeout="$(grep -soP '(?<=^timeout=).*' "$JL_configfile")"
	if echo "$timeout" |grep -E '^[0-9]+$'; then
	  timeout=$(echo "$timeout" |sed "s/^0*\([1-9]\)/\1/;s/^0*$/0/")
	else
	  timeout="$JL_timeoutd"
	fi
	homec="$(grep -soP '(?<=^RetainHome=).*' "$liveconfigfile")"
	[ "$homec" = Y ] || [ "$homec" = y ] || homec="n"
	cd "$livedir"
	initrd="$(cat edit/initrd)"
	rm -f edit/run/synaptic.socket
	chroot edit aptitude clean 2>/dev/null
	chroot edit rm -r /mydir
	chroot edit rm -rf /tmp/* ~/.bash_history
	chroot edit rm /var/lib/dbus/machine-id
	chroot edit rm /sbin/initctl
	chroot edit dpkg-divert --rename --remove /sbin/initctl 2>/dev/null
	chroot edit umount /proc || chroot edit umount -lf /proc
	chroot edit umount /sys
	chroot edit umount /dev/pts
	umount edit/dev || umount -lf edit/dev
	rm -f "$JL_lockF"
	msg_out "You have $timeout seconds each to answere the following questions:\n*** if not answered, I will take 'n' as default (be ready).\n*** Some default may be different due to previous choice.\n"
	home=$(get_yn "Want to retain edit/home directory? (y/n)? (default '$homec'): " $timeout)
	[ "$home" = "" ] && home=$homec
	if [  "$home" = Y ] || [ "$home" = y ]; then
	  msg_out "edit/home kept as it is"
	else
	  rm -rf edit/home/*
	  msg_out "edit/home cleaned!"
	fi
	if grep -sq '^RetainHome=' "$liveconfigfile";then
	   sed -r -i.bak "s/(^RetainHome=).*/\1$home/" "$liveconfigfile"
	else
		echo "RetainHome=$home" >> "$liveconfigfile"
	fi
	msg_out "initrd archive type: $initrd detected!"
	msg_out "Rebuilding initrd!\n*** this step is needed if you have modified the kernel module, or init scripts.\n*** If you have installed new kernel and want to boot that kernel then skip this for now"

	choice=$(get_yn "Have you modified init script or kernel module? (y/n)?: " $timeout)
	c=1
	if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
		c=2
	fi
	while [ $c -eq 1 ]
	do
	  if [ -d "edit/lib/modules/$kerver" ]; then
		rebuild_initrd "$initrd" "$kerver"
		c=2
	  else
		kerver="$(get_input "Enter live system kernel version (n to skip/default, take your time on this one): ")"
	  fi
	  if [ "$kerver" = "n" ] || [ "$kerver" = "N" ]; then
		c=2
	  fi
	done

}


jlcd_start(){
	if $JL_debian; then
		msg_out "Running in Debian mode"
	else
		msg_out "Running in Ubuntu mode"
	fi
	JL_terminal1="$(grep -soP '(?<=^terminal1=).*' "$JL_configfile")"
	JL_terminal2="$(grep -soP '(?<=^terminal2=).*' "$JL_configfile")"
	command -v "$JL_terminal1" >/dev/null 2>&1 || JL_terminal1='x-terminal-emulator'
	command -v "$JL_terminal2" >/dev/null 2>&1 || JL_terminal2='xterm'

	if [ -f "$JL_lockf" ]; then
	  err_out "another instance of this section is running\n or premature shutdown detected from a previous run\nYou need to finish that first or force your way through..."
	  force=$(get_yn "Force start..(y/n)?: " 10)
	  if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
		msg_out "Aborted."
		exit 1
	  fi
	fi
	echo "1" > "$JL_lockF"

	maindir="$PWD"
	yn="$JL_fresh"
	livedir=""

	timeout="$(grep -soP '(?<=^timeout=).*' "$JL_configfile")"
	if echo "$timeout" |grep -E '^[0-9]+$'; then
	  timeout=$(echo $timeout |sed "s/^0*\([1-9]\)/\1/;s/^0*$/0/")
	else
	  timeout=$JL_timeoutd
	fi

	if [ -f "$JLIVEdirF" ]; then
	  livedir="$(cat "$JLIVEdirF")"
	fi

	c=1
	if [ "$yn" = "y" ]; then
	  c=2
	  cd "$livedir"
	  isopath="$(cat "$JLIVEisopathF")"
	  if [ -d edit ]; then
		wrn_out "seems this isn't really a new project (edit directory exists),\nexisting files will be overwritten!!!\n if you aren't sure what this warning is about, close this terminal and run again. \nIf this is shown again, enter y and continue..."
		cont=$(get_yn "Are you sure, you want to continue (y/n)?: " $timeout)
		if [  "$cont" = "y" ] || [ "$cont" = "Y" ]; then
		  msg_out "OK"
		else
		  msg_out "Exiting"
		  exit 1
		fi
	  fi
	  mount -o loop "$isopath" mnt || wrn_out "failed to mount iso."
	  rsync --exclude=/"$JL_casper"/filesystem.squashfs -a mnt/ extracted || err_exit "rsync failed"
	  unsquashfs mnt/"$JL_casper"/filesystem.squashfs || err_exit "unsquashfs failed"
	  mv squashfs-root edit || err_exit "couldn't move squashfs-root."
	  umount mnt
	fi
	cd "$maindir"
	c=1
	while [ $c -eq 1 ]
	do
	  if [ "$yn" != "y" ]; then
		msg_out "If you just hit enter it will take your previous choice (if any)"
		livedir="$(get_input "Enter the directory path where you have saved your project: ")"
		livedir="$(expand_path "$livedir")"
		if [ "$livedir" = "" ]; then
		  if [ -f "$JLIVEdirF" ]; then
		    livedir="$(cat "$JLIVEdirF")"
		    msg_out "previous: $livedir"
		  fi
		elif [ -d "$livedir" ]; then
		  echo "$livedir" > "$JLIVEdirF"
		fi
	  fi
	  if [ "$livedir" != "" ]; then
		c=2
	  else
		c=1
		err_out "invalid directory: $livedir"
	  fi
	  if [ -d "$livedir" ]; then
		c=2
	  else
		c=1
		err_out "directory doesn't exist: $livedir"
	  fi
	done
	liveconfigfile="$livedir/.config"
	touch "$liveconfigfile"
	chmod 777 "$liveconfigfile"
	msg_out "If you just hit enter it will take your previous choice (if any)"
	cdname="$(get_input "Enter your desired (customized) cd/dvd name: ")"
	iso="$(echo "$cdname" |tail -c 5)"
	iso="$(to_lower "$iso")"
	if [ "$iso" = ".iso" ]; then
	  cdname="$(echo "$cdname" | sed 's/....$//')"
	fi
	if [ "$cdname" = "" ]; then
	  if [ -f "$liveconfigfile" ]; then
		cdname="$(grep -soP '(?<=^DiskName=).*' "$liveconfigfile")"
		if [ "$cdname" = "" ]; then
			cdname="New-Disk"
			msg_out "Using 'New-Disk' as cd/dvd name"
		else
			msg_out "Using previously used name: $cdname"
		fi
	  else
		cdname="New-Disk"
		msg_out "\n*** Using 'New-Disk' as cd/dvd name"
	  fi
	fi
	if grep -sq '^DiskName=' "$liveconfigfile";then
	   sed -r -i.bak "s/(^DiskName=).*/\1$(sed_fxrs "$cdname")/" "$liveconfigfile"
	else
		echo "DiskName=$cdname" >> "$liveconfigfile"
	fi
	##############################Copy some required files#####################################################################
	cp main/preparechroot "$livedir"/edit/prepare
	cp main/help "$livedir"/edit/help
	cd "$livedir"
	msg_out "Entered into directory $livedir"
	##################### managing initrd################
	msg_out "managing initrd..."
	if [ -f "extracted/$JL_casper/initrd.lz" ]; then
	  initrd="initrd.lz"
	  msg_outdev/null "Found: $initrd"
	elif [ -f "extracted/$JL_casper/initrd.gz" ]; then
	  initrd="initrd.gz"
	  msg_out "Found: extracted/$JL_casper/$initrd"
	elif [ -f "extracted/$JL_casper/initrd.img" ]; then
	  initrd="initrd.img"
	  msg_out "Found: extracted/$JL_casper/$initrd"
	else
	  msg_out "couldn't dtermine initrd type"
	  initrd="$(get_input "Enter the name of initrd archive: ")"
	fi
	rm -f edit/initrd #name of the initrd is saved here.
	echo "$initrd" > edit/initrd
	##############################Enable network connection####################################################################
	#msg_out "Preparing network connection for chroot....."
	#cp /"$JL_resolvconf" edit/"$JL_resolvconf"
	#cp /etc/hosts edit/etc/
	#msg_out "\tdone"
	refresh_network
	##############################Debcache management########################################################################
	msg_out "Debcache Management starting\n*** Moving deb files to edit/var/cache/apt/archives"
	cd "$livedir"
	if [ -d "debcache" ]; then
	  echo dummy123456 > debcache/dummy123456.deb
	  mv -f debcache/*.deb edit/var/cache/apt/archives
	  msg_out "deb files moved. Debcache Management complete!"
	fi
	##############################Create chroot environment and prepare it for use#############################################
	mount --bind /dev/ edit/dev
	msg_out "Detecting access control state"
	if xhost | grep 'access control enabled' >/dev/null; then
		bxhost='-'
		msg_out 'Access control is enabled'
	else
		bxhost='+'
		msg_out 'Access control is disabled'
	fi
	dxhost="$(grep -soP '(?<=^xhost=).*' "$liveconfigfile")"
	if [ "$bxhost" = '+' ]; then
		xh=$(get_yn"Enable access control (prevent GUI apps to run) (Y/n)? (default '$dxhost'): " $timeout)
	else
		xh=$(get_yn "Keep access control enabled (prevent GUI apps to run) (Y/n)? (default '$dxhost'): " $timeout)
	fi
	[ "$xh" = "" ] && xh="$dxhost"
	if grep -sq '^xhost=' $liveconfigfile; then
	   sed -r -i.bak "s/(^xhost=).*/\1$xh/" "$liveconfigfile"
	else
		echo "xhost=$xh" >> "$liveconfigfile"
	fi
	if [ "$xh" != Y ] && [ "$xh" != y ]; then
		xhost +
	else
		xhost -
	fi

	msg_out "Running chroot terminal...\n*** When you are finished, run: exit or simply close the chroot terminal.\n\n*** run 'cat help' or './help' to get help in chroot terminal."
	if ! $JL_terminal1 -e "$SHELL -c 'chroot ./edit ./prepare;HOME=/root LC_ALL=C chroot ./edit;exec $SHELL'" 2>/dev/null; then
		wrn_out "couldn't run $JL_terminal1, trying $JL_terminal2..."
		if ! $JL_terminal2 -e "$SHELL -c 'chroot ./edit ./prepare;HOME=/root LC_ALL=C chroot ./edit;exec $SHELL'" 2>/dev/null; then
			wrn_out "failed to run $JL_terminal2. Probably not installed!!"
			choice1=$(get_yn "Want to continue without chroot (Y/n)?: " $timeout)
			if [ "$choice1" = Y ] || [ "$choice1" = y ] ]];then
			  msg_out "Continuing without chroot. No modification will be done"
			else
			  err_out "counldn't run the chroot terminal, exiting..."
			  exit 2
			fi
		fi
	fi
	msg_out 'Restoring access control state'
	xhost $bxhost #leave this variable unquoted
	##################################Debcache management############################################################
	msg_out "Debcache Management starting\n*** Moving .deb files to debcache"
	cd "$livedir"
	if [ ! -d "debcache" ]; then
	  mkdir debcache
	fi
	echo dummy123456 > edit/var/cache/apt/archives/dummy123456.deb
	mv -f edit/var/cache/apt/archives/*.deb debcache
	msg_out "deb files moved. Debcache Management complete!"
	##################################Cleaning...#########################################
	jl_clean
	rm -f "$JL_lockF"
	if [ -f "edit/$initrd" ]; then
	  cp -L edit/"$initrd" extracted/"$JL_casper"/
	else
	  msg_out "Assuming: you haven't modified the kernel modules or init scripts"
	fi
	###############################Post Cleaning#####################################################################
	msg_out "Cleaning system"
	rm -f edit/initrd
	rm -f edit/prepare
	rm -f edit/help
	msg_out "System Cleaned!"
	##############################Checking for new installed kernel############################################################
	kerver=0
	if [ -f "extracted/$JL_casper/vmlinuz" ]; then
	  vmlinuz="extracted/$JL_casper/vmlinuz"
	  msg_out "vmlinuz found: $vmlinuz"
	elif [ -f "extracted/$JL_casper/vmlinuz.efi" ]; then
	  vmlinuz="extracted/$JL_casper/vmlinuz.efi"
	  msg_out "vmlinuz found: $vmlinuz"
	else
	  msg_out "Couldn't find vmlinuz!"
	  vmlinuz=$(get_input "Enter the name of vmlinuz: ")
	  vmlinuz="extracted/$JL_casper/$vmlinuz"
	fi
	d=2
	ker=""
	msg_out "Kernel related Qs"
	ker="$(get_yn "Have you installed new kernel and want to boot the new kernel in live cd/dvd: (y/n)?: " $timeout)"
	if [ "$ker" = "y" ] || [ "$ker" = "Y" ]; then
		d=1
	fi
	while [ $d -eq 1 ]
	do
	  kerver="$(get_input "Enter the kernel version (take your time on this one): ")"
	  vmlinuz_path=edit/boot/vmlinuz-"$kerver"
	  initrd_path=edit/boot/initrd.img-"$kerver"
	  if [ -f "$vmlinuz_path" ]; then
		if [ -f "$initrd_path" ]; then
		  cp edit/boot/vmlinuz-"$kerver" "$vmlinuz"
		#   cp edit/boot/initrd.img-"$kerver" extracted/$JL_casper/"$initrd"
		  rebuild_initrd "$initrd" "$kerver"
		  msg_out "kernel updated successfully!"
		  d=2
		else
		  wrn_out "couldn't find the specified kernel!\nEnter n to skip or enter the right version"
		fi
	  else
		wrn_out "couldn't find the specified kernel!\nEnter n to skip or enter the right version"
	  fi
	  if [ "$kerver" = "n" ] || [ "$kerver" = "N" ]; then
		d=2
	  fi
	done
	fastcomp="$(grep -soP '(?<=^FastCompression=).*' "$liveconfigfile")"
	choice1=$(get_yn "Use fast compression (ISO size may become larger) (Y/n)? (default '$fastcomp'): " $timeout)
	[ "$choice1" = "" ] && choice1="$fastcomp"
	if grep -sq '^FastCompression=' "$liveconfigfile";then
	   sed -r -i.bak "s/(^FastCompression=).*/\1$choice1/" "$liveconfigfile"
	else
		echo "FastCompression=$choice1" >> "$liveconfigfile"
	fi
	#check for uefi
	uefi="$(grep -soP '(?<=^UEFI=).*' "$liveconfigfile")"
	choice2=$(get_yn "Want UEFI image (Y/n)? (default '$uefi'): " $timeout)
	[ "x$choice2" = "x" ] && choice2="$uefi"
	if grep -sq '^UEFI=' $liveconfigfile;then
	   sed -r -i.bak "s/(^UEFI=).*/\1$choice2/" "$liveconfigfile"
	else
		echo "UEFI=$choice2" >> $liveconfigfile
	fi
	#check for hybrid
	hybrid="$(grep -soP '(?<=^Hybrid=).*' "$liveconfigfile")"
	choice3=$(get_yn "Want hybrid image (Y/n)? (default '$hybrid'): " $timeout)
	[ "$choice3" = "" ] && choice3="$hybrid"
	if grep -sq '^Hybrid=' "$liveconfigfile";then
	   sed -r -i.bak "s/(^Hybrid=).*/\1$choice3/" "$liveconfigfile"
	else
		echo "Hybrid=$choice3" >> "$liveconfigfile"
	fi
	msg_out "Updating some required files..."
	###############################Create CD/DVD##############################################################################
	cd "$livedir"
	chmod +w extracted/"$JL_casper"/filesystem.manifest 2>/dev/null
	chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extracted/"$JL_casper"/filesystem.manifest
	cp extracted/"$JL_casper"/filesystem.manifest extracted/"$JL_casper"/filesystem.manifest-desktop
	sed -i '/ubiquity/d' extracted/"$JL_casper"/filesystem.manifest-desktop
	sed -i "/"$JL_casper"/d" extracted/"$JL_casper"/filesystem.manifest-desktop
	rm -f extracted/"$JL_casper"/filesystem.squashfs
	msg_out "Deleted old filesystem.squashfs.."
	msg_out "Rebuilding filesystem.squashfs.."
	if [ "$choice1" = Y ] || [ "$choice1" = y ];then
	  msg_out "Using fast compression. Size may become larger"
	  mksquashfs edit extracted/"$JL_casper"/filesystem.squashfs -b 1048576
	else
	  msg_out "Using exhaustive compression. Size may become lesser"
	  #mksquashfs edit extracted/"$JL_casper"/filesystem.squashfs -comp xz
	  mksquashfs edit extracted/"$JL_casper"/filesystem.squashfs -comp xz -e edit/boot
	fi
	printf $(du -sx --block-size=1 edit | cut -f1) > extracted/"$JL_casper"/filesystem.size
	cd extracted
	msg_out "Updating md5sums"
	if [ -f "MD5SUMS" ]; then
	  rm MD5SUMS
	  find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee MD5SUMS
	fi
	if [ -f "md5sum.txt" ]; then
	  rm md5sum.txt
	  find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt
	fi
	msg_out "Creating the image"
	if [ "$choice2" = Y ] || [ "$choice2" = y ];then
		genisoimage -U -A "$IMAGE_NAME" -V "$IMAGE_NAME" -volset "$IMAGE_NAME" -J -joliet-long -r -v -T -o ../"$cdname".iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot . && msg_out 'Prepared UEFI image'
		uefi_opt=--uefi
	else
		genisoimage -D -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../"$cdname".iso .
		uefi_opt=
	fi
	if [ "$choice3" = Y ] || [ "$choice3" = y ]; then
		isohybrid $uefi_opt ../"$cdname".iso && msg_out "Converted to hybrid image"
	fi
	cd ..
	msg_out "Finalizing image"
	chmod 777 "$cdname".iso
	msg_out ".All done. Check the result."
	read -p "Press enter to exit" enter
	exit 0
}
