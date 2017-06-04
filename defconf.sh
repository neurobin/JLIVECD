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
 JL_debian=false
 JL_archlinux=false
 JL_ubuntu=false
 JL_fresh=n
 JLIVEisopathF=$JLdir/JLIVEisopath
 JLIVEdirF=$JLdir/JLIVEdir
 JL_configfile="$JLdir/.config"
 JL_sconf="config.conf"
 JL_sconf_file_d="$JLdir/$JL_sconf"
 JL_terminal1=x-terminal-emulator
 JL_terminal2=xterm
 JL_lockF=/tmp/JL_lock
 JL_timeoutd=10
 JL_casper=casper
 JL_logdirtmp="/tmp/.neurobin/JLIVECD"
 #JL_ynF="$JL_logdirtmp/yn"
 JL_resolvconf=run/resolvconf/resolv.conf #must not start with /
 JL_rhpn=RETAINHOME
 JL_dnpn=DISKNAME
 JL_inpn=IMAGENAME
 JL_xhpn=XHOST
 JL_fcpn=FASTCOMPRESSION
 JL_ufpn=UEFI
 JL_hbpn=NOHYBRID
 JL_tmn=TIMEOUT
 JL_t1n=TERMINAL1
 JL_t2n=TERMINAL2
 JL_crtn=CHROOT
 JL_krpn=KERNEL
 JL_ripn=REBUILDINITRAMFS
 JL_mdpn=OSMODE
 CHROOT='chroot ./edit'
 JL_arch='x86_64'
 JL_squashfs="$JL_casper"/filesystem.squashfs
