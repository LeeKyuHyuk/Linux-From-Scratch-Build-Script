#!/bin/bash
#
# Linux From Scratch Build Script 20190327-systemd v1.0
#
# Optional parameteres below:

# Number of parallel make jobs.
PARALLEL_JOBS=$(cat /proc/cpuinfo | grep cores | wc -l)
# Strip binaries and delete manpages to save space at the end of chapter 5?
STRIP_AND_DELETE_DOCS=1

# End of optional parameters
umask 022
set +h
set -o nounset
set -o errexit
export LC_ALL=POSIX
export PATH=/tools/bin:/bin:/usr/bin
export LFS_TGT=$(uname -m)-lfs-linux-gnu

function step() {
  echo -e "\e[7m\e[1m>>> $1\e[0m"
}

function success() {
  echo -e "\e[1m\e[32m$1\e[0m"
}

function error() {
  echo -e "\e[1m\e[31m$1\e[0m"
}

function extract() {
  case $1 in
    *.tgz) tar -zxf $1 -C $2 ;;
    *.tar.gz) tar -zxf $1 -C $2 ;;
    *.tar.bz2) tar -jxf $1 -C $2 ;;
    *.tar.xz) tar -Jxf $1 -C $2 ;;
  esac
}

function prebuild_sanity_check {
    if ! [[ -d $SOURCES_DIR ]] ; then
        echo "Can't find your sources directory!"
        exit 1
    fi
}

function check_tarballs {
LIST_OF_TARBALLS="
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f $SOURCES_DIR/$tarball ]] ; then
        echo "Can't find $tarball!"
        exit 1
    fi
done
}

function do_strip {
    set +o errexit
    if [[ $STRIP_AND_DELETE_DOCS = 1 ]] ; then
        strip --strip-debug /tools/lib/*
        /usr/bin/strip --strip-unneeded /tools/{,s}bin/*
        rm -rf /tools/{,share}/{info,man,doc}
        find /tools/{lib,libexec} -name \*.la -delete
    fi
}

function timer {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local stime=$1
        etime=$(date '+%s')
        if [[ -z "$stime" ]]; then stime=$etime; fi
        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%02d:%02d:%02d' $dh $dm $ds
    fi
}

prebuild_sanity_check
check_tarballs

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

total_time=$(timer)

# sudo umount -f $ROOTFS_DIR/dev/pts $ROOTFS_DIR/dev $ROOTFS_DIR/proc $ROOTFS_DIR/sys $ROOTFS_DIR/run || /bin/true
# sudo rm -rf $ROOTFS_DIR
# mkdir -v $ROOTFS_DIR
#
# step "Decompress Toolchain"
# extract $PREBUILT_DIR/x86_64-lfs-linux-toolchain.tar.xz $ROOTFS_DIR
# cp -v $SCRIPTS_DIR/build.sh $ROOTFS_DIR
# cp -Rv $SOURCES_DIR $ROOTFS_DIR/sources
#
# step "# 6.2. Preparing Virtual Kernel File Systems"
# mkdir -pv $ROOTFS_DIR/{dev,proc,sys,run}
# sudo mknod -m 600 $ROOTFS_DIR/dev/console c 5 1
# sudo mknod -m 666 $ROOTFS_DIR/dev/null c 1 3
# sudo mount -v --bind /dev $ROOTFS_DIR/dev
# sudo mount -vt devpts devpts $ROOTFS_DIR/dev/pts -o gid=5,mode=620
# sudo mount -vt proc proc $ROOTFS_DIR/proc
# sudo mount -vt sysfs sysfs $ROOTFS_DIR/sys
# sudo mount -vt tmpfs tmpfs $ROOTFS_DIR/run
# if [ -h $ROOTFS_DIR/dev/shm ]; then
#   mkdir -pv $ROOTFS_DIR/$(readlink $ROOTFS_DIR/dev/shm)
# fi
#
# step "# 6.4. Entering the Chroot Environment"
# sudo chroot "$ROOTFS_DIR" \
# /tools/bin/env -i \
# HOME=/root \
# TERM="$TERM" \
# PS1='[Linux From Scratch Build] $ ' \
# PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
# /build.sh --login +h

step "# 6.79. Cleaning Up"
sudo umount -f $ROOTFS_DIR/dev/pts $ROOTFS_DIR/dev $ROOTFS_DIR/proc $ROOTFS_DIR/sys $ROOTFS_DIR/run || /bin/true
rm -rf $ROOTFS_DIR/tmp/* $ROOTFS_DIR/build $ROOTFS_DIR/tools $ROOTFS_DIR/build.sh
sudo chown -R `whoami`:`whoami` $ROOTFS_DIR

step "7.2. General Network Configuration"
ln -sfv /dev/null $ROOTFS_DIR/etc/systemd/network/99-default.link
ln -sfv /run/systemd/resolve/resolv.conf $ROOTFS_DIR/etc/resolv.conf
echo "<lfs>" > $ROOTFS_DIR/etc/hostname
cat > $ROOTFS_DIR/etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF

step "7.5. Configuring the system clock"
cat > $ROOTFS_DIR/etc/adjtime << "EOF"
0.0 0 0.0
0
LOCAL
EOF

step "7.8. Creating the /etc/inputrc File"
cat > $ROOTFS_DIR/etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

step "7.9. Creating the /etc/shells File"
cat > $ROOTFS_DIR/etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

step "7.10. Systemd Usage and Configuration"
mkdir -pv $ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d

cat > $ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d/noclear.conf << EOF
[Service]
TTYVTDisallocate=no
EOF

step "8.2. Creating the /etc/fstab File"
cat > $ROOTFS_DIR/etc/fstab << "EOF"
# Begin /etc/fstab
# <file system>	<mount pt>	<type>	<options>	<dump>	<pass>
/dev/root	/		ext2	rw,noauto	0	1
proc		/proc		proc	defaults	0	0
devpts		/dev/pts	devpts	defaults,gid=5,mode=620,ptmxmode=0666	0	0
tmpfs		/dev/shm	tmpfs	mode=0777	0	0
tmpfs		/tmp		tmpfs	mode=1777	0	0
tmpfs		/run		tmpfs	mode=0755,nosuid,nodev	0	0
sysfs		/sys		sysfs	defaults	0	0
# End /etc/fstab
EOF

echo -e "----------------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 6!"
printf 'Total script time: %s\n' $(timer $total_time)
