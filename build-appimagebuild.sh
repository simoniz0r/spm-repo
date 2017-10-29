#!/bin/bash -e
# Title: spm
# Description: Downloads and installs AppImages and precompiled tar archives.  Can also upgrade and remove installed packages.
# Dependencies: GNU coreutils, tar, wget
# Author: simonizor
# Website: http://www.simonizor.gq
# License: GPL v2.0 only
# Script for building releases of spm

BUILD_DIR="/media/simonizor/0d208b29-3b29-4ffc-99be-1043b9f3c258/github/spm_repo"
VERSION="0.0.1"
mkdir -p "$BUILD_DIR"/deps/extracted
mkdir "$BUILD_DIR"/appimagebuild.AppDir

wget "http://ftp.us.debian.org/debian/pool/main/b/bc/bc_1.06.95-9_amd64.deb" -O "$BUILD_DIR"/deps/bc.deb
wget "http://ftp.us.debian.org/debian/pool/main/w/wget/wget_1.16-1+deb8u2_amd64.deb" -O "$BUILD_DIR"/deps/wget.deb
wget "http://ftp.us.debian.org/debian/pool/main/g/gnutls28/libgnutls-deb0-28_3.3.8-6+deb8u7_amd64.deb" -O "$BUILD_DIR"/deps/libgnutls.deb
wget "http://ftp.us.debian.org/debian/pool/main/n/nettle/libnettle4_2.7.1-5+deb8u2_amd64.deb" -O "$BUILD_DIR"/deps/libnettle.deb
wget "http://ftp.us.debian.org/debian/pool/main/libp/libpsl/libpsl0_0.5.1-1_amd64.deb" -O "$BUILD_DIR"/deps/libpsl.deb
wget "http://ftp.us.debian.org/debian/pool/main/i/icu/libicu52_52.1-8+deb8u5_amd64.deb" -O "$BUILD_DIR"/deps/libicu.deb
wget "http://ftp.us.debian.org/debian/pool/main/n/nettle/libhogweed2_2.7.1-5+deb8u2_amd64.deb" -O "$BUILD_DIR"/deps/libhogweed.deb
wget "http://ftp.us.debian.org/debian/pool/main/g/gcc-4.9/libstdc++6_4.9.2-10_amd64.deb" -O "$BUILD_DIR"/deps/libstdc++.deb
wget "http://ftp.us.debian.org/debian/pool/main/g/gmp/libgmp10_6.0.0+dfsg-6_amd64.deb" -O "$BUILD_DIR"/deps/libgmp.deb
#### These dependencies are for the aibs_testing branch
wget "http://ftp.us.debian.org/debian/pool/main/b/binutils/binutils_2.25-5+deb8u1_amd64.deb" -O "$BUILD_DIR"/deps/binutils.deb
wget "http://ftp.us.debian.org/debian/pool/main/g/git/git_2.11.0-3~bpo8+1_amd64.deb" -O "$BUILD_DIR"/deps/git.deb
wget "http://security.debian.org/debian-security/pool/updates/main/g/git/git_2.1.4-2.1+deb8u5_amd64.deb" -O "$BUILD_DIR"/deps/git-man.deb
wget "http://ftp.us.debian.org/debian/pool/main/c/curl/libcurl3-gnutls_7.38.0-4+deb8u5_amd64.deb" -O "$BUILD_DIR"/deps/libcurl3-gnutls.deb
wget "http://ftp.us.debian.org/debian/pool/main/libe/liberror-perl/liberror-perl_0.17-1.1_all.deb" -O "$BUILD_DIR"/deps/liberror-perl.deb
wget "http://ftp.us.debian.org/debian/pool/main/r/rtmpdump/librtmp1_2.4+20150115.gita107cef-1+deb8u1_amd64.deb" -O "$BUILD_DIR"/deps/librtmp.deb

cd "$BUILD_DIR"/deps/extracted
debextractfunc () {
    ar x "$BUILD_DIR"/deps/"$1"
    rm -f "$BUILD_DIR"/deps/extracted/control.tar.gz
    rm -f "$BUILD_DIR"/deps/extracted/debian-binary
    tar -xf "$BUILD_DIR"/deps/extracted/data.tar.* -C "$BUILD_DIR"/deps/extracted/
    rm -f "$BUILD_DIR"/deps/extracted/data.tar.*
    if [ -f "$BUILD_DIR"/deps/extracted/usr/share/doc/git/contrib/subtree/COPYING ]; then
        rm "$BUILD_DIR"/deps/extracted/usr/share/doc/git/contrib/subtree/COPYING
    fi
    if [ -f "$BUILD_DIR"/deps/extracted/usr/share/doc/git/contrib/persistent-https/LICENSE ]; then
        rm "$BUILD_DIR"/deps/extracted/usr/share/doc/git/contrib/persistent-https/LICENSE
    fi
    cp -r "$BUILD_DIR"/deps/extracted/* "$BUILD_DIR"/appimagebuild.AppDir/
    rm -rf "$BUILD_DIR"/deps/extracted/*
}

debextractfunc "bc.deb"
debextractfunc "wget.deb"
debextractfunc "libgnutls.deb"
debextractfunc "libnettle.deb"
debextractfunc "libpsl.deb"
debextractfunc "libicu.deb"
debextractfunc "libhogweed.deb"
debextractfunc "libstdc++.deb"
debextractfunc "libgmp.deb"
#### These dependencies are for the aibs_testing branch
debextractfunc "binutils.deb"
debextractfunc "git.deb"
debextractfunc "git-man.deb"
debextractfunc "libcurl3-gnutls.deb"
debextractfunc "liberror-perl.deb"
debextractfunc "librtmp.deb"
rm -rf "$BUILD_DIR"/deps

mkdir -p "$BUILD_DIR"/appimagebuild.AppDir/usr/share/appimagebuild
mkdir -p "$BUILD_DIR"/appimagebuild.AppDir/usr/bin
#### This script is for the aibs_testing branch
cp ~/github/spm/appimagebuild.sh "$BUILD_DIR"/appimagebuild.AppDir/usr/bin/appimagebuild
cp ~/github/spm/LICENSE "$BUILD_DIR"/appimagebuild.AppDir/usr/share/appimagebuild/
cp ~/github/spm/jq "$BUILD_DIR"/appimagebuild.AppDir/usr/bin/
cp ~/github/spm/yaml "$BUILD_DIR"/appimagebuild.AppDir/usr/bin/
cp ~/github/spm/spm.png "$BUILD_DIR"/appimagebuild.AppDir/appimagebuild.png
cat >"$BUILD_DIR"/appimagebuild.AppDir/appimagebuild.desktop << EOL
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=appimagebuild
Comment=Builds AppImages using AppImage Build Scripts
Exec=appimagebuild
Icon=appimagebuild
Categories=Utility;
Terminal=true

EOL

wget "https://github.com/darealshinji/AppImageKit-checkrt/releases/download/continuous/AppRun-patched-x86_64" -O "$BUILD_DIR"/appimagebuild.AppDir/AppRun
chmod a+x "$BUILD_DIR"/appimagebuild.AppDir/AppRun

appimagetool "$BUILD_DIR"/appimagebuild.AppDir "$BUILD_DIR"/appimagebuild-"$VERSION"-x86_64.AppImage || exit 1
rm -rf "$BUILD_DIR"/appimagebuild.AppDir
exit 0
