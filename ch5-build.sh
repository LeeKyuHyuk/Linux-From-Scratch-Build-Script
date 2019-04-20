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

rm -rf $TOOLS_DIR $BUILD_DIR
mkdir -pv $TOOLS_DIR $BUILD_DIR
sudo rm -v /tools
sudo ln -svf $TOOLS_DIR /

step "# 5.4. Binutils-2.32 - Pass 1"
extract $SOURCES_DIR/binutils-2.32.tar.xz $BUILD_DIR
mkdir -v $BUILD_DIR/binutils-2.32/build
( cd $BUILD_DIR/binutils-2.32/build && \
$BUILD_DIR/binutils-2.32/configure \
--prefix=/tools \
--with-sysroot=$ROOTFS_DIR \
--with-lib-path=/tools/lib \
--target=$LFS_TGT \
--disable-nls \
--disable-werror )
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.32/build
case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac
make -j$PARALLEL_JOBS install -C $BUILD_DIR/binutils-2.32/build
rm -rf $BUILD_DIR/binutils-2.32

step "# 5.5. gcc-8.2.0 - Pass 1"
extract $SOURCES_DIR/gcc-8.3.0.tar.xz $BUILD_DIR
extract $SOURCES_DIR/mpfr-4.0.2.tar.xz $BUILD_DIR/gcc-8.3.0
mv -v $BUILD_DIR/gcc-8.3.0/mpfr-4.0.2 $BUILD_DIR/gcc-8.3.0/mpfr
extract $SOURCES_DIR/gmp-6.1.2.tar.xz $BUILD_DIR/gcc-8.3.0
mv -v $BUILD_DIR/gcc-8.3.0/gmp-6.1.2 $BUILD_DIR/gcc-8.3.0/gmp
extract $SOURCES_DIR/mpc-1.1.0.tar.gz $BUILD_DIR/gcc-8.3.0
mv -v $BUILD_DIR/gcc-8.3.0/mpc-1.1.0 $BUILD_DIR/gcc-8.3.0/mpc
for file in $BUILD_DIR/gcc-8.3.0/gcc/config/{linux,i386/linux{,64}}.h
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
        -i.orig $BUILD_DIR/gcc-8.3.0/gcc/config/i386/t-linux64
 ;;
esac
mkdir -v $BUILD_DIR/gcc-8.3.0/build
( cd $BUILD_DIR/gcc-8.3.0/build && \
$BUILD_DIR/gcc-8.3.0/configure \
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
--enable-languages=c,c++ )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-8.3.0/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-8.3.0/build
rm -rf $BUILD_DIR/gcc-8.3.0

step "# 5.6. Linux-5.0.4 API Headers"
extract $SOURCES_DIR/linux-5.0.4.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS mrproper -C $BUILD_DIR/linux-5.0.4
make -j$PARALLEL_JOBS INSTALL_HDR_PATH=$BUILD_DIR/linux-5.0.4/dest headers_install -C $BUILD_DIR/linux-5.0.4
cp -rv $BUILD_DIR/linux-5.0.4/dest/include/* /tools/include
rm -rf $BUILD_DIR/linux-5.0.4

step "# 5.7. Glibc-2.29"
extract $SOURCES_DIR/glibc-2.29.tar.xz $BUILD_DIR
mkdir -v $BUILD_DIR/glibc-2.29/build
( cd $BUILD_DIR/glibc-2.29/build && \
$BUILD_DIR/glibc-2.29/configure \
--prefix=/tools \
--host=$LFS_TGT \
--build=$(../scripts/config.guess) \
--enable-kernel=3.2 \
--with-headers=/tools/include )
make -j$PARALLEL_JOBS -C $BUILD_DIR/glibc-2.29/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/glibc-2.29/build
rm -rf $BUILD_DIR/glibc-2.29

step "# 5.8. Libstdc++ from GCC-8.2.0"
extract $SOURCES_DIR/gcc-8.3.0.tar.xz $BUILD_DIR
mkdir -v $BUILD_DIR/gcc-8.3.0/build
( cd $BUILD_DIR/gcc-8.3.0/build && \
$BUILD_DIR/gcc-8.3.0//libstdc++-v3/configure \
--host=$LFS_TGT \
--prefix=/tools \
--disable-multilib \
--disable-nls \
--disable-libstdcxx-threads \
--disable-libstdcxx-pch \
--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.3.0 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-8.3.0/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-8.3.0/build
rm -rf $BUILD_DIR/gcc-8.3.0

step "# 5.9. Binutils-2.32 - Pass 2"
extract $SOURCES_DIR/binutils-2.32.tar.xz $BUILD_DIR
mkdir -v $BUILD_DIR/binutils-2.32/build
( cd $BUILD_DIR/binutils-2.32/build && \
CC=$LFS_TGT-gcc \
AR=$LFS_TGT-ar \
RANLIB=$LFS_TGT-ranlib \
$BUILD_DIR/binutils-2.32/configure \
--prefix=/tools \
--disable-nls \
--disable-werror \
--with-lib-path=/tools/lib \
--with-sysroot )
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.32/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/binutils-2.32/build
make -C $BUILD_DIR/binutils-2.32/build/ld clean
make -C $BUILD_DIR/binutils-2.32/build/ld LIB_PATH=/usr/lib:/lib
cp -v $BUILD_DIR/binutils-2.32/build/ld/ld-new /tools/bin
rm -rf $BUILD_DIR/binutils-2.32

step "# 5.10. gcc-8.2.0 - Pass 2"
extract $SOURCES_DIR/gcc-8.3.0.tar.xz $BUILD_DIR
extract $SOURCES_DIR/mpfr-4.0.2.tar.xz $BUILD_DIR/gcc-8.3.0
mv -v $BUILD_DIR/gcc-8.3.0/mpfr-4.0.2 $BUILD_DIR/gcc-8.3.0/mpfr
extract $SOURCES_DIR/gmp-6.1.2.tar.xz $BUILD_DIR/gcc-8.3.0
mv -v $BUILD_DIR/gcc-8.3.0/gmp-6.1.2 $BUILD_DIR/gcc-8.3.0/gmp
extract $SOURCES_DIR/mpc-1.1.0.tar.gz $BUILD_DIR/gcc-8.3.0
mv -v $BUILD_DIR/gcc-8.3.0/mpc-1.1.0 $BUILD_DIR/gcc-8.3.0/mpc
( cd $BUILD_DIR/gcc-8.3.0 && \
  cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h )
for file in $BUILD_DIR/gcc-8.3.0/gcc/config/{linux,i386/linux{,64}}.h
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
        -i.orig $BUILD_DIR/gcc-8.3.0/gcc/config/i386/t-linux64
  ;;
esac
mkdir -v $BUILD_DIR/gcc-8.3.0/build
( cd $BUILD_DIR/gcc-8.3.0/build && \
CC=$LFS_TGT-gcc \
CXX=$LFS_TGT-g++ \
AR=$LFS_TGT-ar \
RANLIB=$LFS_TGT-ranlib \
$BUILD_DIR/gcc-8.3.0/configure \
--prefix=/tools \
--with-local-prefix=/tools \
--with-native-system-header-dir=/tools/include \
--enable-languages=c,c++ \
--disable-libstdcxx-pch \
--disable-multilib \
--disable-bootstrap \
--disable-libgomp )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-8.3.0/build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-8.3.0/build
ln -sv gcc /tools/bin/cc
rm -rf $BUILD_DIR/gcc-8.3.0

step "# 5.11. Tcl-8.6.9"
extract $SOURCES_DIR/tcl8.6.9-src.tar.gz $BUILD_DIR
( cd $BUILD_DIR/tcl8.6.9/unix && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/tcl8.6.9/unix
make -j$PARALLEL_JOBS install -C $BUILD_DIR/tcl8.6.9/unix
chmod -v u+w /tools/lib/libtcl8.6.so
make -j$PARALLEL_JOBS install-private-headers -C $BUILD_DIR/tcl8.6.9/unix
ln -sv tclsh8.6 /tools/bin/tclsh
rm -rf $BUILD_DIR/tcl8.6.9

step "# 5.12. Expect-5.45.4"
extract $SOURCES_DIR/expect5.45.4.tar.gz $BUILD_DIR
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

step "# 5.13. DejaGNU-1.6.2"
extract $SOURCES_DIR/dejagnu-1.6.2.tar.gz $BUILD_DIR
( cd $BUILD_DIR/dejagnu-1.6.2 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/dejagnu-1.6.2
make -j$PARALLEL_JOBS install -C $BUILD_DIR/dejagnu-1.6.2
rm -rf $BUILD_DIR/dejagnu-1.6.2

step "# 5.14. M4-1.4.18"
extract $SOURCES_DIR/m4-1.4.18.tar.xz $BUILD_DIR
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' $BUILD_DIR/m4-1.4.18/lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> $BUILD_DIR/m4-1.4.18/lib/stdio-impl.h
( cd $BUILD_DIR/m4-1.4.18 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/m4-1.4.18
make -j$PARALLEL_JOBS install -C $BUILD_DIR/m4-1.4.18
rm -rf $BUILD_DIR/m4-1.4.18

step "# 5.15. Ncurses-6.1"
extract $SOURCES_DIR/ncurses-6.1.tar.gz $BUILD_DIR
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

step "# 5.16. Bash-5.0"
extract $SOURCES_DIR/bash-5.0.tar.gz $BUILD_DIR
( cd $BUILD_DIR/bash-5.0 && \
./configure \
--prefix=/tools \
--without-bash-malloc )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bash-5.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bash-5.0
ln -sv bash /tools/bin/sh
rm -rf $BUILD_DIR/bash-5.0

step "# 5.17. Bison-3.3.2"
extract $SOURCES_DIR/bison-3.3.2.tar.xz $BUILD_DIR
( cd $BUILD_DIR/bison-3.3.2 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bison-3.3.2
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bison-3.3.2
rm -rf $BUILD_DIR/bison-3.3.2

step "# 5.18. Bzip2-1.0.6"
extract $SOURCES_DIR/bzip2-1.0.6.tar.gz $BUILD_DIR
make -j$PARALLEL_JOBS -C $BUILD_DIR/bzip2-1.0.6
make -j$PARALLEL_JOBS PREFIX=/tools install -C $BUILD_DIR/bzip2-1.0.6
rm -rf $BUILD_DIR/bzip2-1.0.6

step "# 5.19. Coreutils-8.31"
extract $SOURCES_DIR/coreutils-8.31.tar.xz $BUILD_DIR
( cd $BUILD_DIR/coreutils-8.31 && \
./configure \
--prefix=/tools \
--enable-install-program=hostname )
make -j$PARALLEL_JOBS -C $BUILD_DIR/coreutils-8.31
make -j$PARALLEL_JOBS install -C $BUILD_DIR/coreutils-8.31
rm -rf $BUILD_DIR/coreutils-8.31

step "# 5.20. Diffutils-3.7"
extract $SOURCES_DIR/diffutils-3.7.tar.xz $BUILD_DIR
( cd $BUILD_DIR/diffutils-3.7 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/diffutils-3.7
make -j$PARALLEL_JOBS install -C $BUILD_DIR/diffutils-3.7
rm -rf $BUILD_DIR/diffutils-3.7

step "# 5.21. File-5.36"
extract $SOURCES_DIR/file-5.36.tar.gz $BUILD_DIR
( cd $BUILD_DIR/file-5.36 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/file-5.36
make -j$PARALLEL_JOBS install -C $BUILD_DIR/file-5.36
rm -rf $BUILD_DIR/file-5.36

step "# 5.22. Findutils-4.6.0"
extract $SOURCES_DIR/findutils-4.6.0.tar.gz $BUILD_DIR
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' $BUILD_DIR/findutils-4.6.0/gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' $BUILD_DIR/findutils-4.6.0/gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> $BUILD_DIR/findutils-4.6.0/gl/lib/stdio-impl.h
( cd $BUILD_DIR/findutils-4.6.0 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/findutils-4.6.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/findutils-4.6.0
rm -rf $BUILD_DIR/findutils-4.6.0

step "# 5.23. Gawk-4.2.1"
extract $SOURCES_DIR/gawk-4.2.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gawk-4.2.1 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gawk-4.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gawk-4.2.1
rm -rf $BUILD_DIR/gawk-4.2.1

step "# 5.24. Gettext-0.19.8.1"
extract $SOURCES_DIR/gettext-0.19.8.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gettext-0.19.8.1/gettext-tools && \
EMACS="no" \
./configure \
--prefix=/tools \
--disable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/gnulib-lib
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/intl pluralx.c
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src msgfmt
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src msgmerge
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src xgettext
cp -v $BUILD_DIR/gettext-0.19.8.1/gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin
rm -rf $BUILD_DIR/gettext-0.19.8.1

step "# 5.25. Grep-3.3"
extract $SOURCES_DIR/grep-3.3.tar.xz $BUILD_DIR
( cd $BUILD_DIR/grep-3.3 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/grep-3.3
make -j$PARALLEL_JOBS install -C $BUILD_DIR/grep-3.3
rm -rf $BUILD_DIR/grep-3.3

step "# 5.26. Gzip-1.10"
extract $SOURCES_DIR/gzip-1.10.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gzip-1.10 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gzip-1.10
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gzip-1.10
rm -rf $BUILD_DIR/gzip-1.10

step "# 5.27. Make-4.2.1"
extract $SOURCES_DIR/make-4.2.1.tar.bz2 $BUILD_DIR
sed -i '211,217 d; 219,229 d; 232 d' $BUILD_DIR/make-4.2.1/glob/glob.c
( cd $BUILD_DIR/make-4.2.1 && \
./configure \
--prefix=/tools \
--without-guile )
make -j$PARALLEL_JOBS -C $BUILD_DIR/make-4.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/make-4.2.1
rm -rf $BUILD_DIR/make-4.2.1

step "# 5.28. Patch-2.7.6"
extract $SOURCES_DIR/patch-2.7.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/patch-2.7.6 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/patch-2.7.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/patch-2.7.6
rm -rf $BUILD_DIR/patch-2.7.6

step "# 5.29. Perl-5.28.1"
extract $SOURCES_DIR/perl-5.28.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/perl-5.28.1 && \
sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth )
make -j$PARALLEL_JOBS -C $BUILD_DIR/perl-5.28.1
cp -v $BUILD_DIR/perl-5.28.1/perl $BUILD_DIR/perl-5.28.1/cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.28.1
cp -Rv $BUILD_DIR/perl-5.28.1/lib/* /tools/lib/perl5/5.28.1
rm -rf $BUILD_DIR/perl-5.28.1

step "# 5.30. Python-3.7.3"
extract $SOURCES_DIR/Python-3.7.3.tar.xz $BUILD_DIR
sed -i '/def add_multiarch_paths/a \        return' $BUILD_DIR/Python-3.7.3/setup.py
( cd $BUILD_DIR/Python-3.7.3 && \
./configure \
--prefix=/tools \
--without-ensurepip )
make -j$PARALLEL_JOBS -C $BUILD_DIR/Python-3.7.3
make -j$PARALLEL_JOBS install -C $BUILD_DIR/Python-3.7.3
rm -rf $BUILD_DIR/Python-3.7.3

step "# 5.31. Sed-4.7"
extract $SOURCES_DIR/sed-4.7.tar.xz $BUILD_DIR
( cd $BUILD_DIR/sed-4.7 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/sed-4.7
make -j$PARALLEL_JOBS install -C $BUILD_DIR/sed-4.7
rm -rf $BUILD_DIR/sed-4.7

step "# 5.32. Tar-1.32"
extract $SOURCES_DIR/tar-1.32.tar.xz $BUILD_DIR
( cd $BUILD_DIR/tar-1.32 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/tar-1.32
make -j$PARALLEL_JOBS install -C $BUILD_DIR/tar-1.32
rm -rf $BUILD_DIR/tar-1.32

step "# 5.33. Texinfo-6.6"
extract $SOURCES_DIR/texinfo-6.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/texinfo-6.6 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/texinfo-6.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/texinfo-6.6
rm -rf $BUILD_DIR/texinfo-6.6

step "# 5.34. Util-linux-2.33.1"
extract $SOURCES_DIR/util-linux-2.33.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/util-linux-2.33.1 && \
./configure \
--prefix=/tools \
--without-python \
--disable-makeinstall-chown \
--without-systemdsystemunitdir \
--without-ncurses \
PKG_CONFIG="" )
make -j$PARALLEL_JOBS -C $BUILD_DIR/util-linux-2.33.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/util-linux-2.33.1
rm -rf $BUILD_DIR/util-linux-2.33.1

step "# 5.35. Xz-5.2.4"
extract $SOURCES_DIR/xz-5.2.4.tar.xz $BUILD_DIR
( cd $BUILD_DIR/xz-5.2.4 && \
./configure \
--prefix=/tools )
make -j$PARALLEL_JOBS -C $BUILD_DIR/xz-5.2.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/xz-5.2.4
rm -rf $BUILD_DIR/xz-5.2.4

do_strip

echo -e "----------------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 5!"
printf 'Total script time: %s\n' $(timer $total_time)
echo -e "Now continue reading from \"5.36. Changing Ownership\""
