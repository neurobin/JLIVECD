
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

chkroot(){
	if [ "$(id -u)" != "0" ]; then
	  err_out "root access required."
	  exit 1
	fi
}

chknorm(){
	if [ "$(id -u)" = "0" ]; then
	  err_out "you need to run this as a normal user, not root."
	  exit 1
	fi
}

mode_select(){
	PS3='Please select a mode (#?): '
	opts="Ubuntu Debian ArchLinux"
	select opt in $opts; do #must not double quote
		case $opt in
		    ArchLinux)
		        echo archlinux >/dev/stdout
		        break
		        ;;
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


get_prop_val(){
	local prop="$1"
	local cf="$2"
	grep -isoP "(?<=^$prop=).*" "$cf" > /dev/stdout
}

chk_conf_prop(){
	local prop="$1"
	local cf="$2"
	if grep -isq "^[[:blank:]]*$prop=" "$cf";then
		return 0
	else
		return 1
	fi
}


update_prop_val(){
	local prop="$1"
	local val="$2"
	local cf="$3"
	local h=$4
	if chk_conf_prop "$prop" "$cf"; then
		# sed -E -i.bak "s/^[[:blank:]]*(RetainHome=).*/\1$val/I" "$cf"
		echo "$(awk "BEGIN{IGNORECASE=1} {sub(/^[[:blank:]]*$prop=.*$/,\"$prop=$val\");print}" "$cf")" > "$cf"
	else
		printf "${4+"\\n# $h\\n"}$prop=$val\n" >> "$cf"
	fi
}

get_yn(){
	#$1: msg
	#$2: timeout
	local msg="
	=== $(printf "$1")"
	msg=$(echo "$msg" |sed -e 's/^[[:blank:]]*//')
	local yn
    local timeout="$2"
	if [ "$timeout" = "" ]; then
		read -p "$msg" yn >/dev/null
	else
		read -t "$timeout" -p "$msg" yn >/dev/null
	fi
	if [ "$yn" = y ]; then
		echo y > /dev/stdout
    else
        echo "$yn" > /dev/stdout
	fi
}

get_prop_yn(){
	local prop="$1"
	local cf="$2"
	local msg="$3"
    local timeout="$4"
	local bval="${!prop}"
	local val="$bval"
	if [ "$bval" = "" ]; then
		val=$(get_prop_val "$prop" "$cf")
		[ "$val" = Y ] || [ "$val" = y ] || val=n
		local tval=$(get_yn "$msg (Y/n)? (default '$val'): " "$timeout")
		[ "$tval" = "" ] || val="$tval"
	fi
	echo "$val" >/dev/stdout
}

get_input(){
	#$1: msg
	#$2: timeout
	local msg="
	=== $(printf "$1")"
	msg=$(echo "$msg" |sed -e 's/^[[:blank:]]*//')
	local inp
	local timeout="$2"
	if [ "$timeout" = "" ]; then
		read -p "$msg" inp >/dev/null
	else
		read -t "$timeout" -p "$msg" inp >/dev/null
	fi
	echo "$inp" > /dev/stdout
}

get_prop_input(){
	local prop="$1"
	local cf="$2"
	local msg="$3"
    local timeout="$4"
	local bval="${!prop}"
	local val="$bval"
	if [ "$bval" = "" ]; then
		val=$(get_input "$msg" "$timeout")
		if [ "$val" = "" ]; then
			val=$(get_prop_val "$prop" "$cf")
		fi
	fi
	echo "$val" >/dev/stdout
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
    #~ if ! $JL_archlinux; then
        #~ cp /etc/hosts edit/etc/hosts
    #~ fi
    cp /etc/hosts edit/etc/
    rm -f edit/etc/resolv.conf || err_out "Could not remove resolv.conf, run 'JLopt -rn' if network isn't available"
    cp -L /etc/resolv.conf edit/etc/resolv.conf
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
	cp "$JL_sconf_file_d" "$JL_sconf"
	cd "$maindir"
}

get_initrd_name(){
	local path="$1"
	[ -d "$path" ] || return 1
	if [ -f "$path/initrd.gz" ]; then
		echo initrd.gz >/dev/stdout
	elif [ -f "$path/initrd.lz" ]; then
		echo initrd.lz >/dev/stdout
	elif [ -f "$path/initrd.img" ]; then
		echo initrd.img >/dev/stdout
	else
		return 1
	fi
	return 0
}

get_vmlinuz_path(){
	local path="$1"
	[ -d "$path" ] || return 1
	if [ -f "$path/vmlinuz" ]; then
		echo "$path/vmlinuz"  >/dev/stdout
	elif [ -f "$path/vmlinuz.efi" ]; then
		echo "$path/vmlinuz.efi"  >/dev/stdout
	else
		return 1
	fi
	return 0
}

update_cp(){
	if cp -L "$1" "$2"; then
		msg_out "updated $2"
		return 0
	else
		wrn_out "failed to update $2"
		return 1
	fi
}

update_mv(){
	if mv -f "$1" "$2"; then
		msg_out "updated $2/$(basename "$1")"
		return 0
	else
		wrn_out "failed to update $2/$(basename "$1")"
		return 1
	fi
}

abs_path(){
    if [ -d "$1" ]; then
        cd "$1"
        echo "$(pwd -P)"
    else
        cd "$(dirname "$1")"
        echo "$(pwd -P)/$(basename "$1")"
    fi
}

r_trim(){
    # ^ char in $2 not supported (needs extra care).
    echo "$1" |sed "s=[$2]*$=="
}

sanit_path(){
    echo "$1" |sed -e 's=//*=/=g' -e 's=/$=='
}

fstab_path(){
	local path=$1
	local s=
	local c=
	for i in $(seq 1 ${#path})
	do
		c=${path:i-1:1}
		s="$s$(printf '\\0%o' "'$c")"
	done
	echo "$s"  >/dev/stdout
}

insert_fsentry_fstab(){
	if [ "$edit" != "" ]; then
		proc="proc $(fstab_path "${edit}proc") proc defaults 0 0"
		sys="sysfs $(fstab_path "${edit}sys") sysfs defaults 0 0"
		devpts="devpts $(fstab_path "${edit}dev/pts") devpts defaults 0 0"
		dev="devtmpfs $(fstab_path "${edit}dev") devtmpfs defaults 0 0"
		arr=("$dev" "$devpts" "$proc" "$sys")
		for mp in "${arr[@]}"; do
			local fs=$(echo "$mp" |awk '{print $1}')
			mp=$(echo "$mp" |sed -e 's/\\/\\\\/g')
			sed -e "$ a $mp" --in-place=bak /etc/fstab && msg_out "added $fs entry for $edit in /etc/fstab"
		done
	else
		err_exit "\$edit can not be empty"
	fi
}

remove_fsentry_fstab(){
	local edit="$1"
	if [ "$edit" != "" ]; then
		proc="proc $(fstab_path "${edit}proc") proc defaults 0 0"
		sys="sysfs $(fstab_path "${edit}sys") sysfs defaults 0 0"
		devpts="devpts $(fstab_path "${edit}dev/pts") devpts defaults 0 0"
		dev="devtmpfs $(fstab_path "${edit}dev") devtmpfs defaults 0 0"
		arr=("$dev" "$devpts" "$proc" "$sys")
		for mp in "${arr[@]}"; do
			if grep -sqxF "$mp" /etc/fstab; then
				local fs=$(echo "$mp" |awk '{print $1}')
				pat="$(echo "$mp" |sed -e 's/[^^]/[&]/g' -e 's/\^/\\^/g')"
				sed -e "/^$pat$/d" --in-place=bak /etc/fstab && msg_out "removed $fs entry for $edit in /etc/fstab"
			fi
		done
	else
		wrn_out "\$edit can not be empty"
	fi
}

mount_fs(){
    edit=$(sanit_path "$edit")/ #must have / at end
	if [ "$edit" != "" ]; then
		insert_fsentry_fstab
		mount  devtmpfs "${edit}"dev -t devtmpfs && msg_out 'mounted dev'
		mount  devpts "${edit}"dev/pts -t devpts && msg_out 'mounted devpts'
		mount  proc "${edit}"proc -t proc && msg_out 'mounted proc'
		mount  sysfs "${edit}"sys -t sysfs && msg_out 'mounted sysfs'
	else
		err_exit "\$edit can not be empty"
	fi
}

umount_fs(){
	livedir=$(cat "$JLIVEdirF")
	if [ "$livedir" = "" ]; then
	    edit=edit/
	else
	    edit="$livedir/edit/"
	fi
    edit=$(sanit_path "$edit")/ #must have / at end
    mounted=$(mount |awk '{print $3}')
	if echo "$mounted" |grep -qF "${edit}"proc; then
		if umount "${edit}"proc || umount -lf "${edit}"proc ; then
			msg_out "unmount proc success"
		fi
	fi
	if echo "$mounted" |grep -qF "${edit}"sys; then
		if umount "${edit}"sys || umount -lf "${edit}"sys ; then
			msg_out "unmount sys success"
		fi
	fi
	if echo "$mounted" |grep -qF "${edit}"dev/pts; then
		if umount "${edit}"dev/pts || umount -lf "${edit}"dev/pts ; then
			msg_out "unmount devpts success"
		fi
	fi
	if echo "$mounted" |grep -qF "${edit}"dev; then
		if umount "${edit}"dev || umount -lf "${edit}"dev; then
			msg_out "unmount dev success"
		fi
	fi
	if echo "$mounted" |grep -qF "${livedir}/"mnt; then
		if umount "${livedir}/"mnt || umount -lf "${livedir}/"mnt; then
			msg_out "unmount mnt success"
		fi
	fi
	remove_fsentry_fstab "$edit"
	rm -rf "$JL_lockF" 2>/dev/null
	rm -rf "$JL_logdirtmp" 2>/dev/null
}

trap_with_arg() {
    func="$1" ; shift
    for sig in "$@" ; do
        trap "$func $sig" "$sig"
    done
}

finish(){
	umount_fs #backup unmounter
	if [ "$1" != "EXIT" ];then
		wrn_out "interrupted by signal: $1"
		exit 1
	else
		msg_out "END ***"
		exit 0
	fi
}


make_initrd(){
	local initrd=$1
	local kerver=$2
	$CHROOT mkinitramfs -o /"$initrd" "$kerver" &&
	msg_out "$initrd successfully built.." ||
	wrn_out "$initrd failed to be built (complete or partial)"
}

rebuild_initrd(){
    local initrd="$1"
    local kerver="$2"
	local vmlinuz_path=edit/boot/vmlinuz-"$kerver"
    mv -f edit/"$initrd" edit/"$initrd".old.link
    msg_out "Rebuilding initrd..."
    make_initrd "$initrd" "$kerver"
    update_mv edit/"$initrd" extracted/"$JL_casper"/
	update_cp "$vmlinuz_path" extracted/"$JL_casper"/"$vmlinuz_name"
    mv edit/"$initrd".old.link edit/"$initrd" &&
    msg_out "edit/$initrd updated." ||
	wrn_out "Could not update edit/$initrd"
	# if $JL_debian; then
	# 	#copy isolinux
	# 	update_cp edit/usr/lib/syslinux/isolinux.bin extracted/isolinux/isolinux.bin 2>/dev/null ||
	# 	update_cp edit/usr/lib/ISOLINUX/isolinux.bin extracted/isolinux/isolinux.bin 2>/dev/null ||
	# 	update_cp edit/usr/lib/isolinux/isolinux.bin extracted/isolinux/isolinux.bin 2>/dev/null
	# fi
}

rebuild_initramfs(){
    $CHROOT pacman -Syu --force archiso linux
    HOOKS='"base udev memdisk archiso_shutdown archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_kms block pcmcia filesystems keyboard"'
    sed -i.bak "s/HOOKS=\"[^\"]*\"/HOOKS=$HOOKS/" edit/etc/mkinitcpio.conf
    $CHROOT mkinitcpio -p linux
    update_cp edit/boot/vmlinuz-linux "extracted/arch/boot/$JL_arch/vmlinuz"
    update_cp edit/boot/initramfs-linux.img "extracted/arch/boot/$JL_arch/archiso.img"
    #update efi 
    mount -t vfat -o loop extracted/EFI/archiso/efiboot.img mnt
    cp extracted/arch/boot/$JL_arch/vmlinuz mnt/EFI/archiso/vmlinuz.efi || exit 1
    cp extracted/arch/boot/x86_64/archiso.img mnt/EFI/archiso/archiso.img || exit 1
}

jl_clean(){
	kerver=$(uname -r)
	cd "$livedir" #exported from jlcd_start
	rm -f edit/run/synaptic.socket
	$CHROOT aptitude clean 2>/dev/null
	$CHROOT dpkg-divert --rename --remove /sbin/initctl 2>/dev/null |sed 's/^/\n*** /'
	if [ -d edit/mydir ]; then
		mv -f edit/mydir ./
	fi
	rm -rf edit/tmp/*
	#rm edit/root/.bash_history # it is convenient to not delete it by default. You should clean up in final build manually.
	rm edit/var/lib/dbus/machine-id
	rm edit/sbin/initctl
	msg_out "You have $timeout seconds each to answer the following questions. if not answered, I will take 'n' as default (be ready). Some default may be different due to previous choice.\n"
	homec=$(get_prop_yn "$JL_rhpn" "$liveconfigfile" "Retain home directory" "$timeout")
	if [  "$homec" = Y ] || [ "$homec" = y ]; then
	  	msg_out "edit/home kept as it is"
	else
	  	rm -rf edit/home/*
	  	msg_out "edit/home cleaned!"
	fi
	update_prop_val "$JL_rhpn" "$homec"  "$liveconfigfile" "Whether to keep users home directory, by default it is deleted."
}

jl_clean_arch(){
	kerver=$(uname -r)
	cd "$livedir" #exported from jlcd_start
	if [ -d edit/mydir ]; then
		mv -f edit/mydir ./
	fi
	rm -rf edit/tmp/*
	rm edit/var/lib/dbus/machine-id
	rm edit/sbin/initctl
	$CHROOT $SHELL -c "LANG=C pacman -Sl | awk '/\[installed\]$/ {print \$1 \"/\" \$2 \"-\" \$3}' > /pkglist.txt"
	mv edit/pkglist.txt extracted/arch/pkglist.$JL_arch.txt
	msg_out "You have $timeout seconds each to answer the following questions. if not answered, I will take 'n' as default (be ready). Some default may be different due to previous choice.\n"
	homec=$(get_prop_yn "$JL_rhpn" "$liveconfigfile" "Retain home directory" "$timeout")
	if [  "$homec" = Y ] || [ "$homec" = y ]; then
	  	msg_out "edit/home kept as it is"
	else
	  	rm -rf edit/home/*
	  	msg_out "edit/home cleaned!"
	fi
	update_prop_val "$JL_rhpn" "$homec"  "$liveconfigfile" "Whether to keep users home directory, by default it is deleted."
}

jlcd_start(){
	export livedir=
	export liveconfigfile=
	export edit=
    if $JL_archlinux; then
        msg_out "Running in Arch Linux mode"
	elif $JL_debian; then
		msg_out "Running in Debian mode"
	else
		msg_out "Running in Ubuntu mode"
	fi
	JL_terminal1=$TERMINAL1
	JL_terminal2=$TERMINAL2
	command -v "$JL_terminal1" >/dev/null 2>&1 || JL_terminal1='x-terminal-emulator'
	command -v "$JL_terminal2" >/dev/null 2>&1 || JL_terminal2='xterm'

	if [ -f "$JL_lockF" ]; then
		err_out "another instance of this section is running. You need to finish that first. If it's a false positive, give y to force your way through."
		force=$(get_yn "Force start..(y/n)?: " 10)
		if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
			msg_out "Aborted."
			exit 1
		fi
	fi
	echo "1" > "$JL_lockF"

	trap_with_arg finish SIGTERM EXIT SIGQUIT

	maindir="$PWD"
	yn="$JL_fresh"
	livedir=""

	timeout=$TIMEOUT
	if echo "$timeout" |grep -qE '^[0-9]+$'; then
	  	timeout=$(echo $timeout |sed "s/^0*\([1-9]\)/\1/;s/^0*$/0/")
	else
		wrn_out "invalid timeout value: '$timeout'"
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
        IMAGENAME="$(isoinfo -d -i "$isopath" |sed -n 's/^[[:blank:]]*volume id:[[:blank:]]*\(.*\)$/\1/ip')"
		if [ -d edit ]; then
			wrn_out "seems this isn't really a new project (edit directory exists),existing files will be overwritten!!! if you aren't sure what this warning is about, close this terminal and run again. If this is shown again, enter y and continue..."
			cont=$(get_yn "Are you sure, you want to continue (y/n)?: " $timeout)
			if [  "$cont" = "y" ] || [ "$cont" = "Y" ]; then
			 	msg_out "OK"
			else
			 	msg_out "Exiting"
			 	exit 1
			fi
		fi
		mount -o loop "$isopath" mnt || wrn_out "failed to mount iso."
        rsync --exclude=/"$JL_squashfs" -a mnt/ extracted || err_exit "rsync failed"
        unsquashfs mnt/"$JL_squashfs" || err_exit "unsquashfs failed"
		mv squashfs-root edit || err_exit "couldn't move squashfs-root."
		edit=$(abs_path edit)/ #must end with a slash
		umount mnt || umount -lf mnt
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
	livedir=$(sanit_path "$livedir")
	liveconfigfile="$livedir/.config"
	touch "$liveconfigfile"
	chmod 777 "$liveconfigfile"
	edit=$(abs_path "$livedir/edit")/ #must end with a slash
    if [ "$IMAGENAME" = '' ]; then
        IMAGENAME="$(get_prop_val $JL_inpn "$liveconfigfile")"
    fi
    update_prop_val "$JL_inpn" "$IMAGENAME" "$liveconfigfile" "Do not modify if you don't know what you are doing."

	set -a
	if [ -f "$livedir/$JL_sconf"  ]; then
		. "$livedir/$JL_sconf"
	fi
	set +a

	if [ "$CHROOT" = "" ]; then
		CHROOT='chroot ./edit'
	elif ! command -v $CHROOT >/dev/null 2>&1; then
		wrn_out "invalid chroot command: $CHROOT\n--- falling back to default chroot."
		CHROOT='chroot ./edit'
	elif ! echo "$CHROOT" |grep -qE '^[[:blank:]]*s{0,1}chroot[[:blank:]]+[^[:blank:]]'; then
		wrn_out "invalid chroot command: $CHROOT\n--- falling back to default chroot."
		CHROOT='chroot ./edit'
	fi

	msg_out "chroot command: $CHROOT"

	cdname="$(get_prop_input "$JL_dnpn" "$liveconfigfile" "Enter your desired (customized) cd/dvd name: ")"
	iso="$(echo "$cdname" |tail -c 5)"
	iso="$(to_lower "$iso")"
	if [ "$iso" = ".iso" ]; then
	  cdname="$(echo "$cdname" | sed 's/....$//')"
	fi
	if [ "$cdname" = "" ]; then
		cdname="New-Disk"
		msg_out "Using 'New-Disk' as cd/dvd name"
	else
		msg_out "Using '$cdname' as cd/dvd name"
	fi
	update_prop_val "$JL_dnpn" "$cdname" "$liveconfigfile" "ISO image name without .iso"
	##############################Copy some required files#####################################################################
	cp main/preparechroot "$livedir"/edit/prepare
	cp main/help "$livedir"/edit/help
	cd "$livedir"
	msg_out "Entered into directory $livedir"
	##############################Enable network connection####################################################################
    cp -L /etc/hosts edit/.
    cp -L /etc/resolv.conf edit/.
	#refresh_network
    #JLopt -rn
	##############################cache management########################################################################
	msg_out "Cache Management starting. Moving package files to cache dir"
	cd "$livedir"
	if [ -d "debcache" ]; then
        if $JL_archlinux; then
            echo dummy123456 > debcache/dummy123456.pkg.tar.xz
            mv -f debcache/*.xz edit/var/cache/pacman/pkg/
            msg_out "pkg files moved. Cache Management complete!"
        else
            echo dummy123456 > debcache/dummy123456.deb
            mv -f debcache/*.deb edit/var/cache/apt/archives
            msg_out "deb files moved. Cache Management complete!"
        fi
	fi
	#more cache
	if [ -d mydir ] && [ -d edit ]; then
		mv -f mydir edit/
	elif [ -d edit ]; then
		mkdir edit/mydir
	fi
	chmod 777 edit/mydir
	msg_out 'use edit/mydir to store files that are not supposed to be included in the resultant livecd. This directory content persisits and thus you can keep source packages and other files here. An octal 777 permission is set for this directory, thus no root privilege required to copy files.'
	##############################Create chroot environment and prepare it for use#############################################
	msg_out "Detecting access control state"
	if xhost | grep 'access control enabled' >/dev/null; then
		bxhost='-'
		msg_out 'Access control is enabled'
	else
		bxhost='+'
		msg_out 'Access control is disabled'
	fi
	xh=$(get_prop_yn "$JL_xhpn" "$liveconfigfile" "Enable access control (prevent GUI apps to run)" "$timeout")
	update_prop_val "$JL_xhpn" "$xh" "$liveconfigfile" "Whether to prevent GUI apps to run."
	if [ "$xh" != Y ] && [ "$xh" != y ]; then
		xhost + >/dev/null && msg_out "access control disabled"
	else
		xhost - && msg_out "access control enabled"
	fi

    if ! $JL_archlinux; then
        msg_out "installing updarp in chroot ..."
        cp "$JLdir"/updarp edit/usr/bin/updarp
    fi

	mount_fs
	msg_out "Running chroot terminal... \nWhen you are finished, run: exit or simply close the chroot terminal. run 'cat help' or './help' to get help in chroot terminal."
	if ! $JL_terminal1 -e "$SHELL -c '$CHROOT /prepare;HOME=/root LC_ALL=C $CHROOT;exec $SHELL'" 2>/dev/null; then
		wrn_out "couldn't run $JL_terminal1, trying $JL_terminal2..."
		if ! $JL_terminal2 -e "$SHELL -c '$CHROOT /prepare;HOME=/root LC_ALL=C $CHROOT;exec $SHELL'" 2>/dev/null; then
			wrn_out "failed to run $JL_terminal2. Probably not installed!!"
			choice1=$(get_yn "Want to continue without chroot(Y/n)?: " $timeout)
			if [ "$choice1" = Y ] || [ "$choice1" = y ] ]];then
			  msg_out "Continuing without chroot. No modification will be done"
			else
			  err_out "counldn't run the chrootterminal, exiting..."
			  exit 2
			fi
		fi
	fi
    if ! $JL_archlinux; then
        msg_out "removing updarp ..."
        rm edit/usr/bin/updarp
    fi
	msg_out 'Restoring access control state'
	xhost $bxhost | sed 's/^/\n*** /' && msg_out "xhost restored to initial state."  #leave this variable unquoted
	##################################Debcache management############################################################
	msg_out "Cache Management starting. Moving package files to local cache dir"
	cd "$livedir"
	if [ ! -d "debcache" ]; then
	  mkdir debcache
	fi
    if $JL_archlinux; then
        echo dummy123456 > edit/var/cache/pacman/pkg/dummy123456.pkg.tar.xz
        mv -f edit/var/cache/pacman/pkg/*.xz debcache
        msg_out "pkg files moved. Cache Management complete!"
        $CHROOT pacman -Scc --noconfirm #cleaning cache
    else
        echo dummy123456 > edit/var/cache/apt/archives/dummy123456.deb
        mv -f edit/var/cache/apt/archives/*.deb debcache
        msg_out "deb files moved. Cache Management complete!"
    fi
	##################################Cleaning...#########################################
    if $JL_archlinux; then
        jl_clean_arch
    else
        jl_clean
    fi
	###############################Post Cleaning#####################################################################
	msg_out "Cleaning system"
	rm -f edit/prepare
	rm -f edit/help
	msg_out "System Cleaned!"
	##############################Checking for new installed kernel############################################################
	kerver=0
	d=2
	ker=""
	msg_out "##### Init script & Kernel related #####\nRebuild the initramfs if you have \n1. changed init scripts or kernel modules\n2. installed new kernel and want to boot that kernel in the live session."
	ker="$(get_yn "Rebuild initramfs: (y/n)?: " $timeout)"
	if [ "$ker" = "y" ] || [ "$ker" = "Y" ]; then
        if ! $JL_archlinux; then
            d=1
            ##################### managing initrd################
            msg_out "Finding initrd name ..."
            initrd=$(get_initrd_name "extracted/$JL_casper")
            if [ "$initrd" = ''  ]; then
                wrn_out "couldn't dtermine initrd name in: extracted/$JL_casper"
                initrd="$(get_input "Enter the name of initrd archive: ")"
            fi
            msg_out "initrd: $initrd"
            [ "$initrd" !=  "" ] || err_exit "initrd name can not be empty"

            ################# managing vmlinuz ###################
            msg_out "Finding vmlinuz ..."
            vmlinuz=$(get_vmlinuz_path "extracted/$JL_casper")
            if [ "$vmlinuz" = '' ]; then
                wrn_out "Couldn't find vmlinuz in: extracted/$JL_casper"
                vmlinuz_name=$(get_input "Enter the name of vmlinuz: ")
                vmlinuz="extracted/$JL_casper/$vmlinuz_name"
            fi
            export vmlinuz_name=$(basename "$vmlinuz")
            msg_out "vmlinuz: $vmlinuz_name"
            [ "$vmlinuz_name" != "" ] || err_exit "vmlinuz name can not be empty."
        else
            rebuild_initramfs
            d=2
        fi
	fi
    
    while [ $d -eq 1 ]
    do
        kerver="$(get_input "Enter the kernel version (take your time on this one) (n to skip, empty to use `uname -r`): ")"
        if [ "$kerver" = "n" ] || [ "$kerver" = "N" ]; then
            break
        elif [ "$kerver" = "" ]; then
            kerver=$(uname -r)
        fi
        vmlinuz_path=edit/boot/vmlinuz-"$kerver"
        if [ -f "$vmlinuz_path" ]; then
            rebuild_initrd "$initrd" "$kerver"
            d=2
        else
            err_out "no such kernel version: $kerver"
        fi
    done
        
	fastcomp=$(get_prop_yn "$JL_fcpn" "$liveconfigfile" "Use fast compression (ISO size may become larger)" "$timeout")
	update_prop_val "$JL_fcpn" "$fastcomp" "$liveconfigfile" "y: Fast compression, larger image size. n: smaller image but slower"
	#check for uefi
	uefi=$(get_prop_yn "$JL_ufpn" "$liveconfigfile" "Want UEFI image" "$timeout")
	update_prop_val "$JL_ufpn" "$uefi" "$liveconfigfile" "Whether the image to be built is a UEFI image"
	#check for nhybrid
	nhybrid=$(get_prop_yn "$JL_hbpn" "$liveconfigfile" "Prevent hybrid image" "$timeout")
	update_prop_val "$JL_hbpn" "$nhybrid" "$liveconfigfile" "Whether to prevent building hybrid image."
	msg_out "FASTCOMPRESSION=$fastcomp\n*** UEFI=$uefi\n*** NOHYBRID=$nhybrid"
	msg_out "Updating some required files..."
	###############################Create CD/DVD##############################################################################
	cd "$livedir"
    if ! $JL_archlinux; then
        chmod +w extracted/"$JL_casper"/filesystem.manifest 2>/dev/null
        $CHROOT dpkg-query -W --showformat='${Package} ${Version}\n' > extracted/"$JL_casper"/filesystem.manifest
    fi
	#no more CHROOT
	umount_fs
    if ! $JL_archlinux; then
        cp extracted/"$JL_casper"/filesystem.manifest extracted/"$JL_casper"/filesystem.manifest-desktop
        sed -i '/ubiquity/d' extracted/"$JL_casper"/filesystem.manifest-desktop
        sed -i "/$JL_casper/d" extracted/"$JL_casper"/filesystem.manifest-desktop
    fi
    rm -f extracted/"$JL_squashfs"
	msg_out "Deleted old squashfs.."
	msg_out "Rebuilding squashfs.."
	if [ "$fastcomp" = Y ] || [ "$fastcomp" = y ];then
	  msg_out "Using fast compression. Size may become larger"
	  mksquashfs edit extracted/"$JL_squashfs" -b 1048576 -e edit/boot
	else
	  msg_out "Using exhaustive compression. Size may become lesser"
	  #mksquashfs edit extracted/"$JL_squashfs" -comp xz
	  mksquashfs edit extracted/"$JL_squashfs" -comp xz -e edit/boot
	fi
    if ! $JL_archlinux; then
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
    else
        cd extracted
        msg_out "Updating md5sums"
        md5sum "$JL_squashfs" > "$(dirname "$JL_squashfs")/airootfs.md5"
    fi
	msg_out "Creating the image"
    
	if [ "$uefi" = Y ] || [ "$uefi" = y ];then
		genisoimage -U -A "$IMAGENAME" -V "$IMAGENAME" -volset "$IMAGENAME" -J -joliet-long -r -v -T -o ../"$cdname".iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot . && msg_out 'Prepared UEFI image'
		uefi_opt=--uefi
	else
		genisoimage -D -r -V "$IMAGENAME" -cache-inodes -J -no-emul-boot -boot-load-size 4 -boot-info-table -l -b isolinux/isolinux.bin -c isolinux/boot.cat -o ../"$cdname".iso .
		uefi_opt=
	fi
	if [ "$nhybrid" != Y ] && [ "$nhybrid" != y ]; then
		isohybrid $uefi_opt ../"$cdname".iso && msg_out "Converted to hybrid image" || wrn_out "Could not convert to hybrid image"
	fi
	cd ..
	msg_out "Finalizing image"
	chmod 777 "$cdname".iso
	msg_out ".All done. Check the result."
	read -p "Press enter to exit" enter
	exit 0
}
