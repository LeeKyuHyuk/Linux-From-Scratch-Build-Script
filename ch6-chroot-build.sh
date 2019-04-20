#!/tools/bin/bash
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
# export LFS_TGT=$(uname -m)-lfs-linux-gnu

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
    if ! [[ -d /sources ]] ; then
        echo "Can't find your sources directory!"
        exit 1
    fi
}

function check_tarballs {
LIST_OF_TARBALLS="
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f /sources/$tarball ]] ; then
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

total_time=$(timer)

rm -rf /build
mkdir -v /build

step "# 6.5. Creating Directories"
mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -v  /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -v  /usr/libexec
mkdir -pv /usr/{,local/}share/man/man{1..8}
case $(uname -m) in
 x86_64) mkdir -v /lib64 ;;
esac
mkdir -v /var/{log,mail,spool}
ln -sv /run /var/run
ln -sv /run/lock /var/lock
mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

step "# 6.6. Creating Essential Files and Symlinks"
ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} /bin
ln -sv /tools/bin/{env,install,perl,printf} /usr/bin
ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib
ln -sv /tools/lib/libstdc++.{a,so{,.6}} /usr/lib
install -vdm755 /usr/lib/pkgconfig
ln -sv bash /bin/sh
ln -sv /proc/self/mounts /etc/mtab
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
systemd-bus-proxy:x:72:72:systemd Bus Proxy:/:/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/bin/false
systemd-network:x:76:76:systemd Network Management:/:/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-bus-proxy:x:72:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

step "# 6.7. Linux-5.0.4 API Headers"
extract /sources/linux-5.0.4.tar.xz /build
make -j$PARALLEL_JOBS mrproper -C /build/linux-5.0.4
make -j$PARALLEL_JOBS INSTALL_HDR_PATH=/build/linux-5.0.4/dest headers_install -C /build/linux-5.0.4
find /build/linux-5.0.4/dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv /build/linux-5.0.4/dest/include/* /usr/include
rm -rf /build/linux-5.0.4

step "# 6.8. Man-pages-5.00"
extract /sources/man-pages-5.00.tar.xz /build
make -j$PARALLEL_JOBS install -C /build/man-pages-5.00
rm -rf /build/man-pages-5.00

step "# 6.9. Glibc-2.29"
extract /sources/glibc-2.29.tar.xz /build
patch -Np1 -i /sources/glibc-2.29-fhs-1.patch -d /build/glibc-2.29
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    ;;
esac
mkdir -v /build/glibc-2.29/build
( cd /build/glibc-2.29/build && \
CC="gcc -ffile-prefix-map=/tools=/usr" \
/build/glibc-2.29/configure \
--prefix=/usr \
--disable-werror \
--enable-kernel=3.2 \
--enable-stack-protector=strong \
--with-headers=/usr/include \
libc_cv_slibdir=/lib )
make -j$PARALLEL_JOBS -C /build/glibc-2.29/build
sed '/test-installation/s@$(PERL)@echo not running@' -i /build/glibc-2.29/Makefile
make -j$PARALLEL_JOBS install -C /build/glibc-2.29/build
cp -v /build/glibc-2.29/nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
install -v -Dm644 /build/glibc-2.29/nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
install -v -Dm644 /build/glibc-2.29/nscd/nscd.service /lib/systemd/system/nscd.service
make -j$PARALLEL_JOBS localedata/install-locales -C /build/glibc-2.29/build
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
mkdir -v /build/tzdata2019a
extract /sources/tzdata2019a.tar.gz /build/tzdata2019a
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in /build/tzdata2019a/etcetera /build/tzdata2019a/southamerica \
          /build/tzdata2019a/northamerica /build/tzdata2019a/europe \
          /build/tzdata2019a/africa /build/tzdata2019a/antarctica  \
          /build/tzdata2019a/asia /build/tzdata2019a/australasia \
          /build/tzdata2019a/backward /build/tzdata2019a/pacificnew \
          /build/tzdata2019a/systemv; do
    zic -L /dev/null -d $ZONEINFO ${tz}
    zic -L /dev/null -d $ZONEINFO/posix ${tz}
    zic -L /build/tzdata2019a/leapseconds -d $ZONEINFO/right ${tz}
done
cp -v /build/tzdata2019a/{zone.tab,zone1970.tab,iso3166.tab} $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
ln -sfv /usr/share/zoneinfo/Asia/Seoul /etc/localtime
rm -rf /build/tzdata2019a
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
rm -rf /build/glibc-2.29

step "# 6.10. Adjusting the Toolchain"
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
gcc -dumpspecs | sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs

step "# 6.11. Zlib-1.2.11"
extract /sources/zlib-1.2.11.tar.xz /build
( cd /build/zlib-1.2.11 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/zlib-1.2.11
make -j$PARALLEL_JOBS install -C /build/zlib-1.2.11
mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
rm -rf /build/zlib-1.2.11

step "# 6.12. File-5.36"
extract /sources/file-5.36.tar.gz /build
( cd /build/file-5.36 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/file-5.36
make -j$PARALLEL_JOBS install -C /build/file-5.36
rm -rf /build/file-5.36

step "# 6.13. Readline-8.0"
extract /sources/readline-8.0.tar.gz /build
sed -i '/MV.*old/d' /build/readline-8.0/Makefile.in
sed -i '/{OLDSUFF}/c:' /build/readline-8.0/support/shlib-install
( cd /build/readline-8.0 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/readline-8.0 )
make -j$PARALLEL_JOBS SHLIB_LIBS="-L/tools/lib -lncursesw" -C /build/readline-8.0
make -j$PARALLEL_JOBS SHLIB_LIBS="-L/tools/lib -lncursesw" install -C /build/readline-8.0
mv -v /usr/lib/lib{readline,history}.so.* /lib
chmod -v u+w /lib/lib{readline,history}.so.*
ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
rm -rf /build/readline-8.0

step "# 6.14. M4-1.4.18"
extract /sources/m4-1.4.18.tar.xz /build
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' /build/m4-1.4.18/lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> /build/m4-1.4.18/lib/stdio-impl.h
( cd /build/m4-1.4.18 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/m4-1.4.18
make -j$PARALLEL_JOBS install -C /build/m4-1.4.18
rm -rf /build/m4-1.4.18

step "# 6.15. Bc-1.07.1"
extract /sources/bc-1.07.1.tar.gz /build
cat > /build/bc-1.07.1/bc/fix-libmath_h << "EOF"
#! /bin/bash
sed -e '1   s/^/{"/' \
    -e     's/$/",/' \
    -e '2,$ s/^/"/'  \
    -e   '$ d'       \
    -i libmath.h

sed -e '$ s/$/0}/' \
    -i libmath.h
EOF
ln -sv /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
ln -sfv libncursesw.so.6 /usr/lib/libncurses.so
sed -i -e '/flex/s/as_fn_error/: ;; # &/' /build/bc-1.07.1/configure
( cd /build/bc-1.07.1 && \
./configure \
--prefix=/usr \
--with-readline \
--mandir=/usr/share/man \
--infodir=/usr/share/info )
make -j$PARALLEL_JOBS -C /build/bc-1.07.1
make -j$PARALLEL_JOBS install -C /build/bc-1.07.1
rm -rf /build/bc-1.07.1

step "# 6.16. Binutils-2.32"
extract /sources/binutils-2.32.tar.xz /build
mkdir -v /build/binutils-2.32/build
( cd /build/binutils-2.32/build && \
/build/binutils-2.32/configure \
--prefix=/usr \
--enable-gold \
--enable-ld=default \
--enable-plugins \
--enable-shared \
--disable-werror \
--enable-64-bit-bfd \
--with-system-zlib )
make -j$PARALLEL_JOBS  tooldir=/usr -C /build/binutils-2.32/build
make -j$PARALLEL_JOBS tooldir=/usr install -C /build/binutils-2.32/build
rm -rf /build/binutils-2.32

step "# 6.17. GMP-6.1.2"
extract /sources/gmp-6.1.2.tar.xz /build
( cd /build/gmp-6.1.2 && \
./configure \
--prefix=/usr \
--enable-cxx \
--disable-static \
--docdir=/usr/share/doc/gmp-6.1.2 )
make -j$PARALLEL_JOBS -C /build/gmp-6.1.2
make -j$PARALLEL_JOBS install -C /build/gmp-6.1.2
rm -rf /build/gmp-6.1.2

step "# 6.18. MPFR-4.0.2"
extract /sources/mpfr-4.0.2.tar.xz /build
( cd /build/mpfr-4.0.2 && \
./configure \
--prefix=/usr \
--disable-static \
--enable-thread-safe \
--docdir=/usr/share/doc/mpfr-4.0.2 )
make -j$PARALLEL_JOBS -C /build/mpfr-4.0.2
make -j$PARALLEL_JOBS install -C /build/mpfr-4.0.2
rm -rf /build/mpfr-4.0.2

step "# 6.19. MPC-1.1.0"
extract /sources/mpc-1.1.0.tar.gz /build
( cd /build/mpc-1.1.0 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/mpc-1.1.0 )
make -j$PARALLEL_JOBS -C /build/mpc-1.1.0
make -j$PARALLEL_JOBS install -C /build/mpc-1.1.0
rm -rf /build/mpc-1.1.0

step "# 6.20. Shadow-4.6"
extract /sources/shadow-4.6.tar.xz /build
sed -i 's/groups$(EXEEXT) //' /build/shadow-4.6/src/Makefile.in
( cd /build/shadow-4.6 && find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \; )
( cd /build/shadow-4.6 && find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \; )
( cd /build/shadow-4.6 && find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \; )
sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' /build/shadow-4.6/etc/login.defs
sed -i 's/1000/999/' /build/shadow-4.6/etc/useradd
( cd /build/shadow-4.6 && \
./configure \
--sysconfdir=/etc \
--with-group-name-max-length=32 )
make -j$PARALLEL_JOBS -C /build/shadow-4.6
make -j$PARALLEL_JOBS install -C /build/shadow-4.6
mv -v /usr/bin/passwd /bin
pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd
rm -rf /build/shadow-4.6

step "6.21. GCC-8.3.0"
extract /sources/gcc-8.3.0.tar.xz /build
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig /build/gcc-8.3.0/gcc/config/i386/t-linux64
  ;;
esac
rm -f /usr/lib/gcc
mkdir -v /build/gcc-8.3.0/build
( cd /build/gcc-8.3.0/build && \
SED=sed \
/build/gcc-8.3.0/configure \
--prefix=/usr \
--enable-languages=c,c++ \
--disable-multilib \
--disable-bootstrap \
--disable-libmpx \
--with-system-zlib )
make -j$PARALLEL_JOBS -C /build/gcc-8.3.0/build
make -j$PARALLEL_JOBS install -C /build/gcc-8.3.0/build
ln -sv ../usr/bin/cpp /lib
ln -sv gcc /usr/bin/cc
install -v -dm755 /usr/lib/bfd-plugins
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/8.3.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
rm -rf /build/gcc-8.3.0

step "# 6.22. Bzip2-1.0.6"
extract /sources/bzip2-1.0.6.tar.gz /build
patch -Np1 -i /sources/bzip2-1.0.6-install_docs-1.patch -d /build/bzip2-1.0.6
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' /build/bzip2-1.0.6/Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" /build/bzip2-1.0.6/Makefile
make -j$PARALLEL_JOBS -f Makefile-libbz2_so -C /build/bzip2-1.0.6
make -j$PARALLEL_JOBS clean -C /build/bzip2-1.0.6
make -j$PARALLEL_JOBS -C /build/bzip2-1.0.6
make -j$PARALLEL_JOBS PREFIX=/usr install -C /build/bzip2-1.0.6
cp -v /build/bzip2-1.0.6/bzip2-shared /bin/bzip2
cp -av /build/bzip2-1.0.6/libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat
rm -rf /build/bzip2-1.0.6

step "# 6.23. Pkg-config-0.29.2"
extract /sources/pkg-config-0.29.2.tar.gz /build
( cd /build/pkg-config-0.29.2 && \
./configure \
--prefix=/usr \
--with-internal-glib \
--disable-host-tool \
--docdir=/usr/share/doc/pkg-config-0.29.2 )
make -j$PARALLEL_JOBS -C /build/pkg-config-0.29.2
make -j$PARALLEL_JOBS install -C /build/pkg-config-0.29.2
rm -rf /build/pkg-config-0.29.2

step "# 6.24. Ncurses-6.1"
extract /sources/ncurses-6.1.tar.gz /build
sed -i '/LIBTOOL_INSTALL/d' /build/ncurses-6.1/c++/Makefile.in
( cd /build/ncurses-6.1 && \
./configure \
--prefix=/usr \
--mandir=/usr/share/man \
--with-shared \
--without-debug \
--without-normal \
--enable-pc-files \
--enable-widec )
make -j$PARALLEL_JOBS -C /build/ncurses-6.1
make -j$PARALLEL_JOBS install -C /build/ncurses-6.1
mv -v /usr/lib/libncursesw.so.6* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so
rm -rf /build/ncurses-6.1

step "# 6.25. Attr-2.4.48"
extract /sources/attr-2.4.48.tar.gz /build
( cd /build/attr-2.4.48 && \
./configure \
--prefix=/usr \
--disable-static \
--sysconfdir=/etc \
--docdir=/usr/share/doc/attr-2.4.48 )
make -j$PARALLEL_JOBS -C /build/attr-2.4.48
make -j$PARALLEL_JOBS install -C /build/attr-2.4.48
mv -v /usr/lib/libattr.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
rm -rf /build/attr-2.4.48

step "# 6.26. Acl-2.2.53"
extract /sources/acl-2.2.53.tar.gz /build
( cd /build/acl-2.2.53 && \
./configure \
--prefix=/usr \
--disable-static \
--libexecdir=/usr/lib \
--docdir=/usr/share/doc/acl-2.2.53 )
make -j$PARALLEL_JOBS -C /build/acl-2.2.53
make -j$PARALLEL_JOBS install -C /build/acl-2.2.53
mv -v /usr/lib/libacl.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
rm -rf /build/acl-2.2.53

step "# 6.27. Libcap-2.26"
extract /sources/libcap-2.26.tar.xz /build
sed -i '/install.*STALIBNAME/d' /build/libcap-2.26/libcap/Makefile
make -j$PARALLEL_JOBS -C /build/libcap-2.26
make -j$PARALLEL_JOBS RAISE_SETFCAP=no lib=lib prefix=/usr install -C /build/libcap-2.26
chmod -v 755 /usr/lib/libcap.so.2.26
mv -v /usr/lib/libcap.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
rm -rf /build/libcap-2.26

step "# 6.28. Sed-4.7"
extract /sources/sed-4.7.tar.xz /build
sed -i 's/usr/tools/' /build/sed-4.7/build-aux/help2man
sed -i 's/testsuite.panic-tests.sh//' /build/sed-4.7/Makefile.in
( cd /build/sed-4.7 && \
./configure \
--prefix=/usr \
--bindir=/bin )
make -j$PARALLEL_JOBS -C /build/sed-4.7
make -j$PARALLEL_JOBS install -C /build/sed-4.7
rm -rf /build/sed-4.7

step "# 6.29. Psmisc-23.2"
extract /sources/psmisc-23.2.tar.xz /build
( cd /build/psmisc-23.2 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/psmisc-23.2
make -j$PARALLEL_JOBS install -C /build/psmisc-23.2
mv -v /usr/bin/fuser   /bin
mv -v /usr/bin/killall /bin
rm -rf /build/psmisc-23.2

step "# 6.30. Iana-Etc-2.30"
extract /sources/iana-etc-2.30.tar.bz2 /build
make -j$PARALLEL_JOBS -C /build/iana-etc-2.30
make -j$PARALLEL_JOBS install -C /build/iana-etc-2.30
rm -rf /build/iana-etc-2.30

step "# 6.31. Bison-3.3.2"
extract /sources/bison-3.3.2.tar.xz /build
( cd /build/bison-3.3.2 && \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/bison-3.3.2 )
make -j$PARALLEL_JOBS -C /build/bison-3.3.2
make -j$PARALLEL_JOBS install -C /build/bison-3.3.2
rm -rf /build/bison-3.3.2

step "# 6.32. Flex-2.6.4"
extract /sources/flex-2.6.4.tar.gz /build
sed -i "/math.h/a #include <malloc.h>" /build/flex-2.6.4/src/flexdef.h
( cd /build/flex-2.6.4 && \
HELP2MAN=/tools/bin/true \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/flex-2.6.4 )
make -j$PARALLEL_JOBS -C /build/flex-2.6.4
make -j$PARALLEL_JOBS install -C /build/flex-2.6.4
ln -sv flex /usr/bin/lex
rm -rf /build/flex-2.6.4

step "# 6.33. Grep-3.3"
extract /sources/grep-3.3.tar.xz /build
( cd /build/grep-3.3 && \
./configure \
--prefix=/usr \
--bindir=/bin )
make -j$PARALLEL_JOBS -C /build/grep-3.3
make -j$PARALLEL_JOBS install -C /build/grep-3.3
rm -rf /build/grep-3.3

step "# 6.34. Bash-5.0"
extract /sources/bash-5.0.tar.gz /build
( cd /build/bash-5.0 && \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/bash-5.0 \
--without-bash-malloc \
--with-installed-readline )
make -j$PARALLEL_JOBS -C /build/bash-5.0
make -j$PARALLEL_JOBS install -C /build/bash-5.0
mv -vf /usr/bin/bash /bin
rm -rf /build/bash-5.0

step "# 6.35. Libtool-2.4.6"
extract /sources/libtool-2.4.6.tar.xz /build
( cd /build/libtool-2.4.6 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/libtool-2.4.6
make -j$PARALLEL_JOBS install -C /build/libtool-2.4.6
rm -rf /build/libtool-2.4.6

step "# 6.36. GDBM-1.18.1"
extract /sources/gdbm-1.18.1.tar.gz /build
( cd /build/gdbm-1.18.1 && \
./configure \
--prefix=/usr \
--disable-static \
--enable-libgdbm-compat )
make -j$PARALLEL_JOBS -C /build/gdbm-1.18.1
make -j$PARALLEL_JOBS install -C /build/gdbm-1.18.1
rm -rf /build/gdbm-1.18.1

step "# 6.37. Gperf-3.1"
extract /sources/gperf-3.1.tar.gz /build
( cd /build/gperf-3.1 && \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/gperf-3.1 )
make -j$PARALLEL_JOBS -C /build/gperf-3.1
make -j$PARALLEL_JOBS install -C /build/gperf-3.1
rm -rf /build/gperf-3.1

step "# 6.38. Expat-2.2.6"
extract /sources/expat-2.2.6.tar.bz2 /build
sed -i 's|usr/bin/env |bin/|' /build/expat-2.2.6/run.sh.in
( cd /build/expat-2.2.6 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/expat-2.2.6 )
make -j$PARALLEL_JOBS -C /build/expat-2.2.6
make -j$PARALLEL_JOBS install -C /build/expat-2.2.6
rm -rf /build/expat-2.2.6

step "# 6.39. Inetutils-1.9.4"
extract /sources/inetutils-1.9.4.tar.xz /build
( cd /build/inetutils-1.9.4 && \
./configure \
--prefix=/usr \
--localstatedir=/var \
--disable-logger \
--disable-whois \
--disable-rcp \
--disable-rexec \
--disable-rlogin \
--disable-rsh \
--disable-servers )
make -j$PARALLEL_JOBS -C /build/inetutils-1.9.4
make -j$PARALLEL_JOBS install -C /build/inetutils-1.9.4
mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin
rm -rf /build/inetutils-1.9.4

step "# 6.40. Perl-5.28.1"
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
export BUILD_ZLIB=False
export BUILD_BZIP2=0
extract /sources/perl-5.28.1.tar.xz /build
( cd /build/perl-5.28.1 && \
sh Configure \
-des \
-Dprefix=/usr \
-Dvendorprefix=/usr \
-Dman1dir=/usr/share/man/man1 \
-Dman3dir=/usr/share/man/man3 \
-Dpager="/usr/bin/less -isR" \
-Duseshrplib \
-Dusethreads )
make -j$PARALLEL_JOBS -C /build/perl-5.28.1
make -j$PARALLEL_JOBS install -C /build/perl-5.28.1
unset BUILD_ZLIB BUILD_BZIP2
rm -rf /build/perl-5.28.1

step "# 6.41. XML::Parser-2.44"
extract /sources/XML-Parser-2.44.tar.gz /build
( cd /build/XML-Parser-2.44 && perl Makefile.PL )
make -j$PARALLEL_JOBS -C /build/XML-Parser-2.44
make -j$PARALLEL_JOBS install -C /build/XML-Parser-2.44
rm -rf /build/XML-Parser-2.44

step "# 6.42. Intltool-0.51.0"
extract /sources/intltool-0.51.0.tar.gz /build
sed -i 's:\\\${:\\\$\\{:' /build/intltool-0.51.0/intltool-update.in
( cd /build/intltool-0.51.0 && \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/gperf-3.1 )
make -j$PARALLEL_JOBS -C /build/intltool-0.51.0
make -j$PARALLEL_JOBS install -C /build/intltool-0.51.0
rm -rf /build/intltool-0.51.0

step "# 6.43. Autoconf-2.69"
extract /sources/autoconf-2.69.tar.xz /build
sed '361 s/{/\\{/' -i /build/autoconf-2.69/bin/autoscan.in
( cd /build/autoconf-2.69 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/autoconf-2.69
make -j$PARALLEL_JOBS install -C /build/autoconf-2.69
rm -rf /build/autoconf-2.69

step "# 6.44. Automake-1.16.1"
extract /sources/automake-1.16.1.tar.xz /build
( cd /build/automake-1.16.1 && \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/automake-1.16.1 )
make -j$PARALLEL_JOBS -C /build/automake-1.16.1
make -j$PARALLEL_JOBS install -C /build/automake-1.16.1
rm -rf /build/automake-1.16.1

step "# 6.45. Xz-5.2.4"
extract /sources/xz-5.2.4.tar.xz /build
( cd /build/xz-5.2.4 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/xz-5.2.4 )
make -j$PARALLEL_JOBS -C /build/xz-5.2.4
make -j$PARALLEL_JOBS install -C /build/xz-5.2.4
mv -v /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
rm -rf /build/xz-5.2.4

step "# 6.46. Kmod-26"
extract /sources/kmod-26.tar.xz /build
( cd /build/kmod-26 && \
./configure \
--prefix=/usr \
--bindir=/bin \
--sysconfdir=/etc \
--with-rootlibdir=/lib \
--with-xz \
--with-zlib )
make -j$PARALLEL_JOBS -C /build/kmod-26
make -j$PARALLEL_JOBS install -C /build/kmod-26
for target in depmod insmod lsmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /sbin/$target
done
ln -sfv kmod /bin/lsmod
rm -rf /build/kmod-26

step "# 6.47. Gettext-0.19.8.1"
extract /sources/gettext-0.19.8.1.tar.xz /build
sed -i '/^TESTS =/d' /build/gettext-0.19.8.1/gettext-runtime/tests/Makefile.in &&
sed -i 's/test-lock..EXEEXT.//' /build/gettext-0.19.8.1/gettext-tools/gnulib-tests/Makefile.in
sed -e '/AppData/{N;N;p;s/\.appdata\./.metainfo./}' \
    -i /build/gettext-0.19.8.1/gettext-tools/its/appdata.loc
( cd /build/gettext-0.19.8.1 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/gettext-0.19.8.1 )
make -j$PARALLEL_JOBS -C /build/gettext-0.19.8.1
make -j$PARALLEL_JOBS install -C /build/gettext-0.19.8.1
chmod -v 0755 /usr/lib/preloadable_libintl.so
rm -rf /build/gettext-0.19.8.1

step "# 6.48. Libelf from Elfutils-0.176"
extract /sources/elfutils-0.176.tar.bz2 /build
( cd /build/elfutils-0.176 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/elfutils-0.176
make -j$PARALLEL_JOBS install -C /build/elfutils-0.176/libelf
install -vm644 /build/elfutils-0.176/config/libelf.pc /usr/lib/pkgconfig
rm -rf /build/elfutils-0.176

step "# 6.49. Libffi-3.2.1"
extract /sources/libffi-3.2.1.tar.gz /build
sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i /build/libffi-3.2.1/include/Makefile.in
sed -e '/^includedir/ s/=.*$/=@includedir@/' \
    -e 's/^Cflags: -I${includedir}/Cflags:/' \
    -i /build/libffi-3.2.1/libffi.pc.in
( cd /build/libffi-3.2.1 && \
./configure \
--prefix=/usr \
--disable-static \
--with-gcc-arch=native )
make -j$PARALLEL_JOBS -C /build/libffi-3.2.1
make -j$PARALLEL_JOBS install -C /build/libffi-3.2.1
rm -rf /build/libffi-3.2.1

step "# 6.50. OpenSSL-1.1.1b"
extract /sources/openssl-1.1.1b.tar.gz /build
( cd /build/openssl-1.1.1b && \
./config \
--prefix=/usr         \
--openssldir=/etc/ssl \
--libdir=lib \
shared \
zlib-dynamic )
make -j$PARALLEL_JOBS -C /build/openssl-1.1.1b
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' /build/openssl-1.1.1b/Makefile
make -j$PARALLEL_JOBS MANSUFFIX=ssl install -C /build/openssl-1.1.1b
rm -rf /build/openssl-1.1.1b

step "# 6.51. Python-3.7.3"
extract /sources/Python-3.7.3.tar.xz /build
( cd /build/Python-3.7.3 && \
./configure \
--prefix=/usr \
--enable-shared \
--with-system-expat \
--with-system-ffi \
--with-ensurepip=yes )
make -j$PARALLEL_JOBS -C /build/Python-3.7.3
make -j$PARALLEL_JOBS install -C /build/Python-3.7.3
chmod -v 755 /usr/lib/libpython3.7m.so
chmod -v 755 /usr/lib/libpython3.so
ln -sfv pip3.7 /usr/bin/pip3
rm -rf /build/Python-3.7.3

step "# 6.52. Ninja-1.9.0"
export NINJAJOBS=$PARALLEL_JOBS
extract /sources/ninja-1.9.0.tar.gz /build
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' /build/ninja-1.9.0/src/ninja.cc
( cd /build/ninja-1.9.0 && python3 configure.py --bootstrap )
install -vm755 /build/ninja-1.9.0/ninja /usr/bin/
install -vDm644 /build/ninja-1.9.0/misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 /build/ninja-1.9.0/misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
rm -rf /build/ninja-1.9.0

step "# 6.53. Meson-0.49.2"
extract /sources/meson-0.49.2.tar.gz /build
( cd /build/meson-0.49.2 && python3 setup.py build )
( cd /build/meson-0.49.2 && python3 setup.py install --root=dest )
cp -rv /build/meson-0.49.2/dest/* /
rm -rf /build/meson-0.49.2

step "# 6.54. Coreutils-8.31"
extract /sources/coreutils-8.31.tar.xz /build
patch -Np1 -i /sources/coreutils-8.31-i18n-1.patch -d /build/coreutils-8.31
sed -i '/test.lock/s/^/#/' /build/coreutils-8.31/gnulib-tests/gnulib.mk
( cd /build/coreutils-8.31 && autoreconf -fiv )
( cd /build/coreutils-8.31 && \
FORCE_UNSAFE_CONFIGURE=1 \
./configure \
--prefix=/usr \
--enable-no-install-program=kill,uptime )
FORCE_UNSAFE_CONFIGURE=1 make -j$PARALLEL_JOBS -C /build/coreutils-8.31
make -j$PARALLEL_JOBS install -C /build/coreutils-8.31
mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
mv -v /usr/bin/{head,nice,sleep,touch} /bin
rm -rf /build/coreutils-8.31

step "# 6.55. Check-0.12.0"
extract /sources/check-0.12.0.tar.gz /build
( cd /build/check-0.12.0 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/check-0.12.0
make -j$PARALLEL_JOBS install -C /build/check-0.12.0
sed -i '1 s/tools/usr/' /usr/bin/checkmk
rm -rf /build/check-0.12.0

step "# 6.56. Diffutils-3.7"
extract /sources/diffutils-3.7.tar.xz /build
( cd /build/diffutils-3.7 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/diffutils-3.7
make -j$PARALLEL_JOBS install -C /build/diffutils-3.7
rm -rf /build/diffutils-3.7

step "# 6.57. Gawk-4.2.1"
extract /sources/gawk-4.2.1.tar.xz /build
sed -i 's/extras//' /build/gawk-4.2.1/Makefile.in
( cd /build/gawk-4.2.1 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/gawk-4.2.1
make -j$PARALLEL_JOBS install -C /build/gawk-4.2.1
rm -rf /build/gawk-4.2.1

step "# 6.58. Findutils-4.6.0"
extract /sources/findutils-4.6.0.tar.gz /build
sed -i 's/test-lock..EXEEXT.//' /build/findutils-4.6.0/tests/Makefile.in
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' /build/findutils-4.6.0/gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' /build/findutils-4.6.0/gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> /build/findutils-4.6.0/gl/lib/stdio-impl.h
( cd /build/findutils-4.6.0 && \
./configure \
--prefix=/usr \
--localstatedir=/var/lib/locate )
make -j$PARALLEL_JOBS -C /build/findutils-4.6.0
make -j$PARALLEL_JOBS install -C /build/findutils-4.6.0
mv -v /usr/bin/find /bin
sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb
rm -rf /build/findutils-4.6.0

step "# 6.62. Gzip-1.10"
extract /sources/gzip-1.10.tar.xz /build
( cd /build/gzip-1.10 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/gzip-1.10
make -j$PARALLEL_JOBS install -C /build/gzip-1.10
mv -v /usr/bin/gzip /bin
rm -rf /build/gzip-1.10

step "# 6.63. IPRoute2-5.0.0"
extract /sources/iproute2-5.0.0.tar.xz /build
sed -i /ARPD/d /build/iproute2-5.0.0/Makefile
rm -fv /build/iproute2-5.0.0/man/man8/arpd.8
sed -i 's/.m_ipt.o//' /build/iproute2-5.0.0/tc/Makefile
make -j$PARALLEL_JOBS -C /build/iproute2-5.0.0
make -j$PARALLEL_JOBS DOCDIR=/usr/share/doc/iproute2-5.0.0 install -C /build/iproute2-5.0.0
rm -rf /build/iproute2-5.0.0

step "# 6.65. Libpipeline-1.5.1"
extract /sources/libpipeline-1.5.1.tar.gz /build
( cd /build/libpipeline-1.5.1 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/libpipeline-1.5.1
make -j$PARALLEL_JOBS install -C /build/libpipeline-1.5.1
rm -rf /build/libpipeline-1.5.1

step "# 6.66. Make-4.2.1"
extract /sources/make-4.2.1.tar.bz2 /build
sed -i '211,217 d; 219,229 d; 232 d' /build/make-4.2.1/glob/glob.c
( cd /build/make-4.2.1 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/make-4.2.1
make -j$PARALLEL_JOBS install -C /build/make-4.2.1
rm -rf /build/make-4.2.1

step "# 6.67. Patch-2.7.6"
extract /sources/patch-2.7.6.tar.xz /build
( cd /build/patch-2.7.6 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C /build/patch-2.7.6
make -j$PARALLEL_JOBS install -C /build/patch-2.7.6
rm -rf /build/patch-2.7.6

step "# 6.69. Tar-1.32"
extract /sources/tar-1.32.tar.xz /build
( cd /build/tar-1.32 && \
FORCE_UNSAFE_CONFIGURE=1  \
./configure \
--prefix=/usr \
--bindir=/bin )
make -j$PARALLEL_JOBS -C /build/tar-1.32
make -j$PARALLEL_JOBS install -C /build/tar-1.32
rm -rf /build/tar-1.32

step "# 6.70. Texinfo-6.6"
extract /sources/texinfo-6.6.tar.xz /build
( cd /build/texinfo-6.6 && \
FORCE_UNSAFE_CONFIGURE=1  \
./configure \
--prefix=/usr \
--disable-static )
make -j$PARALLEL_JOBS -C /build/texinfo-6.6
make -j$PARALLEL_JOBS install -C /build/texinfo-6.6
rm -rf /build/texinfo-6.6

step "# 6.72. Systemd-241"
extract /sources/systemd-241.tar.gz /build
ln -sf /tools/bin/true /usr/bin/xsltproc
for file in /tools/lib/lib{blkid,mount,uuid}*; do
    ln -sf $file /usr/lib/
done
extract /sources/systemd-man-pages-241.tar.xz /build/systemd-241
sed '177,$ d' -i /build/systemd-241/src/resolve/meson.build
sed -i 's/GROUP="render", //' /build/systemd-241/rules/50-udev-default.rules.in
mkdir -v /build/systemd-241/build
( cd /build/systemd-241/build && \
PKG_CONFIG_PATH="/usr/lib/pkgconfig:/tools/lib/pkgconfig" \
LANG=en_US.UTF-8 \
meson \
--prefix=/usr \
--sysconfdir=/etc \
--localstatedir=/var \
-Dblkid=true \
-Dbuildtype=release \
-Ddefault-dnssec=no \
-Dfirstboot=false \
-Dinstall-tests=false \
-Dkill-path=/bin/kill \
-Dkmod-path=/bin/kmod \
-Dldconfig=false \
-Dmount-path=/bin/mount \
-Drootprefix= \
-Drootlibdir=/lib \
-Dsplit-usr=true \
-Dsulogin-path=/sbin/sulogin \
-Dsysusers=false \
-Dumount-path=/bin/umount    \
-Db_lto=false \
.. )
( cd /build/systemd-241/build && LANG=en_US.UTF-8 ninja )
( cd /build/systemd-241/build && LANG=en_US.UTF-8 ninja install )
rm -rfv /usr/lib/rpm
rm -f /usr/bin/xsltproc
systemd-machine-id-setup
cat > /lib/systemd/systemd-user-sessions << "EOF"
#!/bin/bash
rm -f /run/nologin
EOF
chmod 755 /lib/systemd/systemd-user-sessions
rm -rf /build/systemd-241

step "# 6.73. D-Bus-1.12.12"
extract /sources/dbus-1.12.12.tar.gz /build
( cd /build/dbus-1.12.12 && \
./configure \
--prefix=/usr \
--sysconfdir=/etc \
--localstatedir=/var \
--disable-static \
--disable-doxygen-docs \
--disable-xml-docs \
--docdir=/usr/share/doc/dbus-1.12.12 \
--with-console-auth-dir=/run/console )
make -j$PARALLEL_JOBS -C /build/dbus-1.12.12
make -j$PARALLEL_JOBS install -C /build/dbus-1.12.12
mv -v /usr/lib/libdbus-1.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libdbus-1.so) /usr/lib/libdbus-1.so
ln -sfv /etc/machine-id /var/lib/dbus
rm -rf /build/dbus-1.12.12

step "# 6.74. Procps-ng-3.3.15"
extract /sources/procps-ng-3.3.15.tar.xz /build
( cd /build/procps-ng-3.3.15 && \
./configure \
--prefix=/usr \
--exec-prefix= \
--libdir=/usr/lib \
--docdir=/usr/share/doc/procps-ng-3.3.15 \
--disable-static \
--disable-kill \
--with-systemd )
make -j$PARALLEL_JOBS -C /build/procps-ng-3.3.15
make -j$PARALLEL_JOBS install -C /build/procps-ng-3.3.15
mv -v /usr/lib/libprocps.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
rm -rf /build/procps-ng-3.3.15

step "# 6.75. Util-linux-2.33.1"
mkdir -pv /var/lib/hwclock
rm -vf /usr/include/{blkid,libmount,uuid}
extract /sources/util-linux-2.33.1.tar.xz /build
( cd /build/util-linux-2.33.1 && \
./configure \
ADJTIME_PATH=/var/lib/hwclock/adjtime \
--docdir=/usr/share/doc/util-linux-2.33.1 \
--disable-chfn-chsh \
--disable-login \
--disable-nologin \
--disable-su \
--disable-setpriv \
--disable-runuser \
--disable-pylibmount \
--disable-static \
--without-python )
make -j$PARALLEL_JOBS -C /build/util-linux-2.33.1
make -j$PARALLEL_JOBS install -C /build/util-linux-2.33.1
rm -rf /build/util-linux-2.33.1

step "# 6.76. E2fsprogs-1.45.0"
extract /sources/e2fsprogs-1.45.0.tar.gz /build
mkdir -v /build/e2fsprogs-1.45.0/build
( cd /build/e2fsprogs-1.45.0/build && \
./configure \
--prefix=/usr \
--bindir=/bin \
--with-root-prefix="" \
--enable-elf-shlibs \
--disable-libblkid \
--disable-libuuid \
--disable-uuidd \
--disable-fsck )
make -j$PARALLEL_JOBS -C /build/e2fsprogs-1.45.0/build
make -j$PARALLEL_JOBS install -C /build/e2fsprogs-1.45.0/build
make -j$PARALLEL_JOBS install-libs -C /build/e2fsprogs-1.45.0/build
chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
rm -rf /build/e2fsprogs-1.45.0
