JLIVECD
======
*************************************************************************************************************************
                                          Live cd/dvd customization tool
*************************************************************************************************************************
 
*************************************************************************************************************************
Disclaimer
-----------

Customized ISOs for personal use are fine. If you want to share your customization with others, whether for free or for purchase, you'll have to rename it; remove all distro specific artwork, branding, and other identity elements; and you can't confuse your intended users about the customization being associated in any way with the base distro.

You're free to use the softwares without renaming those, as they are licensed under GPL. But otherwise, it will be your own creation and no longer you base distros'.

The name and identity elements of a distro are trademarked and copyrighted. Unless you have approval from appropriate authorization you can't use those (identity elements and name).
*************************************************************************************************************************

What this is about:
-------------------
This is a simple command line tool to customize live cd/dvd of ubuntu based distros, Linux Mint and some of their derivatives. It is developed with the help of the documentation found on:
https://help.ubuntu.com/community/LiveCDCustomization and intended primarily for personal use. This is released under GPL v2 lincense and redistrubtion is free and open complying to the licensing terms of GPL v2 license.


Requirements:
------------

1.squashfs-tools

2.genisoimage

install requirements by:

sudo apt-get install squashfs-tools genisoimage

Installation:
------------

give the install.sh file execution permission and run it in terminal

How to use:
----------

Run JLstart in a terminal or run it from menu->system->JLIVECD

N.B: This does no modification on it's own. you need to modify the iso images on your own. It only renders an environment for modification and finally creates the modified iso image. And of course, you need an iso image as base as no other image or archive will work with this tool.

Example:

~$ JLstart

Is this a fresh start: (y/n)?n

[sudo] password for user:

...............................


Hints are given on the go, follow them to successfully create a customized live cd/dvd

Tested OS:
---------

*Linux Mint 17 cinnamon

*Linux Mint 17 XFCE

*Xubuntu 14.04.1 LTS


Additonal info:
--------------

1.In Linux Mint 17 XFCE there's a bug. To fix this edit /usr/sbin/invoke-rc.d file (in chroot) as:
replace exit 100 with exit 0 at line 285 and 421, then apply upgrade. after upgrading revert this modification (must).

2.In Linux Mint 17 xfce, if you install nautilus then it will set gnome-session as default session and if gnome desktop is not installed then no desktop window will show up in live session. change the link /usr/bin/x-session-manager to point to /usr/bin/xfce4-session

3.In xubuntu 14.04.1 there's another bug: Can't open /scripts/casper-functions" error) to fix this, run this code in chroot:

ln -s /usr/share/initramfs-tools/scripts /scripts

Follow the following link for bug report:

https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1325142

4.If you are not able to get connected to internet in chroot then you can try running the code: JLRefreshNetwork in another terminal in your main system. This may happen, if you have started JLIVECD before connecting your pc to the internet.

5.If you want to change the timeout value then run this code in another terminal in your main system:

sudo echo timeout_value > /usr/local/JLIVECD/main/timeout

"timeout_value" should be replaced with your desired time in seconds (ex: 12)

Special Feature:
----------------
I call it debcache management! 


1.Just put your .deb files in edit/var/cache/apt/archives folder and they won't be downloaded again in the software installaion process.

2.They will be moved automatically to a folder named debcache (located in the same directory as "edit") prior to image creation so that they won't be included in the iso image.

3.You never need to delete .deb files from edit/var/cache/apt/archives manually and you shouldn't.

4.If you don't delete the .deb files then you will never need to download them again as long as they remain the updated files according to your package list (which you get from apt-get update). debcache management will take proper measures to move the files to required places to minimize downloads of packages from internet.

5.Altenatively, you can put the .deb files in "debcache" folder too, but in that case you need to run the application after you have finished copying files to this folder...


Source Link:
-----------
https://github.com/mdjahidulhamid/JLIVECD

Web page:
---------
http://mdjahidulhamid.github.io/JLIVECD/

Facebook Page:
--------------
https://www.facebook.com/pages/JCode/1513497505602572
