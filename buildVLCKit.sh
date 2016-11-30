#!/bin/sh
# Copyright (C) Pierre d'Herbemont, 2010
# Copyright (C) Felix Paul Kühne, 2012-2016

set -e

SDK=`xcrun --sdk macosx --show-sdk-version`
SDK_MIN=10.7
VERBOSE=no
CONFIGURATION="Release"
NONETWORK=no
SKIPLIBVLCCOMPILATION=no
SCARY=yes

CORE_COUNT=`sysctl -n machdep.cpu.core_count`
let MAKE_JOBS=$CORE_COUNT+1

usage()
{
cat << EOF
usage: $0 [-s] [-v] [-k sdk]

OPTIONS
   -k       Specify which sdk to use (see 'xcodebuild -showsdks', current: ${SDK})
   -v       Be more verbose
   -d       Enable Debug
   -n       Skip script steps requiring network interaction
   -l       Skip libvlc compilation
   -w       Build a limited stack of non-scary libraries only
EOF
}

spushd()
{
     pushd "$1" 2>&1> /dev/null
}

spopd()
{
     popd 2>&1> /dev/null
}

info()
{
     local green="\033[1;32m"
     local normal="\033[0m"
     echo "[${green}info${normal}] $1"
}

buildxcodeproj()
{
    local target="$2"
    local PLATFORM="$3"

    info "Building $1 ($target, ${CONFIGURATION}, $PLATFORM)"

    local architectures="x86_64"

    local defs="$GCC_PREPROCESSOR_DEFINITIONS"
    if [ "$SCARY" = "no" ]; then
        defs="$defs NOSCARYCODECS"
    fi
    xcodebuild -project "$1.xcodeproj" \
               -target "$target" \
               -sdk $PLATFORM$SDK \
               -configuration ${CONFIGURATION} \
               ARCHS="${architectures}" \
               MACOSX_DEPLOYMENT_TARGET=${SDK_MIN} \
               GCC_PREPROCESSOR_DEFINITIONS="$defs" \
               > ${out}
}

while getopts "hvwsfbdntlk:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         d)  CONFIGURATION="Debug"
             ;;
         w)  SCARY="no"
             ;;
         n)
             NONETWORK=yes
             ;;
         l)
             SKIPLIBVLCCOMPILATION=yes
             ;;
         k)
             SDK=$OPTARG
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done
shift $(($OPTIND - 1))

out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

if [ "x$1" != "x" ]; then
    usage
    exit 1
fi

# Get root dir
spushd .
aspen_root_dir=`pwd`
spopd

info "Preparing build dirs"

mkdir -p libvlc

spushd libvlc

if [ "$NONETWORK" != "yes" ]; then
if ! [ -e vlc ]; then
git clone git://git.videolan.org/vlc.git vlc
else
cd vlc
git pull --rebase
cd ..
fi
fi

spopd

#
# Build time
#

buildLibVLC() {
    args=""
    if [ "$VERBOSE" = "yes" ]; then
        args="${args} V=1"
    fi

    spushd libvlc
    spushd vlc

    VLCROOT=`pwd` # Let's make sure VLCROOT is an absolute path
    PREFIX="${VLCROOT}/install-macos"

    if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
    
    export PATH="${VLCROOT}/extras/tools/build/bin:${VLCROOT}/contrib/x86_64-apple-darwin15/bin:$PATH"
    
    info "Building tools"
    spushd extras/tools
    ./bootstrap
    make -j$MAKE_JOBS ${args}
    spopd # extras/tools

    info "Building contrib"
    spushd contrib
    mkdir -p vlckitbuild
    spushd vlckitbuild
    ../bootstrap --build=x86_64-apple-darwin15 --disable-bluray --disable-growl --disable-sparkle --disable-SDL --disable-SDL_image --disable-microdns --disable-fontconfig --disable-bghudappkit
    make -j$MAKE_JOBS fetch ${args}
    make .gettext ${args}
    make -j$MAKE_JOBS ${args}
    spopd # vlckitbuild
    spopd # contrib

    info "Bootstraping vlc"
    info "VLCROOT = ${VLCROOT}"
    if ! [ -e ${VLCROOT}/configure ]; then
        ${VLCROOT}/bootstrap
    fi

    mkdir -p vlckitbuild

    spushd vlckitbuild
    ../extras/package/macosx/configure.sh --build=x86_64-apple-darwin15 --prefix="${PREFIX}" --disable-macosx-vlc-app --disable-macosx --enable-merge-ffmpeg --disable-sparkle
    make -j$MAKE_JOBS ${args}
    make install $(args)    
    spopd #vlckitbuild

fi

    spopd #vlc
    spopd #libvlc
    
}

buildLibVLC

info "libvlc compilation done"

info "Building VLCKit.framework"

buildxcodeproj VLCKit "VLCKit" macosx

info "Build of VLCKit.framework completed"
