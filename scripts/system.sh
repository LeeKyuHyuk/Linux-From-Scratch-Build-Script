#!/bin/bash
sudo umount $ROOTFS_DIR/dev/pts $ROOTFS_DIR/{dev,proc,sys,run}
sudo rm -rf $ROOTFS_DIR/{bin,build,dev,home,lib64,mnt,packages,root,sbin,sys,var,boot,build.sh,etc,lib,media,opt,proc,run,srv,tmp,usr}
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
mkdir -pv $ROOTFS_DIR/packages $ROOTFS_DIR/build
cp -rv $PACKAGES_DIR/* $ROOTFS_DIR/packages
cp -rv $PATCHES_DIR/* $ROOTFS_DIR/packages
cp -v $SCRIPTS_DIR/build.sh $ROOTFS_DIR/build.sh
chmod +x $ROOTFS_DIR/build.sh
sudo chroot "$ROOTFS_DIR" /tools/bin/env -i \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin:/tools/usr/sbin \
    /build.sh --login +h
sudo umount $ROOTFS_DIR/dev/pts $ROOTFS_DIR/{dev,proc,sys,run}
sudo -k
