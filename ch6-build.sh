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
export LFS_DIR=$(cd "$(dirname "$0")" && pwd)
export SOURCES_DIR=$LFS_DIR/sources
export ROOTFS_DIR=$LFS_DIR/rootfs
export BUILD_DIR=$ROOTFS_DIR/build
export TOOLS_DIR=$ROOTFS_DIR/tools

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

sudo umount -f $ROOTFS_DIR/dev/pts $ROOTFS_DIR/dev $ROOTFS_DIR/proc $ROOTFS_DIR/sys $ROOTFS_DIR/run || /bin/true
sudo rm -rf $ROOTFS_DIR
mkdir -v $ROOTFS_DIR
extract $LFS_DIR/x86_64-lfs-linux-toolchain-2019-04.tar.xz $ROOTFS_DIR
cp -v $LFS_DIR/ch6-chroot-build.sh $ROOTFS_DIR
cp -Rv $SOURCES_DIR $ROOTFS_DIR/sources

sudo rm -rf $ROOTFS_DIR/{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var}

step "# 6.2. Preparing Virtual Kernel File Systems"
mkdir -pv $ROOTFS_DIR/{dev,proc,sys,run}
sudo mknod -m 600 $ROOTFS_DIR/dev/console c 5 1
sudo mknod -m 666 $ROOTFS_DIR/dev/null c 1 3
sudo mount -v --bind /dev $ROOTFS_DIR/dev
sudo mount -vt devpts devpts $ROOTFS_DIR/dev/pts -o gid=5,mode=620
sudo mount -vt proc proc $ROOTFS_DIR/proc
sudo mount -vt sysfs sysfs $ROOTFS_DIR/sys
sudo mount -vt tmpfs tmpfs $ROOTFS_DIR/run
if [ -h $ROOTFS_DIR/dev/shm ]; then
  mkdir -pv $ROOTFS_DIR/$(readlink $ROOTFS_DIR/dev/shm)
fi

step "# 6.4. Entering the Chroot Environment"
sudo chroot "$ROOTFS_DIR" \
/tools/bin/env -i \
HOME=/root \
TERM="$TERM" \
PS1='[Linux From Scratch Build] $ ' \
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
/ch6-chroot-build.sh --login +h

step "# 6.79. Cleaning Up"
rm -rf $ROOTFS_DIR/tmp/* $ROOTFS_DIR/build $ROOTFS_DIR/tools

echo -e "----------------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 6!"
printf 'Total script time: %s\n' $(timer $total_time)
