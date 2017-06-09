# ##############################################################################
# ############################### JLIVECD ######################################
# ##############################################################################
#            Copyright (c) 2015-2017 Md. Jahidul Hamid
# 
# -----------------------------------------------------------------------------
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
# 
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
# 
#     * The names of its contributors may not be used to endorse or promote 
#       products derived from this software without specific prior written
#       permission.
#       
# Disclaimer:
# 
#     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#     AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#     IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#     ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
#     LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#     CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#     SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#     INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#     CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#     ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#     POSSIBILITY OF SUCH DAMAGE.
# ##############################################################################

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
	  wrn_out "Running as root not recommended. May produce some problems. Better run as a normal user."
	  return 1
	fi
}

mode_select(){
    echo >/dev/stderr
    echo "***************** MODE SELECT *****************" >/dev/stderr
    echo "* For Ubuntu family & Linux Mint: ubuntu mode *" >/dev/stderr
    echo "* For Debian:                     debian mode *" >/dev/stderr
    echo "* For archlinux:               archlinux mode *" >/dev/stderr
    echo "***********************************************" >/dev/stderr
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
        tval="$(get_prop_val "$prop" "$cf")"
		val=$(get_input "$msg (default '$tval'): " "$timeout")
		if [ "$val" = "" ]; then
			val="$tval"
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

get_iso_label(){
    isoinfo -d -i "$1" |sed -n 's/^[[:blank:]]*volume id:[[:blank:]]*\(.*\)$/\1/ip'
}

du_size_ex_initramfs(){
    # $1: path
    # $2: block size
    du --block-size=$2 --exclude='archiso.img' --exclude='vmlinuz.efi' -s "$1" 2>/dev/null |sed -n 's/^[[:blank:]]*\([0-9][0-9]*\).*/\1/p'
}

du_size(){
    # $1: path
    # $2: block size
    du --block-size=$2 -s "$1" 2>/dev/null |sed -n 's/^[[:blank:]]*\([0-9][0-9]*\).*/\1/p'
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
	#chknorm
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
        chown 1000:1000 "$livedir"
	done
	cd "$livedir"
	[ -d mnt ] && wrn_out "$livedir/mnt Exists, Content will be overwritten" || mkdir mnt
    chown 1000:1000 mnt
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
    chown 1000:1000 extracted
	rm -f "$JLIVEdirF"
	echo "$livedir" > "$JLIVEdirF"
	cp "$JL_sconf_file_d" "$JL_sconf"
    chown 1000:1000 "$JL_sconf"
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
    local f="$2"
    if [ -d "$f" ]; then
        f="$f/$(basename "$1")"
    fi
	if mv -f "$1" "$2"; then
		msg_out "updated $f"
		return 0
	else
		wrn_out "failed to update $f"
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
    mv -f edit/"$initrd" edit/"$initrd".old.link 2>/dev/null
    msg_out "Rebuilding initrd for $kerver ..."
    make_initrd "$initrd" "$kerver"
    update_mv edit/"$initrd" extracted/"$JL_casper"/
	update_cp "$vmlinuz_path" extracted/"$JL_casper"/"$vmlinuz_name"
    mv edit/"$initrd".old.link edit/"$initrd" 2>/dev/null # &&
    # msg_out "edit/$initrd updated." ||
	# wrn_out "Could not update edit/$initrd"
	# if $JL_debian; then
	# 	#copy isolinux
	# 	update_cp edit/usr/lib/syslinux/isolinux.bin extracted/isolinux/isolinux.bin 2>/dev/null ||
	# 	update_cp edit/usr/lib/ISOLINUX/isolinux.bin extracted/isolinux/isolinux.bin 2>/dev/null ||
	# 	update_cp edit/usr/lib/isolinux/isolinux.bin extracted/isolinux/isolinux.bin 2>/dev/null
	# fi
}

kernel_select_arch(){
    local x=1
    local val=
    while [ $x -eq 1 ];do
        val=$(get_prop_input "$JL_krpn" "$liveconfigfile" "Enter kernel (n to skip)")
        if [ "$val" = n ]; then
            x=2
        elif [ -f edit/boot/vmlinuz-"$val" ]; then
            x=2
        else
            err_out "No such kernel: $val. There must be a vmlinuz-$val file in edit/boot/"
        fi
    done
    echo "$val" >/dev/stdout
}

mk_new_efi(){
    msg_out "Creating new efi boot image ..."
    bs='1M'
    olds=$(du_size_ex_initramfs "mnt" $bs)
    msg_out "Old size excluding initramfs: ${olds}x$bs"
    vms=$(du_size "extracted/arch/boot/$JL_arch/vmlinuz" $bs)
    rds=$(du_size "extracted/arch/boot/x86_64/archiso.img" $bs)
    news=$((olds + vms + rds))
    msg_out "New size including initramfs: ${news}x$bs"
    dd if=/dev/zero bs=$bs count=$news of=efiboot-new.img
    mkfs.fat -n "ARCHISO_EFI" efiboot-new.img
    umount new 2>/dev/null || umount -lf new 2>/dev/null || rm -r new 2>/dev/null
    mkdir new
    mount -t vfat -o loop efiboot-new.img new && msg_out "mounted new efi"
    cp -r mnt/* new/
    #rm new/EFI/archiso/vmlinuz.efi new/EFI/archiso/archiso.img
    update_cp extracted/arch/boot/$JL_arch/vmlinuz new/EFI/archiso/vmlinuz.efi &&
    update_cp extracted/arch/boot/x86_64/archiso.img new/EFI/archiso/archiso.img &&
    msg_out "Successfully created new efi image" || {
    umount new || umount -lf new
    rm -r new
    umount mnt || umount -lf mnt
    err_out "Created a broken efi image"
    return 1
    }
    umount new || umount -lf new
    rm -r new
    update_mv efiboot-new.img extracted/EFI/archiso/efiboot.img
}

rebuild_initramfs(){
    KERNEL=$(kernel_select_arch)
    if [ "$KERNEL" = '' -o "$KERNEL" = n ]; then
        wrn_out "Skipping this step..."
        return 1
    fi
    update_prop_val "$JL_krpn" "$KERNEL" "$liveconfigfile" "Kernel version"
    $CHROOT pacman -S archiso --noconfirm --needed
    HOOKS='"base udev memdisk archiso_shutdown archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_kms block pcmcia filesystems keyboard"'
    sed -i.bak "s/HOOKS=\"[^\"]*\"/HOOKS=$HOOKS/" edit/etc/mkinitcpio.conf
    msg_out "Rebuilding initramfs for kernel: $KERNEL"
    $CHROOT mkinitcpio -p $KERNEL -k $KERNEL
    update_cp "edit/boot/vmlinuz-$KERNEL" "extracted/arch/boot/$JL_arch/vmlinuz"
    update_cp "edit/boot/initramfs-$KERNEL.img" "extracted/arch/boot/$JL_arch/archiso.img"
    #update efi 
    mount -t vfat -o loop extracted/EFI/archiso/efiboot.img mnt
    update_cp "extracted/arch/boot/$JL_arch/vmlinuz" mnt/EFI/archiso/vmlinuz.efi &&
    update_cp "extracted/arch/boot/x86_64/archiso.img" mnt/EFI/archiso/archiso.img ||
    mk_new_efi
    umount mnt || umount -lf mnt
}

jl_clean(){
	kerver=$(uname -r)
	cd "$livedir" #exported from jlcd_start
	rm -f edit/run/synaptic.socket
	$CHROOT aptitude clean 2>/dev/null
	#$CHROOT dpkg-divert --rename --remove /sbin/initctl 2>/dev/null |sed 's/^/\n*** /' #ubuntu 9.10 only
	if [ -d edit/mydir ]; then
		mv -f edit/mydir ./
	fi
	rm -rf edit/tmp/*
	#rm edit/root/.bash_history # it is convenient to not delete it by default. You should clean up in final build manually.
	#rm edit/var/lib/dbus/machine-id #ubuntu 9.10 only
	#rm edit/sbin/initctl #ubuntu 9.10 only
}

jl_clean_arch(){
	kerver=$(uname -r)
	cd "$livedir" #exported from jlcd_start
	if [ -d edit/mydir ]; then
		mv -f edit/mydir ./
	fi
	rm -rf edit/tmp/*
	$CHROOT $SHELL -c "LANG=C pacman -Sl | awk '/\[installed\]$/ {print \$1 \"/\" \$2 \"-\" \$3}' > /pkglist.txt"
	mv edit/pkglist.txt extracted/arch/pkglist.$JL_arch.txt
}

show_osmode(){
    if $JL_archlinux; then
        msg_out "Running in Arch Linux mode"
	elif $JL_debian; then
		msg_out "Running in Debian mode"
	else
		msg_out "Running in Ubuntu mode"
	fi
}

update_vars_according_to_osmode(){
    if [ "$1" = archlinux ]; then
        JL_archlinux=true
        JL_squashfs="arch/$JL_arch/airootfs.sfs"
    elif [ "$1" = debian ]; then
        JL_debian=true;
        JL_casper=live
        JL_squashfs="$JL_casper"/filesystem.squashfs
        JL_resolvconf=var/run/NetworkManager/resolv.conf #must not start with /
    else
        JL_ubuntu=true
    fi
}

jlcd_start(){
    export livedir=
    export liveconfigfile=
    export edit=
	JL_terminal1=$TERMINAL1
	JL_terminal2=$TERMINAL2
	command -v "$JL_terminal1" >/dev/null 2>&1 || JL_terminal1='x-terminal-emulator'
	command -v "$JL_terminal2" >/dev/null 2>&1 || JL_terminal2='xterm'

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
        IMAGENAME="$(get_iso_label "$isopath")"
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
        if [ "$live_os" = '' ]; then
            osmode=$(mode_select)
        else
            osmode="$live_os"
        fi
        if [ "$osmode" = archlinux ]; then
            JL_archlinux=true
            JL_squashfs="arch/$JL_arch/airootfs.sfs"
        elif [ "$osmode" = debian ]; then
            JL_debian=true;
            JL_casper=live
            JL_squashfs="$JL_casper"/filesystem.squashfs
            JL_resolvconf=var/run/NetworkManager/resolv.conf #must not start with /
        else
            JL_ubuntu=true
        fi
		mount -o loop "$isopath" mnt || wrn_out "failed to mount iso."
        rsync --exclude=/"$JL_squashfs" -a mnt/ extracted || { umount mnt || umount -lf mnt; err_exit "rsync failed"; }
        unsquashfs -f mnt/"$JL_squashfs" || { umount mnt || umount -lf mnt; err_exit "unsquashfs failed"; }
		mv -fT squashfs-root edit || { umount mnt || umount -lf mnt; err_exit "couldn't move squashfs-root."; }
		edit=$(abs_path edit)/ #must end with a slash
		umount mnt || umount -lf mnt
        prepare_args="$prepare_args --new"
	fi
	cd "$maindir"
	c=1
	while [ $c -eq 1 ]
	do
		if [ "$yn" != "y" ]; then
			msg_out "If you just hit enter it will take your previous choice (if any)"
            if [ -f "$JLIVEdirF" ]; then
                livedirp="$(cat "$JLIVEdirF")"
            fi
            msg_out "previous project path: $livedirp"
			livedir="$(get_input "Enter the directory path where you have saved your project: ")"
			livedir="$(expand_path "$livedir")"
			if [ "$livedir" = "" ]; then
                livedir="$livedirp"
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
	set -a
	if [ -f "$livedir/$JL_sconf"  ]; then
		. "$livedir/$JL_sconf"
	fi
	set +a
    
    # validate mode
    if [ "$yn" != y ]; then
        osmode="$(get_prop_val "$JL_mdpn" "$liveconfigfile" )"
    fi
    if [ "$osmode" != '' ]; then
        if [ "$live_os" != '' ] && [ "$live_os" != "$osmode" ]; then
            err_exit "OSMODE=$osmode in $liveconfigfile file doesn't match with OSMODE passed as argument ($live_os)"
        fi
    elif [ "$live_os" != '' ]; then
        osmode="$live_os"
    else
        osmode=$(mode_select)
    fi
    
    update_prop_val "$JL_mdpn" "$osmode" "$liveconfigfile" "operating mode (override not possible)"
    if [ "$osmode" = archlinux ]; then
        JL_archlinux=true
        JL_squashfs="arch/$JL_arch/airootfs.sfs"
    elif [ "$osmode" = debian ]; then
        JL_debian=true;
        JL_casper=live
        JL_squashfs="$JL_casper"/filesystem.squashfs
        JL_resolvconf=var/run/NetworkManager/resolv.conf #must not start with /
    else
        JL_ubuntu=true
    fi
    show_osmode
    
    if [ "$IMAGENAME" = '' ]; then
        IMAGENAME="$(get_prop_val $JL_inpn "$liveconfigfile")"
    fi
    update_prop_val "$JL_inpn" "$IMAGENAME" "$liveconfigfile" "Image label (no override for archlinux)"

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

	cdname="$(get_prop_input "$JL_dnpn" "$liveconfigfile" "Enter your desired (customized) cd/dvd name")"
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
	cp preparechroot "$livedir"/edit/prepare
	cp help "$livedir"/edit/help
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

    check_space_changed=false
    if ! $JL_archlinux; then
        msg_out "installing updarp in chroot ..."
        cp "$JLdir"/updarp edit/usr/bin/updarp
    else
        if grep -q '^[[:blank:]]*CheckSpace' edit/etc/pacman.conf; then
            sed -i.bak 's/^[[:blank:]]*CheckSpace/#&/' edit/etc/pacman.conf
            check_space_changed=true
        fi
    fi

	mount_fs
	msg_out "Running chroot terminal... \nWhen you are finished, run: exit or simply close the chroot terminal. run 'cat help' or './help' to get help in chroot terminal."
	if ! $JL_terminal1 -e "$SHELL -c '$CHROOT /prepare $prepare_args;HOME=/root LC_ALL=C $CHROOT;exec $SHELL'" 2>/dev/null; then
		wrn_out "couldn't run $JL_terminal1, trying $JL_terminal2..."
		if ! $JL_terminal2 -e "$SHELL -c '$CHROOT /prepare $prepare_args;HOME=/root LC_ALL=C $CHROOT;exec $SHELL'" 2>/dev/null; then
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
	##############################Checking for new installed kernel############################################################
	msg_out "\n*** You have $timeout seconds each to answer the following questions.\n*** If not answered, I will take 'n' as default (be ready).\n*** Some default may be different due to previous choice.\n***\n"
	kerver=0
	d=2
	ker=""
	msg_out "##### Init script & Kernel related #####\nRebuild the initramfs if you have \n1. changed init scripts or kernel modules\n2. installed new kernel and want to boot that kernel in the live session."
	ker="$(get_prop_yn "$JL_ripn" "$liveconfigfile" "Rebuild initramfs" $timeout)"
    update_prop_val "$JL_ripn" "$ker" "$liveconfigfile" "Whether to rebuild initrd"
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
        #dkerver="$(get_prop_val $JL_krpn "$liveconfigfile")"
        #if [ "$dkerver" = '' ]; then dkerver=$(uname -r); fi
        kerver="$(get_prop_input $JL_krpn "$liveconfigfile" "Enter the kernel version (take your time on this one) (n to skip)")"
        if [ "$kerver" = "n" ] || [ "$kerver" = "N" ]; then
            break
        elif [ "$kerver" = "" ]; then
            kerver="$(uname -r)"
        fi
        vmlinuz_path=edit/boot/vmlinuz-"$kerver"
        if [ -d "edit/lib/modules/$kerver" ]; then
            rebuild_initrd "$initrd" "$kerver"
            d=2
            update_prop_val "$JL_krpn" "$kerver" "$liveconfigfile" "Kernel version"
        else
            err_out "no such kernel version: $kerver"
        fi
    done
    ############################### Cleaning home ###############################################################
	homec=$(get_prop_yn "$JL_rhpn" "$liveconfigfile" "Retain home directory" "$timeout")
	if [  "$homec" = Y ] || [ "$homec" = y ]; then
	  	msg_out "edit/home kept as it is"
	else
	  	rm -rf edit/home/*
	  	msg_out "edit/home cleaned!"
	fi
	update_prop_val "$JL_rhpn" "$homec"  "$liveconfigfile" "Whether to keep users home directory, by default it is deleted."
    ################################# Changing back some configs #################################################
    if ! $JL_archlinux; then
        msg_out "removing updarp ..."
        rm edit/usr/bin/updarp
    elif $check_space_changed; then
        sed -i.bak 's/^##*[[:blank:]]*\(CheckSpace\)/\1/' edit/etc/pacman.conf
    fi
	msg_out 'Restoring access control state'
	xhost $bxhost | sed 's/^/\n*** /' && msg_out "xhost restored to initial state."  #leave this variable unquoted
	##################################Cache management############################################################
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
    ############################# Prepare to create CD/DVD####################################################################
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
	  mksquashfs edit extracted/"$JL_squashfs" -b 1048576 -e edit/boot || err_exit "mksquashfs failed!"
	else
	  msg_out "Using exhaustive compression. Size may become lesser"
	  #mksquashfs edit extracted/"$JL_squashfs" -comp xz || err_exit "mksquashfs failed!"
	  mksquashfs edit extracted/"$JL_squashfs" -comp xz -e edit/boot || err_exit "mksquashfs failed!"
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
        if ! $JL_archlinux; then
            efi_img=boot/grub/efi.img
        else
            efi_img=EFI/archiso/efiboot.img
        fi
		genisoimage -U -A "$IMAGENAME" -V "$IMAGENAME" -volset "$IMAGENAME" -J -joliet-long -D -r -v -T -o ../"$cdname".iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e "$efi_img" -no-emul-boot . && msg_out 'Prepared UEFI image'
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
