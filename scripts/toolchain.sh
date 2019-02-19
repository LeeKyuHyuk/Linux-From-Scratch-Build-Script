#!/bin/bash
#
# Linux From Scratch Build Script - Version 20190214-systemd
# https://github.com/LeeKyuHyuk/Linux-From-Scratch-Build-Script
#
# Optional parameteres below:
STRIP_AND_DELETE_DOCS=1     # Strip binaries and delete manpages to save space at the end of chapter 5?
CONFIG_PKG_VERSION="Linux From Scratch Build Script"
CONFIG_BUG_URL="https://github.com/LeeKyuHyuk/Linux-From-Scratch-Build-Script/issues"
# End of optional parameters
set +h
set -o nounset
set -o errexit
umask 022

export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=/tools/bin:/bin:/usr/bin

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

step "Creating the Tools Directory"
rm -rf $TOOLS_DIR $BUILD_DIR
mkdir -pv $TOOLS_DIR $BUILD_DIR
sudo rm -rfv /tools
sudo ln -sv $TOOLS_DIR /
sudo -k

step "binutils-2.31.1 - Pass 1"
extract $PACKAGES_DIR/binutils-2.31.1.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/binutils-2.31.1/build
( cd $BUILD_DIR/binutils-2.31.1/build && \
../configure \
--prefix=/tools \
--with-sysroot=$ROOTFS_DIR \
--with-lib-path=/tools/lib \
--target=$LFS_TGT \
--disable-nls \
--disable-werror )
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.31.1/build
case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac
make -j$PARALLEL_JOBS install -C $BUILD_DIR/binutils-2.31.1/build
rm -rf $BUILD_DIR/binutils-2.31.1

step "GCC-8.2.0 - Pass 1"
extract $PACKAGES_DIR/gcc-8.2.0.tar.xz $BUILD_DIR
extract $PACKAGES_DIR/mpfr-4.0.1.tar.xz $BUILD_DIR/gcc-8.2.0
mv -v $BUILD_DIR/gcc-8.2.0/mpfr-4.0.1 $BUILD_DIR/gcc-8.2.0/mpfr
extract $PACKAGES_DIR/gmp-6.1.2.tar.xz $BUILD_DIR/gcc-8.2.0
mv -v $BUILD_DIR/gcc-8.2.0/gmp-6.1.2 $BUILD_DIR/gcc-8.2.0/gmp
extract $PACKAGES_DIR/mpc-1.1.0.tar.gz $BUILD_DIR/gcc-8.2.0
mv -v $BUILD_DIR/gcc-8.2.0/mpc-1.1.0 $BUILD_DIR/gcc-8.2.0/mpc
for file in $BUILD_DIR/gcc-8.2.0/gcc/config/{linux,i386/linux{,64}}.h
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
    -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
touch $file.orig
done
case $(uname -m) in
x86_64)
sed -e '/m64=/s/lib64/lib/' \
-i.orig $BUILD_DIR/gcc-8.2.0/gcc/config/i386/t-linux64
;;
esac
mkdir -pv $BUILD_DIR/gcc-8.2.0/build
( cd $BUILD_DIR/gcc-8.2.0/build && \
../configure \
--target=$LFS_TGT \
--prefix=/tools \
--with-glibc-version=2.11 \
--with-sysroot=$ROOTFS_DIR \
--with-newlib \
--without-headers \
--with-local-prefix=/tools \
--with-native-system-header-dir=/tools/include \
--disable-nls \
--disable-shared \
--disable-multilib \
--disable-decimal-float \
--disable-threads \
--disable-libatomic \
--disable-libgomp \
--disable-libmpx \
--disable-libquadmath \
--disable-libssp \
--disable-libvtv \
--disable-libstdcxx \
--enable-languages=c,c++ \
--with-pkgversion="$CONFIG_PKG_VERSION" \
--with-bugurl="$CONFIG_BUG_URL" )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-8.2.0/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-8.2.0/build
rm -rf $BUILD_DIR/gcc-8.2.0

step "Linux-4.18.5 API Headers"
extract $PACKAGES_DIR/linux-4.18.5.tar.xz $BUILD_DIR
make mrproper -C $BUILD_DIR/linux-4.18.5
make INSTALL_HDR_PATH=$BUILD_DIR/linux-4.18.5/dest headers_install -C $BUILD_DIR/linux-4.18.5
cp -rv $BUILD_DIR/linux-4.18.5/dest/include/* /tools/include
rm -rf $BUILD_DIR/linux-4.18.5

step "glibc-2.28"
extract $PACKAGES_DIR/glibc-2.28.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/glibc-2.28/build
( cd $BUILD_DIR/glibc-2.28/build && \
../configure \
--prefix=/tools \
--host=$LFS_TGT \
--build=$(../scripts/config.guess) \
--enable-kernel=3.2 \
--with-headers=/tools/include \
libc_cv_forced_unwind=yes \
libc_cv_c_cleanup=yes )
make -j$PARALLEL_JOBS -C $BUILD_DIR/glibc-2.28/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/glibc-2.28/build
rm -rf $BUILD_DIR/glibc-2.28

step "Libstdc++ from GCC-8.2.0"
extract $PACKAGES_DIR/gcc-8.2.0.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/gcc-8.2.0/build
( cd $BUILD_DIR/gcc-8.2.0/build && \
../libstdc++-v3/configure \
--host=$LFS_TGT \
--prefix=/tools \
--disable-multilib \
--disable-nls \
--disable-libstdcxx-threads \
--disable-libstdcxx-pch \
--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-8.2.0/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-8.2.0/build
rm -rf $BUILD_DIR/gcc-8.2.0

step "binutils-2.31.1 - Pass 2"
extract $PACKAGES_DIR/binutils-2.31.1.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/binutils-2.31.1/build
( cd $BUILD_DIR/binutils-2.31.1/build && \
CC=$LFS_TGT-gcc \
AR=$LFS_TGT-ar \
RANLIB=$LFS_TGT-ranlib \
../configure \
--prefix=/tools \
--disable-nls \
--disable-werror \
--with-lib-path=/tools/lib \
--with-sysroot )
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.31.1/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/binutils-2.31.1/build
make -C $BUILD_DIR/binutils-2.31.1/build/ld clean
make -C $BUILD_DIR/binutils-2.31.1/build/ld LIB_PATH=/usr/lib:/lib
cp -v $BUILD_DIR/binutils-2.31.1/build/ld/ld-new /tools/bin
rm -rf $BUILD_DIR/binutils-2.31.1

step "GCC-8.2.0 - Pass 2"
extract $PACKAGES_DIR/gcc-8.2.0.tar.xz $BUILD_DIR
extract $PACKAGES_DIR/mpfr-4.0.1.tar.xz $BUILD_DIR/gcc-8.2.0
mv -v $BUILD_DIR/gcc-8.2.0/mpfr-4.0.1 $BUILD_DIR/gcc-8.2.0/mpfr
extract $PACKAGES_DIR/gmp-6.1.2.tar.xz $BUILD_DIR/gcc-8.2.0
mv -v $BUILD_DIR/gcc-8.2.0/gmp-6.1.2 $BUILD_DIR/gcc-8.2.0/gmp
extract $PACKAGES_DIR/mpc-1.1.0.tar.gz $BUILD_DIR/gcc-8.2.0
mv -v $BUILD_DIR/gcc-8.2.0/mpc-1.1.0 $BUILD_DIR/gcc-8.2.0/mpc
cat $BUILD_DIR/gcc-8.2.0/gcc/limitx.h $BUILD_DIR/gcc-8.2.0/gcc/glimits.h $BUILD_DIR/gcc-8.2.0/gcc/limity.h > \
`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
for file in $BUILD_DIR/gcc-8.2.0/gcc/config/{linux,i386/linux{,64}}.h
do
cp -uv $file{,.orig}
sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
-e 's@/usr@/tools@g' $file.orig > $file
  echo '
  #undef STANDARD_STARTFILE_PREFIX_1
  #undef STANDARD_STARTFILE_PREFIX_2
  #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
  #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
      -i.orig $BUILD_DIR/gcc-8.2.0/gcc/config/i386/t-linux64
    ;;
esac
mkdir -pv $BUILD_DIR/gcc-8.2.0/build
( cd $BUILD_DIR/gcc-8.2.0/build && \
CC=$LFS_TGT-gcc \
CXX=$LFS_TGT-g++ \
AR=$LFS_TGT-ar \
RANLIB=$LFS_TGT-ranlib \
../configure \
--prefix=/tools \
--with-local-prefix=/tools \
--with-native-system-header-dir=/tools/include \
--enable-languages=c,c++ \
--disable-libstdcxx-pch \
--disable-multilib \
--disable-bootstrap \
--disable-libgomp \
--with-pkgversion="$CONFIG_PKG_VERSION" \
--with-bugurl="$CONFIG_BUG_URL" )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-8.2.0/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-8.2.0/build
ln -sv gcc /tools/bin/cc
rm -rf $BUILD_DIR/gcc-8.2.0

step "Tcl-8.6.8"
extract $PACKAGES_DIR/tcl8.6.8-src.tar.gz $BUILD_DIR
( cd $BUILD_DIR/tcl8.6.8/unix && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/tcl8.6.8/unix
make -j$PARALLEL_JOBS install -C $BUILD_DIR/tcl8.6.8/unix
chmod -v u+w /tools/lib/libtcl8.6.so
make -j$PARALLEL_JOBS install-private-headers -C $BUILD_DIR/tcl8.6.8/unix
ln -sv tclsh8.6 /tools/bin/tclsh
rm -rf $BUILD_DIR/tcl8.6.8

step "Expect-5.45.4"
extract $PACKAGES_DIR/expect5.45.4.tar.gz $BUILD_DIR
cp -v $BUILD_DIR/expect5.45.4/configure{,.orig}
sed 's:/usr/local/bin:/bin:' $BUILD_DIR/expect5.45.4/configure.orig > $BUILD_DIR/expect5.45.4/configure
( cd $BUILD_DIR/expect5.45.4 && \
./configure \
--prefix=/tools \
--with-tcl=/tools/lib \
--with-tclinclude=/tools/include )
make -j$PARALLEL_JOBS -C $BUILD_DIR/expect5.45.4
make -j$PARALLEL_JOBS SCRIPTS="" install -C $BUILD_DIR/expect5.45.4
rm -rf $BUILD_DIR/expect5.45.4

step "DejaGNU-1.6.1"
extract $PACKAGES_DIR/dejagnu-1.6.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/dejagnu-1.6.1 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/dejagnu-1.6.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/dejagnu-1.6.1
rm -rf $BUILD_DIR/dejagnu-1.6.1

step "M4-1.4.18"
extract $PACKAGES_DIR/m4-1.4.18.tar.xz $BUILD_DIR
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' $BUILD_DIR/m4-1.4.18/lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> $BUILD_DIR/m4-1.4.18/lib/stdio-impl.h
( cd $BUILD_DIR/m4-1.4.18 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/m4-1.4.18
make -j$PARALLEL_JOBS install -C $BUILD_DIR/m4-1.4.18
rm -rf $BUILD_DIR/m4-1.4.18

step "Ncurses-6.1"
extract $PACKAGES_DIR/ncurses-6.1.tar.gz $BUILD_DIR
sed -i s/mawk// $BUILD_DIR/ncurses-6.1/configure
( cd $BUILD_DIR/ncurses-6.1 && \
./configure \
--prefix=/tools \
--with-shared \
--without-debug \
--without-ada \
--enable-widec \
--enable-overwrite )
make -j$PARALLEL_JOBS -C $BUILD_DIR/ncurses-6.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/ncurses-6.1
ln -s libncursesw.so /tools/lib/libncurses.so
rm -rf $BUILD_DIR/ncurses-6.1

step "Bash-4.4.18"
extract $PACKAGES_DIR/bash-4.4.18.tar.gz $BUILD_DIR
( cd $BUILD_DIR/bash-4.4.18 && ./configure --prefix=/tools --without-bash-malloc )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bash-4.4.18
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bash-4.4.18
ln -sv bash /tools/bin/sh
rm -rf $BUILD_DIR/bash-4.4.18

step "bison-3.0.5"
extract $PACKAGES_DIR/bison-3.0.5.tar.xz $BUILD_DIR
( cd $BUILD_DIR/bison-3.0.5 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bison-3.0.5
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bison-3.0.5
rm -rf $BUILD_DIR/bison-3.0.5

step "Bzip2-1.0.6"
extract $PACKAGES_DIR/bzip2-1.0.6.tar.gz $BUILD_DIR
make -j$PARALLEL_JOBS -C $BUILD_DIR/bzip2-1.0.6
make -j$PARALLEL_JOBS PREFIX=/tools install -C $BUILD_DIR/bzip2-1.0.6
rm -rf $BUILD_DIR/bzip2-1.0.6

step "Coreutils-8.30"
extract $PACKAGES_DIR/coreutils-8.30.tar.xz $BUILD_DIR
( cd $BUILD_DIR/coreutils-8.30 && ./configure --prefix=/tools --enable-install-program=hostname )
make -j$PARALLEL_JOBS -C $BUILD_DIR/coreutils-8.30
make -j$PARALLEL_JOBS install -C $BUILD_DIR/coreutils-8.30
rm -rf $BUILD_DIR/coreutils-8.30

step "diffutils-3.6"
extract $PACKAGES_DIR/diffutils-3.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/diffutils-3.6 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/diffutils-3.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/diffutils-3.6
rm -rf $BUILD_DIR/diffutils-3.6

step "file-5.34"
extract $PACKAGES_DIR/file-5.34.tar.gz $BUILD_DIR
( cd $BUILD_DIR/file-5.34 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/file-5.34
make -j$PARALLEL_JOBS install -C $BUILD_DIR/file-5.34
rm -rf $BUILD_DIR/file-5.34

step "Findutils-4.6.0"
extract $PACKAGES_DIR/findutils-4.6.0.tar.gz $BUILD_DIR
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' $BUILD_DIR/findutils-4.6.0/gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' $BUILD_DIR/findutils-4.6.0/gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> $BUILD_DIR/findutils-4.6.0/gl/lib/stdio-impl.h
( cd $BUILD_DIR/findutils-4.6.0 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/findutils-4.6.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/findutils-4.6.0
rm -rf $BUILD_DIR/findutils-4.6.0

step "Gawk-4.2.1"
extract $PACKAGES_DIR/gawk-4.2.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gawk-4.2.1 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gawk-4.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gawk-4.2.1
rm -rf $BUILD_DIR/gawk-4.2.1

step "Gettext-0.19.8.1"
extract $PACKAGES_DIR/gettext-0.19.8.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gettext-0.19.8.1/gettext-tools && EMACS="no" ./configure --prefix=/tools --disable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/gnulib-lib
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/intl pluralx.c
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src msgfmt
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src msgmerge
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src xgettext
cp -v $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin
rm -rf $BUILD_DIR/gettext-0.19.8.1

step "grep-3.1"
extract $PACKAGES_DIR/grep-3.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/grep-3.1 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/grep-3.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/grep-3.1
rm -rf $BUILD_DIR/grep-3.1

step "gzip-1.9"
extract $PACKAGES_DIR/gzip-1.9.tar.xz $BUILD_DIR
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' $BUILD_DIR/gzip-1.9/lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> $BUILD_DIR/gzip-1.9/lib/stdio-impl.h
( cd $BUILD_DIR/gzip-1.9 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gzip-1.9
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gzip-1.9
rm -rf $BUILD_DIR/gzip-1.9

step "Make-4.2.1"
extract $PACKAGES_DIR/make-4.2.1.tar.bz2 $BUILD_DIR
sed -i '211,217 d; 219,229 d; 232 d' $BUILD_DIR/make-4.2.1/glob/glob.c
( cd $BUILD_DIR/make-4.2.1 && ./configure --prefix=/tools --without-guile )
make -j$PARALLEL_JOBS -C $BUILD_DIR/make-4.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/make-4.2.1
rm -rf $BUILD_DIR/make-4.2.1

step "Patch-2.7.6"
extract $PACKAGES_DIR/patch-2.7.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/patch-2.7.6 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/patch-2.7.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/patch-2.7.6
rm -rf $BUILD_DIR/patch-2.7.6

step "perl-5.28.0"
extract $PACKAGES_DIR/perl-5.28.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/perl-5.28.0 && sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth )
make -j$PARALLEL_JOBS -C $BUILD_DIR/perl-5.28.0
cp -v $BUILD_DIR/perl-5.28.0/perl $BUILD_DIR/perl-5.28.0/cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.28.0
cp -Rv $BUILD_DIR/perl-5.28.0/lib/* /tools/lib/perl5/5.28.0
rm -rf $BUILD_DIR/perl-5.28.0

step "sed-4.5"
extract $PACKAGES_DIR/sed-4.5.tar.xz $BUILD_DIR
( cd $BUILD_DIR/sed-4.5 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/sed-4.5
make -j$PARALLEL_JOBS install -C $BUILD_DIR/sed-4.5
rm -rf $BUILD_DIR/sed-4.5

step "tar-1.30"
extract $PACKAGES_DIR/tar-1.30.tar.xz $BUILD_DIR
( cd $BUILD_DIR/tar-1.30 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/tar-1.30
make -j$PARALLEL_JOBS install -C $BUILD_DIR/tar-1.30
rm -rf $BUILD_DIR/tar-1.30

step "Texinfo-6.5"
extract $PACKAGES_DIR/texinfo-6.5.tar.xz $BUILD_DIR
( cd $BUILD_DIR/texinfo-6.5 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/texinfo-6.5
make -j$PARALLEL_JOBS install -C $BUILD_DIR/texinfo-6.5
rm -rf $BUILD_DIR/texinfo-6.5

step "Util-linux-2.32.1"
extract $PACKAGES_DIR/util-linux-2.32.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/util-linux-2.32.1 && \
./configure \
--prefix=/tools \
--without-python \
--disable-makeinstall-chown \
--without-systemdsystemunitdir \
--without-ncurses \
PKG_CONFIG="" )
make -j$PARALLEL_JOBS -C $BUILD_DIR/util-linux-2.32.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/util-linux-2.32.1
rm -rf $BUILD_DIR/util-linux-2.32.1

step "Xz-5.2.4"
extract $PACKAGES_DIR/xz-5.2.4.tar.xz $BUILD_DIR
( cd $BUILD_DIR/xz-5.2.4 && ./configure --prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/xz-5.2.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/xz-5.2.4
rm -rf $BUILD_DIR/xz-5.2.4

do_strip

success "\nTotal toolchain build time: $(timer $total_build_time)\n"
