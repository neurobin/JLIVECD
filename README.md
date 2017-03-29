# Disclaimer

Customized ISOs for personal use are fine. If you want to share your customization with others, whether for free or for purchase, you'll have to rename it; remove all distro specific artwork, branding, and other identity elements; and you can't confuse your intended users about the customization being associated in any way with the base distro.

You're free to use the softwares without renaming those, as they are licensed under GPL. But otherwise, it will be your own creation and no longer you base distros'.

The name and identity elements of a distro are trademarked and copyrighted. Unless you have approval from appropriate authorization you can't use those (identity elements and name).

# Description:

This is a simple command line tool to customize live cd/dvd of Debian, Ubuntu family, Linux Mint and some of their derivatives. It is developed with the help of the documentation found on: 

1. https://help.ubuntu.com/community/LiveCDCustomization
2. https://wiki.debian.org/DebianInstaller/Modify/CD

This tool is intended primarily for personal use.

It gives you a chroot environment for modification and creates the modified iso image. You need to do all the customizations on your own, JLIVECD itself does not do any modifications.

<mark>Please read through the <a href="#additional-info">Additional info</a> section before you start with a Ubuntu or Linux Mint ISO for the first time.</mark>

# Features:

1. You can save your project in a suitable directory and keep adding and changing things while checking the ISOs' built on those changes.
2. Your changes are always saved. You can resume it whenever you like.
3. It remembers your previous choice (the project directory, the desired ISO name and the original ISO path). Just hit <kbd>Enter</kbd> when you are prompt for input in such cases.
4. You only need to give it the original ISO once, every time after that, you can just go to the chroot terminal and keep customizing things.
5. It remembers user choices for various options and prompts both globally and locally (project wise).


# Requirements:

1. bash (This is generally installed by default in most Linux distros)
2. squashfs-tools
3. genisoimage
4. syslinux, syslinux-utils (If you want hybrid ISO image (default))
5. rsync
6. xterm (optional)

Install requirements with the following command:

```sh
sudo apt-get install squashfs-tools genisoimage syslinux syslinux-utils rsync
```

Optionally you can keep `xterm` installed. It will work as a backup terminal in case the default terminal fails to run.

```sh
sudo apt-get install xterm
```

# Installation:

run the `install.sh` file in terminal:

```sh
sudo bash ./install.sh
```

# How to use:

## For Ubuntu family & Linux Mint

Run `JLstart -ub` in a terminal or run it from `menu->Development->JLIVECD`.

<img alt="JLIVECD menu image" src="img/runjlivecd.png"></img>

Example:

```bash
~$ JLstart -ub

=== Is this a new project: (y/n)?: n

[sudo] password for user:

...............................
```

Hints are given on the go, follow them to create a customized live cd/dvd.

## For Debian

Run `JLstart -db` in a terminal or run it from `menu->Development->JLIVECD` and follow through.

```bash
~$ JLstart -db

=== Is this a new project: (y/n)?: n

[sudo] password for user:

...............................
```

# Directories & Files:

In your project directory, you will find some default files/directories. Don't change their names.

**The directories are:**

* `debcache`: `.deb` files are kept here. See the special feature section for more details.
* `edit`: This is the root filesystem (i.e `/`) for the live system (chroot system). Any change you make here will appear in the finalized ISO.
* `extracted`: This is where the original ISO is extracted. You can change several things here, like Diskname, release, date, splash screen, etc.
* `mnt`: A directory used only for mounting ISO image.
* `mydir`: A directory with 777 permission. This directory is moved inside `edit/` during chroot, thus in chroot it will be available as `/mydir`. Use this directory to store/install source packages and files that you need to store for future but do not want to include them in the ISO.

**The files are:**

* `.config`: configuration of the corresponding project i.e `DISKNAME` and some other defaults.
* `config.conf`: Final configuration managed by user. This is essentially a bash script and thus you can make intelligent use of it and set dynamic options. Any non-empty value set to a variable (option) will bypass its input prompt.


# Things to care:

1. **Quotation in prompts are taken as literal.** `~/"some folder"` and `"~/some folder"` are different. If you want spaces then give it as it is: `~/some folder`.
2. **Do not use NTFS partition.**
3. The default is `no` for all `yes/no` type prompts unless specified otherwise.

# Some Tips & Tricks:

1. If you are not being able to get connected to internet in chroot, you can try running the code: `JLopt -rn` in another terminal in your main system. This may happen if you start JLIVECD before connecting your pc to the internet.
2. If you want to change the timeout value then run this code in a terminal in your main system: `JLopt -t timeout_value`. "timeout_value" should be replaced with your desired time in seconds. Ex: for 12 seconds timeout: `JLopt -t 12`
3. JLIVECD seems to have problem running the `mate-terminal` properly. For mate DE, install `xterm` instead ( `sudo apt-get install xterm`).
4. You can change the default terminal JLIVECD uses for chroot. To change the primary default terminal run this code in a terminal in your main system: `JLopt -t1 actual-terminal-command`. To change the secondary default terminal: `JLopt -t2 actual-terminal-command`. For Ex. `JLopt -t1 gnome-terminal`
5. You don't need to give the full name/path to the base iso prompt: `enter base iso path: ~/Downloads/x`. As there is only one file that matches 'x in my Downloads folder is xubuntu-14.04.1-x64.iso, it will take that file as the input.
6. You can use full path with or without `.iso`.

# Special Feature:

I call it debcache management!

1. Put your `.deb` files in *edit/var/cache/apt/archives* folder and they won't be downloaded again in the software installation process.
2. They will be moved automatically to a folder named debcache (located in the same directory as "edit") prior to image creation so that they won't be included in the iso image.
3. You never need to delete .deb files from *edit/var/cache/apt/archives* manually and you shouldn't.
4. If you don't delete the .deb files then you will never need to download them again as long as they remain the updated files according to your package list (which you get from `apt-get update`). debcache management will take proper measures to move the files to required places to minimize downloads of packages from Internet.
5. Alternatively, you can put the `.deb` files in **debcache** folder too, but in that case you need to run the application after you have finished copying files to this folder...

# New features:

* You can close the host and chroot terminal safely at any stage. Simultaneous closing is also OK.
* Possibility to use schroot (only for advanced users).

# Creating bootable USB

By default JLIVECD creates hybrid image. You can either use tools like `unetbootin` or something like `dd` to create the bootable USB. If you want to use `dd`, be careful about mistyping and what you are doing. For example, you could end up wiping your hard disk if you mistype `/dev/sdb` as `/dev/sda`. For this, I have another script ([chibu](https://github.com/neurobin/chibu)) that checks the validity of the usb device and makes sure it's a USB device not something else like a partition on your hard drive. After cheking validity it runs a `dd` command to create the bootable USB.

**Note:** chibu or dd will destory existing data on the USB

With chibu, it's like this:

```bash
sudo chibu iso_path /dev/sdx
```
where `/dev/sdx` (not `/dev/sdx1` etc..) is your usb device, (x is a letter)

You can find the device id with:

```bash
sudo fdisk -l
```
look for the usb device in the output of the above command.

**Notes:**

* USB created with `unetbootin` may not have its boot flag set. Check with `gparted` and set the boot flag if not set.
* USB created with `unetbootin` may fail to boot with its first default boot option, choose `failsafe` option.
* If unetbootin doesn't work, try `dd` (preferably [chibu](https://github.com/neurobin/chibu))

# Tested OS:

* Xubuntu 16.04 LTS
* Linux Mint 17 cinnamon
* Linux Mint 17 XFCE
* Xubuntu 14.04.1 LTS
* Ubuntu 14.04.1 LTS
* Ubuntu 14.04.3 LTS
* Debian (xfce) 8.7.1 Jessie
* Debian (xfce) testing (stretch) @ Thu Mar 23 13:31:53 UTC 2017

<div id="additional-info"></div>

# Additonal info:

1.In Linux Mint 17 XFCE there's a bug. To fix this edit `/usr/sbin/invoke-rc.d` file (in chroot) as:
replace `exit 100` with `exit 0` at line `285` and `421`, then apply upgrade. after upgrading revert this modification (must).

2.In Linux Mint 17 xfce, if you install nautilus then it will set gnome-session as default session and if gnome desktop is not installed then no desktop window will show up in live session. change the link `/usr/bin/x-session-manager` to point to `/usr/bin/xfce4-session`.

3.In xubuntu 14.04.1 there's another bug: Can't open /scripts/casper-functions" error) to fix this, run this code in chroot:

```sh
ln -s /usr/share/initramfs-tools/scripts /scripts
```

Follow the following link for bug report:

https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1325142

4.In Ubuntu 14.04 Gnome LTS you might encounter two more bugs:

One should be solved by editing:

```sh
/var/lib/dpkg/info/whoopsie.prerm
/var/lib/dpkg/info/libpam-systemd\:amd64.prerm
/var/lib/dpkg/info/libpam-systemd\:amd64.postinst
```

(change `exit $?` to `exit 0` in the invoke-rc.d lines)

Other one should be solved by editing:

```sh
/etc/kernel/postrm.d/zz-update-grub
/etc/kernel/postinst.d/zz-update-grub
```

find the following and comment out the if and fi line:

```sh
if [ -e /boot/grub/grub.cfg ]; then
   #exec update-grub
fi
```

Revert these changes before exiting the chroot.

Follow the following link for bug report for more details:

https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1325142

5.You may encounter another bug: `Ubiquity installer, hang/freeze on harddisk detection`. This bug can be solved by editing the file `edit/usr/share/applications/ubiquity-gtkui.desktop` and changing the section `exex` from

```sh
sh -c 'ubiquity gtk_ui'
```

to

```sh
sh -c 'sudo ubiquity gtk_ui'
```
