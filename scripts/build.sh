#!/tools/bin/bash
#
# Linux From Scratch Build Script - Version 20190214-systemd
# https://github.com/LeeKyuHyuk/Linux-From-Scratch-Build-Script
#
# Optional parameteres below:
PARALLEL_JOBS=`cat /proc/cpuinfo | grep cores | wc -l`
STRIP_AND_DELETE_DOCS=1     # Strip binaries and delete manpages to save space at the end of chapter 5?
CONFIG_PKG_VERSION="Linux From Scratch Build Script"
CONFIG_BUG_URL="https://github.com/LeeKyuHyuk/Linux-From-Scratch-Build-Script/issues"
PACKAGES_DIR=/packages
BUILD_DIR=/build
# End of optional parameters
set +h
set -o nounset
set -o errexit
umask 022

export LC_ALL=POSIX
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

function check_environment_variable {
    if ! [[ -d $PACKAGES_DIR ]] ; then
        error "Please download tarball files!"
        error "Run 'make download'."
        exit 1
    fi
}


function check_tarballs {
    LIST_OF_TARBALLS="
    "

  for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f $SOURCES_DIR/$tarball ]] ; then
      error "Can't find '$tarball'!"
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

check_environment_variable
check_tarballs
total_build_time=$(timer)

step "Creating Directories"
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

step "Creating Essential Files and Symlinks"
ln -sv /tools/bin/{bash,cat,dd,echo,ln,pwd,rm,stty} /bin
ln -sv /tools/bin/{env,install,perl} /usr/bin
ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib
ln -sv /tools/lib/libstdc++.{a,so{,.6}} /usr/lib
for lib in blkid lzma mount uuid
do
    ln -sv /tools/lib/lib$lib.so* /usr/lib
done
ln -svf /tools/include/blkid    /usr/include
ln -svf /tools/include/libmount /usr/include
ln -svf /tools/include/uuid     /usr/include
install -vdm755 /usr/lib/pkgconfig
for pc in blkid mount uuid
do
    sed 's@tools@usr@g' /tools/lib/pkgconfig/${pc}.pc \
        > /usr/lib/pkgconfig/${pc}.pc
done
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
nogroup:x:99:
users:x:999:
EOF
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

step "Linux-4.18.5 API Headers"
extract $PACKAGES_DIR/linux-4.18.5.tar.xz $BUILD_DIR
make mrproper -C $BUILD_DIR/linux-4.18.5
make INSTALL_HDR_PATH=$BUILD_DIR/linux-4.18.5/dest headers_install -C $BUILD_DIR/linux-4.18.5
find $BUILD_DIR/linux-4.18.5/dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv $BUILD_DIR/linux-4.18.5/dest/include/* /usr/include
rm -rf $BUILD_DIR/linux-4.18.5

step "Man-pages-4.16"
extract $PACKAGES_DIR/man-pages-4.16.tar.xz $BUILD_DIR
make -j1 install -C $BUILD_DIR/man-pages-4.16
rm -rf $BUILD_DIR/man-pages-4.16

step "Glibc-2.28"
extract $PACKAGES_DIR/glibc-2.28.tar.xz $BUILD_DIR
patch -Np1 -i $PACKAGES_DIR/glibc-2.28-fhs-1.patch -d $BUILD_DIR/glibc-2.28
ln -sfv /tools/lib/gcc /usr/lib
case $(uname -m) in
    i?86)    GCC_INCDIR=/usr/lib/gcc/$(uname -m)-pc-linux-gnu/8.2.0/include
            ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    ;;
    x86_64) GCC_INCDIR=/usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    ;;
esac
rm -f /usr/include/limits.h
mkdir -pv $BUILD_DIR/glibc-2.28/build
( cd $BUILD_DIR/glibc-2.28/build && \
CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
../configure \
--prefix=/usr                          \
--disable-werror                       \
--enable-kernel=3.2                    \
--enable-stack-protector=strong        \
libc_cv_slibdir=/lib )
unset GCC_INCDIR
make -j$PARALLEL_JOBS -C $BUILD_DIR/glibc-2.28/build
case $(uname -m) in
  i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
  x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
esac
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i $BUILD_DIR/glibc-2.28/Makefile
make -j$PARALLEL_JOBS install -C $BUILD_DIR/glibc-2.28/build
cp -v $BUILD_DIR/glibc-2.28/nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
install -v -Dm644 $BUILD_DIR/glibc-2.28/nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
install -v -Dm644 $BUILD_DIR/glibc-2.28/nscd/nscd.service /lib/systemd/system/nscd.service
make -j$PARALLEL_JOBS localedata/install-locales -C $BUILD_DIR/glibc-2.28/build
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

mkdir -pv $BUILD_DIR/tzdata2018i
extract $PACKAGES_DIR/tzdata2018i.tar.gz $BUILD_DIR/tzdata2018i
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in $BUILD_DIR/tzdata2018i/etcetera $BUILD_DIR/tzdata2018i/southamerica \
$BUILD_DIR/tzdata2018i/northamerica $BUILD_DIR/tzdata2018i/europe \
$BUILD_DIR/tzdata2018i/africa $BUILD_DIR/tzdata2018i/antarctica  \
$BUILD_DIR/tzdata2018i/asia $BUILD_DIR/tzdata2018i/australasia $BUILD_DIR/tzdata2018i/backward $BUILD_DIR/tzdata2018i/pacificnew $BUILD_DIR/tzdata2018i/systemv; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L $BUILD_DIR/tzdata2018i/leapseconds -d $ZONEINFO/right ${tz}
done

cp -v $BUILD_DIR/tzdata2018i/{zone.tab,zone1970.tab,iso3166.tab} $ZONEINFO
rm -rf $BUILD_DIR/tzdata2018i
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
ln -sfv /usr/share/zoneinfo/America/New_York /etc/localtime
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
rm -rf $BUILD_DIR/glibc-2.28

step "Adjusting the Toolchain"
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
gcc -dumpspecs | sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs

step "Zlib-1.2.11"
extract $PACKAGES_DIR/zlib-1.2.11.tar.xz $BUILD_DIR
( cd $BUILD_DIR/zlib-1.2.11 && ./configure --prefix=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/zlib-1.2.11
make -j$PARALLEL_JOBS install -C $BUILD_DIR/zlib-1.2.11
rm -rf $BUILD_DIR/zlib-1.2.11
mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so

step "File-5.34"
extract $PACKAGES_DIR/file-5.34.tar.gz $BUILD_DIR
( cd $BUILD_DIR/file-5.34 && ./configure --prefix=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/file-5.34
make -j$PARALLEL_JOBS install -C $BUILD_DIR/file-5.34
rm -rf $BUILD_DIR/file-5.34

step "Readline-7.0"
extract $PACKAGES_DIR/readline-7.0.tar.gz $BUILD_DIR
sed -i '/MV.*old/d' $BUILD_DIR/readline-7.0/Makefile.in
sed -i '/{OLDSUFF}/c:' $BUILD_DIR/readline-7.0/support/shlib-install
( cd $BUILD_DIR/readline-7.0 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/readline-7.0 )
make -j$PARALLEL_JOBS SHLIB_LIBS="-L/tools/lib -lncurses" -C $BUILD_DIR/readline-7.0
make -j$PARALLEL_JOBS SHLIB_LIBS="-L/tools/lib -lncurses" install -C $BUILD_DIR/readline-7.0
mv -v /usr/lib/lib{readline,history}.so.* /lib
chmod -v u+w /lib/lib{readline,history}.so.*
ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
rm -rf $BUILD_DIR/readline-7.0

step "M4-1.4.18"
extract $PACKAGES_DIR/m4-1.4.18.tar.xz $BUILD_DIR
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' $BUILD_DIR/m4-1.4.18/lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> $BUILD_DIR/m4-1.4.18/lib/stdio-impl.h
( cd $BUILD_DIR/m4-1.4.18 && ./configure --prefix=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/m4-1.4.18
make -j$PARALLEL_JOBS install -C $BUILD_DIR/m4-1.4.18
rm -rf $BUILD_DIR/m4-1.4.18

step "Bc-1.07.1"
extract $PACKAGES_DIR/bc-1.07.1.tar.gz $BUILD_DIR
cat > $BUILD_DIR/bc-1.07.1/bc/fix-libmath_h << "EOF"
#!/bin/bash
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
sed -i -e '/flex/s/as_fn_error/: ;; # &/' $BUILD_DIR/bc-1.07.1/configure
( cd $BUILD_DIR/bc-1.07.1 && \
./configure \
--prefix=/usr \
--with-readline \
--mandir=/usr/share/man \
--infodir=/usr/share/info )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bc-1.07.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bc-1.07.1
rm -rf $BUILD_DIR/bc-1.07.1

step "Binutils-2.31.1"
extract $PACKAGES_DIR/binutils-2.31.1.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/binutils-2.31.1/build
( cd $BUILD_DIR/binutils-2.31.1/build && \
../configure \
--prefix=/usr \
--enable-gold \
--enable-ld=default \
--enable-plugins \
--enable-shared \
--disable-werror \
--enable-64-bit-bfd \
--with-system-zlib )
make -j$PARALLEL_JOBS tooldir=/usr -C $BUILD_DIR/binutils-2.31.1/build
make -j$PARALLEL_JOBS tooldir=/usr install -C $BUILD_DIR/binutils-2.31.1/build
rm -rf $BUILD_DIR/binutils-2.31.1

step "GMP-6.1.2"
extract $PACKAGES_DIR/gmp-6.1.2.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gmp-6.1.2 && \
./configure \
--prefix=/usr \
--enable-cxx \
--disable-static \
--docdir=/usr/share/doc/gmp-6.1.2 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gmp-6.1.2
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gmp-6.1.2
rm -rf $BUILD_DIR/gmp-6.1.2

step "MPFR-4.0.1"
extract $PACKAGES_DIR/mpfr-4.0.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/mpfr-4.0.1 && \
./configure \
--prefix=/usr \
--disable-static \
--enable-thread-safe \
--docdir=/usr/share/doc/mpfr-4.0.1 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpfr-4.0.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/mpfr-4.0.1
rm -rf $BUILD_DIR/mpfr-4.0.1

step "MPC-1.1.0"
extract $PACKAGES_DIR/mpc-1.1.0.tar.gz $BUILD_DIR
( cd $BUILD_DIR/mpc-1.1.0 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/mpc-1.1.0 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpc-1.1.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/mpc-1.1.0
rm -rf $BUILD_DIR/mpc-1.1.0

step "Shadow-4.6"
extract $PACKAGES_DIR/shadow-4.6.tar.xz $BUILD_DIR
sed -i 's/groups$(EXEEXT) //' $BUILD_DIR/shadow-4.6/src/Makefile.in
( cd $BUILD_DIR/shadow-4.6 && find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \; )
( cd $BUILD_DIR/shadow-4.6 && find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \; )
( cd $BUILD_DIR/shadow-4.6 && find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \; )
sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' $BUILD_DIR/shadow-4.6/etc/login.defs
sed -i 's/1000/999/' $BUILD_DIR/shadow-4.6/etc/useradd
( cd $BUILD_DIR/shadow-4.6 && \
./configure \
--sysconfdir=/etc \
--with-group-name-max-length=32 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/shadow-4.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/shadow-4.6
mv -v /usr/bin/passwd /bin
pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd
rm -rf $BUILD_DIR/shadow-4.6

step "GCC-8.2.0"
extract $PACKAGES_DIR/gcc-8.2.0.tar.xz $BUILD_DIR
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig $BUILD_DIR/gcc-8.2.0/gcc/config/i386/t-linux64
  ;;
esac
rm -f /usr/lib/gcc
mkdir -pv $BUILD_DIR/gcc-8.2.0/build
( cd $BUILD_DIR/gcc-8.2.0/build && \
SED=sed \
../configure \
--prefix=/usr \
--enable-languages=c,c++ \
--disable-multilib \
--disable-bootstrap \
--disable-libmpx \
--with-system-zlib \
--with-pkgversion="$CONFIG_PKG_VERSION" \
--with-bugurl="$CONFIG_BUG_URL" )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-8.2.0/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-8.2.0/build
ln -sv ../usr/bin/cpp /lib
ln -sv gcc /usr/bin/cc
install -v -dm755 /usr/lib/bfd-plugins
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/8.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
rm -rf $BUILD_DIR/gcc-8.2.0

step "Bzip2-1.0.6"
extract $PACKAGES_DIR/bzip2-1.0.6.tar.gz $BUILD_DIR
patch -Np1 -i $PACKAGES_DIR/bzip2-1.0.6-install_docs-1.patch -d $BUILD_DIR/bzip2-1.0.6
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' $BUILD_DIR/bzip2-1.0.6/Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" $BUILD_DIR/bzip2-1.0.6/Makefile

make -j$PARALLEL_JOBS -f Makefile-libbz2_so -C $BUILD_DIR/bzip2-1.0.6
make -j$PARALLEL_JOBS clean -C $BUILD_DIR/bzip2-1.0.6
make -j$PARALLEL_JOBS -C $BUILD_DIR/bzip2-1.0.6
make -j$PARALLEL_JOBS PREFIX=/usr install -C $BUILD_DIR/bzip2-1.0.6
cp -v $BUILD_DIR/bzip2-1.0.6/bzip2-shared /bin/bzip2
cp -av $BUILD_DIR/bzip2-1.0.6/libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat
rm -rf $BUILD_DIR/bzip2-1.0.6

step "Pkg-config-0.29.2"
extract $PACKAGES_DIR/pkg-config-0.29.2.tar.gz $BUILD_DIR
( cd $BUILD_DIR/pkg-config-0.29.2 && \
./configure \
--prefix=/usr \
--with-internal-glib \
--disable-host-tool \
--docdir=/usr/share/doc/pkg-config-0.29.2 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/pkg-config-0.29.2
make -j$PARALLEL_JOBS install -C $BUILD_DIR/pkg-config-0.29.2
rm -rf $BUILD_DIR/pkg-config-0.29.2

step "Ncurses-6.1"
extract $PACKAGES_DIR/ncurses-6.1.tar.gz $BUILD_DIR
sed -i '/LIBTOOL_INSTALL/d' $BUILD_DIR/ncurses-6.1/c++/Makefile.in
( cd $BUILD_DIR/ncurses-6.1 && \
./configure \
--prefix=/usr \
--mandir=/usr/share/man \
--with-shared \
--without-debug \
--without-normal \
--enable-pc-files \
--enable-widec )
make -j$PARALLEL_JOBS -C $BUILD_DIR/ncurses-6.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/ncurses-6.1
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
rm -rf $BUILD_DIR/ncurses-6.1

step "Attr-2.4.48"
extract $PACKAGES_DIR/attr-2.4.48.tar.gz $BUILD_DIR
( cd $BUILD_DIR/attr-2.4.48 && \
./configure \
--prefix=/usr \
--disable-static  \
--sysconfdir=/etc \
--docdir=/usr/share/doc/attr-2.4.48 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/attr-2.4.48
make -j$PARALLEL_JOBS install -C $BUILD_DIR/attr-2.4.48
mv -v /usr/lib/libattr.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
rm -rf $BUILD_DIR/attr-2.4.48

step "Acl-2.2.53"
extract $PACKAGES_DIR/acl-2.2.53.tar.gz $BUILD_DIR
( cd $BUILD_DIR/acl-2.2.53 && \
./configure \
--prefix=/usr \
--disable-static  \
--libexecdir=/usr/lib \
--docdir=/usr/share/doc/acl-2.2.53 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/acl-2.2.53
make -j$PARALLEL_JOBS install -C $BUILD_DIR/acl-2.2.53
mv -v /usr/lib/libacl.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
rm -rf $BUILD_DIR/acl-2.2.53

step "Libcap-2.25"
extract $PACKAGES_DIR/libcap-2.25.tar.xz $BUILD_DIR
sed -i '/install.*STALIBNAME/d' $BUILD_DIR/libcap-2.25/libcap/Makefile
make -j$PARALLEL_JOBS -C $BUILD_DIR/libcap-2.25
make -j$PARALLEL_JOBS RAISE_SETFCAP=no lib=lib prefix=/usr install -C $BUILD_DIR/libcap-2.25
chmod -v 755 /usr/lib/libcap.so.2.25
mv -v /usr/lib/libcap.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
rm -rf $BUILD_DIR/libcap-2.25

step "Sed-4.5"
extract $PACKAGES_DIR/sed-4.5.tar.xz $BUILD_DIR
sed -i 's/usr/tools/' $BUILD_DIR/sed-4.5/build-aux/help2man
sed -i 's/testsuite.panic-tests.sh//' $BUILD_DIR/sed-4.5/Makefile.in
( cd $BUILD_DIR/sed-4.5 && \
./configure \
--prefix=/usr \
--bindir=/bin )
make -j$PARALLEL_JOBS -C $BUILD_DIR/sed-4.5
make -j$PARALLEL_JOBS install -C $BUILD_DIR/sed-4.5
rm -rf $BUILD_DIR/sed-4.5

step "Psmisc-23.1"
extract $PACKAGES_DIR/psmisc-23.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/psmisc-23.1 && \
./configure \
--prefix=/usr \
--bindir=/bin )
make -j$PARALLEL_JOBS -C $BUILD_DIR/psmisc-23.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/psmisc-23.1
rm -rf $BUILD_DIR/psmisc-23.1

step "Iana-Etc-2.30"
extract $PACKAGES_DIR/iana-etc-2.30.tar.bz2 $BUILD_DIR
make -j$PARALLEL_JOBS -C $BUILD_DIR/iana-etc-2.30
make -j$PARALLEL_JOBS install -C $BUILD_DIR/iana-etc-2.30
rm -rf $BUILD_DIR/iana-etc-2.30

step "Bison-3.0.5"
extract $PACKAGES_DIR/bison-3.0.5.tar.xz $BUILD_DIR
( cd $BUILD_DIR/bison-3.0.5 && ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.0.5 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bison-3.0.5
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bison-3.0.5
rm -rf $BUILD_DIR/bison-3.0.5

step "Flex-2.6.4"
extract $PACKAGES_DIR/flex-2.6.4.tar.gz $BUILD_DIR
sed -i "/math.h/a #include <malloc.h>" $BUILD_DIR/flex-2.6.4/src/flexdef.h
( cd $BUILD_DIR/flex-2.6.4 && \
HELP2MAN=/tools/bin/true \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/flex-2.6.4 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/flex-2.6.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/flex-2.6.4
ln -sv flex /usr/bin/lex
rm -rf $BUILD_DIR/flex-2.6.4

step "Grep-3.1"
extract $PACKAGES_DIR/grep-3.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/grep-3.1 && ./configure --prefix=/usr --bindir=/bin )
make -j$PARALLEL_JOBS -C $BUILD_DIR/grep-3.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/grep-3.1
rm -rf $BUILD_DIR/grep-3.1

step "Bash-4.4.18"
extract $PACKAGES_DIR/bash-4.4.18.tar.gz $BUILD_DIR
( cd $BUILD_DIR/bash-4.4.18 && \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/bash-4.4.18 \
--without-bash-malloc \
--with-installed-readline )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bash-4.4.18
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bash-4.4.18
mv -vf /usr/bin/bash /bin
rm -rf $BUILD_DIR/bash-4.4.18

step "Libtool-2.4.6"
extract $PACKAGES_DIR/libtool-2.4.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/libtool-2.4.6 && ./configure --prefix=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libtool-2.4.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/libtool-2.4.6
rm -rf $BUILD_DIR/libtool-2.4.6

step "GDBM-1.17"
extract $PACKAGES_DIR/gdbm-1.17.tar.gz $BUILD_DIR
( cd $BUILD_DIR/gdbm-1.17 && \
./configure \
--prefix=/usr \
--disable-static \
--enable-libgdbm-compat )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gdbm-1.17
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gdbm-1.17
rm -rf $BUILD_DIR/gdbm-1.17

step "Gperf-3.1"
extract $PACKAGES_DIR/gperf-3.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/gperf-3.1 && \
./configure \
--prefix=/usr \
--docdir=/usr/share/doc/gperf-3.1 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gperf-3.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gperf-3.1
rm -rf $BUILD_DIR/gperf-3.1

step "Expat-2.2.6"
extract $PACKAGES_DIR/expat-2.2.6.tar.bz2 $BUILD_DIR
sed -i 's|usr/bin/env |bin/|' $BUILD_DIR/expat-2.2.6/run.sh.in
( cd $BUILD_DIR/expat-2.2.6 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/expat-2.2.6 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/expat-2.2.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/expat-2.2.6
rm -rf $BUILD_DIR/expat-2.2.6

step "Inetutils-1.9.4"
extract $PACKAGES_DIR/inetutils-1.9.4.tar.xz $BUILD_DIR
( cd $BUILD_DIR/inetutils-1.9.4 && \
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
make -j$PARALLEL_JOBS -C $BUILD_DIR/inetutils-1.9.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/inetutils-1.9.4
mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin
rm -rf $BUILD_DIR/inetutils-1.9.4

step "Perl-5.28.0"
extract $PACKAGES_DIR/perl-5.28.0.tar.xz $BUILD_DIR
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
export BUILD_ZLIB=False
export BUILD_BZIP2=0
( cd $BUILD_DIR/perl-5.28.0 && \
sh Configure -des \
-Dprefix=/usr \
-Dvendorprefix=/usr \
-Dman1dir=/usr/share/man/man1 \
-Dman3dir=/usr/share/man/man3 \
-Dpager="/usr/bin/less -isR"  \
-Duseshrplib \
-Dusethreads )
make -j$PARALLEL_JOBS -C $BUILD_DIR/perl-5.28.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/perl-5.28.0
unset BUILD_ZLIB BUILD_BZIP2
rm -rf $BUILD_DIR/perl-5.28.0

step "XML::Parser-2.44"
extract $PACKAGES_DIR/XML-Parser-2.44.tar.gz $BUILD_DIR
( cd $BUILD_DIR/XML-Parser-2.44 && perl Makefile.PL )
make -j$PARALLEL_JOBS -C $BUILD_DIR/XML-Parser-2.44
make -j$PARALLEL_JOBS install -C $BUILD_DIR/XML-Parser-2.44
rm -rf $BUILD_DIR/XML-Parser-2.44

step "Intltool-0.51.0"
extract $PACKAGES_DIR/intltool-0.51.0.tar.gz $BUILD_DIR
sed -i 's:\\\${:\\\$\\{:' $BUILD_DIR/intltool-0.51.0/intltool-update.in
( cd $BUILD_DIR/intltool-0.51.0 && ./configure --prefix=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/intltool-0.51.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/intltool-0.51.0
rm -rf $BUILD_DIR/intltool-0.51.0

step "Autoconf-2.69"
extract $PACKAGES_DIR/autoconf-2.69.tar.xz $BUILD_DIR
sed '361 s/{/\\{/' -i $BUILD_DIR/autoconf-2.69/bin/autoscan.in
( cd $BUILD_DIR/autoconf-2.69 && ./configure --prefix=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/autoconf-2.69
make -j$PARALLEL_JOBS install -C $BUILD_DIR/autoconf-2.69
rm -rf $BUILD_DIR/autoconf-2.69

step "Automake-1.16.1"
extract $PACKAGES_DIR/automake-1.16.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/automake-1.16.1 && ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/automake-1.16.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/automake-1.16.1
rm -rf $BUILD_DIR/automake-1.16.1

step "Xz-5.2.4"
extract $PACKAGES_DIR/xz-5.2.4.tar.xz $BUILD_DIR
( cd $BUILD_DIR/xz-5.2.4 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/xz-5.2.4 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/xz-5.2.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/xz-5.2.4
mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
rm -rf $BUILD_DIR/xz-5.2.4

step "Kmod-25"
extract $PACKAGES_DIR/kmod-25.tar.xz $BUILD_DIR
( cd $BUILD_DIR/kmod-25 && \
./configure \
--prefix=/usr \
--bindir=/bin \
--sysconfdir=/etc \
--with-rootlibdir=/lib \
--with-xz \
--with-zlib )
make -j$PARALLEL_JOBS -C $BUILD_DIR/kmod-25
make -j$PARALLEL_JOBS install -C $BUILD_DIR/kmod-25
for target in depmod insmod lsmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /sbin/$target
done
ln -sfv kmod /bin/lsmod
rm -rf $BUILD_DIR/kmod-25

step "Gettext-0.19.8.1"
extract $PACKAGES_DIR/gettext-0.19.8.1.tar.xz $BUILD_DIR
sed -i '/^TESTS =/d' $BUILD_DIR/gettext-0.19.8.1/gettext-runtime/tests/Makefile.in &&
sed -i 's/test-lock..EXEEXT.//' $BUILD_DIR/gettext-0.19.8.1/gettext-tools/gnulib-tests/Makefile.in
sed -e '/AppData/{N;N;p;s/\.appdata\./.metainfo./}' \
    -i $BUILD_DIR/gettext-0.19.8.1/gettext-tools/its/appdata.loc
( cd $BUILD_DIR/gettext-0.19.8.1 && \
./configure \
--prefix=/usr \
--disable-static \
--docdir=/usr/share/doc/gettext-0.19.8.1 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gettext-0.19.8.1
chmod -v 0755 /usr/lib/preloadable_libintl.so
rm -rf $BUILD_DIR/gettext-0.19.8.1

step "Libelf from Elfutils-0.173"
extract $PACKAGES_DIR/elfutils-0.173.tar.bz2 $BUILD_DIR
( cd $BUILD_DIR/elfutils-0.173 && \
./configure \
--prefix=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/elfutils-0.173
make -j$PARALLEL_JOBS install -C $BUILD_DIR/elfutils-0.173/libelf
install -vm644 $BUILD_DIR/elfutils-0.173/config/libelf.pc /usr/lib/pkgconfig
rm -rf $BUILD_DIR/elfutils-0.173

step "Libffi-3.2.1"
extract $PACKAGES_DIR/libffi-3.2.1.tar.gz $BUILD_DIR
sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i $BUILD_DIR/libffi-3.2.1/include/Makefile.in
sed -e '/^includedir/ s/=.*$/=@includedir@/' \
    -e 's/^Cflags: -I${includedir}/Cflags:/' \
    -i $BUILD_DIR/libffi-3.2.1/libffi.pc.in
( cd $BUILD_DIR/libffi-3.2.1 && ./configure --prefix=/usr --disable-static --with-gcc-arch=native )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libffi-3.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/libffi-3.2.1
rm -rf $BUILD_DIR/libffi-3.2.1

step "OpenSSL-1.1.0i"
extract $PACKAGES_DIR/openssl-1.1.0i.tar.gz $BUILD_DIR
( cd $BUILD_DIR/openssl-1.1.0i && \
./config \
--prefix=/usr \
--openssldir=/etc/ssl \
--libdir=lib \
shared \
zlib-dynamic )
make -j$PARALLEL_JOBS -C $BUILD_DIR/openssl-1.1.0i
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' $BUILD_DIR/openssl-1.1.0i/Makefile
make -j$PARALLEL_JOBS MANSUFFIX=ssl install -C $BUILD_DIR/openssl-1.1.0i
rm -rf $BUILD_DIR/openssl-1.1.0i

step "Python-3.7.0"
extract $PACKAGES_DIR/Python-3.7.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/Python-3.7.0 && \
./configure \
--prefix=/usr \
--enable-shared \
--with-system-expat \
--with-system-ffi \
--with-ensurepip=yes )
make -j$PARALLEL_JOBS -C $BUILD_DIR/Python-3.7.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/Python-3.7.0
chmod -v 755 /usr/lib/libpython3.7m.so
chmod -v 755 /usr/lib/libpython3.so
rm -rf $BUILD_DIR/Python-3.7.0

step "Ninja-1.8.2"
extract $PACKAGES_DIR/ninja-1.8.2.tar.gz $BUILD_DIR
patch -Np1 -i $PACKAGES_DIR/ninja-1.8.2-add_NINJAJOBS_var-1.patch -d $BUILD_DIR/ninja-1.8.2
( cd $BUILD_DIR/ninja-1.8.2 && python3 configure.py --bootstrap )
install -vm755 $BUILD_DIR/ninja-1.8.2/ninja /usr/bin/
install -vDm644 $BUILD_DIR/ninja-1.8.2/misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 $BUILD_DIR/ninja-1.8.2/misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
rm -rf $BUILD_DIR/ninja-1.8.2

step "Meson-0.47.1"
extract $PACKAGES_DIR/meson-0.47.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/meson-0.47.1 && python3 setup.py build )
( cd $BUILD_DIR/meson-0.47.1 && python3 setup.py install --root=$BUILD_DIR/meson-0.47.1/dest )
cp -rv $BUILD_DIR/meson-0.47.1/dest/* /
rm -rf $BUILD_DIR/meson-0.47.1

step "Systemd-239"
ln -sf /tools/bin/true /usr/bin/xsltproc
extract $PACKAGES_DIR/systemd-239.tar.gz $BUILD_DIR
extract $PACKAGES_DIR/systemd-man-pages-239.tar.xz $BUILD_DIR/systemd-239
sed '166,$ d' -i $BUILD_DIR/systemd-239/src/resolve/meson.build
patch -Np1 -i $PACKAGES_DIR/systemd-239-glibc_statx_fix-1.patch -d $BUILD_DIR/systemd-239
sed -i 's/GROUP="render", //' $BUILD_DIR/systemd-239/rules/50-udev-default.rules.in
( cd $BUILD_DIR/systemd-239/build && \
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
-Dumount-path=/bin/umount \
-Db_lto=false \
.. )
( cd $BUILD_DIR/systemd-239/build && LANG=en_US.UTF-8 ninja )
( cd $BUILD_DIR/systemd-239/build && LANG=en_US.UTF-8 ninja install )
rm -rfv /usr/lib/rpm
rm -f /usr/bin/xsltproc
systemd-machine-id-setup
cat > /lib/systemd/systemd-user-sessions << "EOF"
#!/bin/bash
rm -f /run/nologin
EOF
chmod 755 /lib/systemd/systemd-user-sessions

do_strip

success "\nTotal toolchain build time: $(timer $total_build_time)\n"
