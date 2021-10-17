#!/bin/sh
# Copyright (C) Pierre d'Herbemont, 2010
# Copyright (C) Felix Paul Kühne, 2012-2021

set -e

BUILD_DEVICE=yes
BUILD_SIMULATOR=yes
BUILD_DYNAMIC_FRAMEWORK=no
BUILD_ARCH=`uname -m | cut -d. -f1`
SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`
SDK_MIN=8.4
VERBOSE=no
DEBUG=no
CONFIGURATION="Release"
NONETWORK=no
SKIPLIBVLCCOMPILATION=no
SCARY=yes
TVOS=no
MACOS=no
IOS=yes
BITCODE=no
OSVERSIONMINCFLAG=mios
OSVERSIONMINLDFLAG=ios
ROOT_DIR=empty
FARCH="all"

TESTEDHASH="1f870b73e0" # libvlc hash that this version of VLCKit is build on

if [ -z "$MAKE_JOBS" ]; then
    CORE_COUNT=`sysctl -n machdep.cpu.core_count`
    let MAKE_JOBS=$CORE_COUNT+1
fi

usage()
{
cat << EOF
usage: $0 [-s] [-v] [-k sdk]

OPTIONS
   -k       Specify which sdk to use (see 'xcodebuild -showsdks', current: ${SDK})
   -v       Be more verbose
   -s       Build for simulator
   -f       Build framework for device and simulator
   -d       Enable Debug
   -n       Skip script steps requiring network interaction
   -l       Skip libvlc compilation
   -t       Build for tvOS
   -x       Build for macOS / Mac OS X
   -w       Build a limited stack of non-scary libraries only
   -y       Build universal static libraries
   -b       Enable bitcode
   -a       Build framework for specific arch (all|i386|x86_64|armv7|armv7s|aarch64)
EOF
}

while getopts "hvwsfbdxntlk:a:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         s)
             BUILD_DEVICE=no
             BUILD_SIMULATOR=yes
             BUILD_DYNAMIC_FRAMEWORK=no
             ;;
         f)
             BUILD_DEVICE=yes
             BUILD_SIMULATOR=yes
             BUILD_DYNAMIC_FRAMEWORK=yes
             ;;
         d)  CONFIGURATION="Debug"
             DEBUG=yes
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
         a)
             BUILD_DEVICE=yes
             BUILD_SIMULATOR=yes
             BUILD_DYNAMIC_FRAMEWORK=yes
             FARCH=$OPTARG
             ;;
         b)
             BITCODE=yes
             ;;
         t)
             TVOS=yes
             IOS=no
             BITCODE=yes
             SDK_VERSION=`xcrun --sdk appletvos --show-sdk-version`
             SDK_MIN=10.2
             OSVERSIONMINCFLAG=mtvos
             OSVERSIONMINLDFLAG=tvos
             ;;
         x)
             MACOS=yes
             IOS=no
             BITCODE=no
             SDK_VERSION=`xcrun --sdk macosx --show-sdk-version`
             SDK_MIN=10.9
             OSVERSIONMINCFLAG=mmacosx
             OSVERSIONMINLDFLAG=macosx
             BUILD_DEVICE=yes
             BUILD_DYNAMIC_FRAMEWORK=yes
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

get_actual_arch() {
    if [ "$1" = "aarch64" ]; then
        echo "arm64"
    else
        echo "$1"
    fi
}

get_arch() {
    if [ "$1" = "arm64" ]; then
        echo "aarch64"
    else
        echo "$1"
    fi
}

is_simulator_arch() {
    if [ "$1" = "i386" -o "$1" = "x86_64" ];then
        return 0
    else
        return 1
    fi
}

get_buildsystem_arch() {
    if [ "$1" = "arm64" ]; then
        echo "aarch64"
    else
        echo "$1"
    fi
}

vlcGetOSXKernelVersion() {
    local OSX_KERNELVERSION=$(uname -r | cut -d. -f1)
    if [ ! -z "$VLC_FORCE_KERNELVERSION" ]; then
        OSX_KERNELVERSION="$VLC_FORCE_KERNELVERSION"
    fi

    echo "$OSX_KERNELVERSION"
}

vlcGetBuildTriplet() {
    echo "$BUILD_ARCH-apple-darwin$(vlcGetOSXKernelVersion)"
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

cleantheenvironment()
{
    export CC=""
    export CFLAGS=""
    export CPPFLAGS=""
    export CXX=""
    export CXXFLAGS=""
    export CXXCPPFLAGS=""
    export OBJC=""
    export OBJCFLAGS=""
    export LD=""
    export LDFLAGS=""
    export STRIP=""
    export PKG_CONFIG_PATH=""
}

buildxcodeproj()
{
    cleantheenvironment

    local target="$2"
    local PLATFORM="$3"

    info "Building $1 ($target, ${CONFIGURATION}, $PLATFORM)"

    local architectures=""
    if [ "$FARCH" = "all" ];then
        if [ "$TVOS" = "yes" ]; then
            if [ "$PLATFORM" = "appletvsimulator" ]; then
                architectures="x86_64 arm64"
            else
                architectures="arm64"
            fi
        fi
        if [ "$IOS" = "yes" ]; then
            if [ "$PLATFORM" = "iphonesimulator" ]; then
                architectures="i386 x86_64 arm64"
            else
                architectures="armv7 armv7s arm64"
            fi
        fi
        if [ "$MACOS" = "yes" ]; then
            architectures="x86_64 arm64"
        fi
    else
        architectures=`get_actual_arch $FARCH`
    fi

    local bitcodeflag=""
    if [ "$IOS" = "yes" ]; then
    if [ "$BITCODE" = "yes" ]; then
        info "Bitcode enabled"
        bitcodeflag="BITCODE_GENERATION_MODE=bitcode"
    else
        info "Bitcode disabled"
        bitcodeflag="BITCODE_GENERATION_MODE=none ENABLE_BITCODE=no"
    fi
    fi
    if [ "$TVOS" = "yes" ]; then
    if [ "$BITCODE" = "yes" ]; then
        bitcodeflag="BITCODE_GENERATION_MODE=bitcode"
    fi
    fi

    if [ "$SCARY" = "no" ]; then
        defs="$defs NOSCARYCODECS"
    fi

    xcodebuild archive \
               -project "$1.xcodeproj" \
               -sdk $PLATFORM$SDK \
               -configuration ${CONFIGURATION} \
               -scheme "$target" \
               -archivePath build/"$target"-$PLATFORM$SDK.xcarchive \
               ARCHS="${architectures}" \
               IPHONEOS_DEPLOYMENT_TARGET=${SDK_MIN} \
               ${bitcodeflag} \
               SKIP_INSTALL=no \
               > ${out}
}

# Get root dir
spushd .
ROOT_DIR=`pwd`
spopd

# get python installation
python3Path=$(echo /Library/Frameworks/Python.framework/Versions/3.*/bin | awk '{print $1;}')
if [ ! -d "$python3Path" ]; then
    python3Path=""
fi

VLCROOT=${ROOT_DIR}/libvlc/vlc
export PATH="$python3Path:${VLCROOT}/extras/tools/build/bin:${VLCROOT}/contrib/${HOST_TRIPLET}/bin:${VLC_PATH}:/usr/bin:/bin:/usr/sbin:/sbin"
BUILD_ARCH=`get_buildsystem_arch $BUILD_ARCH`

info "Preparing build dirs"

mkdir -p libvlc

spushd libvlc

echo `pwd`

if [ "$NONETWORK" != "yes" ]; then
    if ! [ -e vlc ]; then
        git clone https://code.videolan.org/videolan/vlc.git --branch 3.0.x --single-branch vlc
        info "Applying patches to vlc.git"
        cd vlc
        git checkout -B localBranch ${TESTEDHASH}
        git branch --set-upstream-to=3.0.x localBranch
        git am ${ROOT_DIR}/Resources/MobileVLCKit/patches/*.patch
        if [ $? -ne 0 ]; then
            git am --abort
            info "Applying the patches failed, aborting git-am"
            exit 1
        fi
        cd ..
    else
        cd vlc
        git fetch --all
        git reset --hard ${TESTEDHASH}
        git am ${ROOT_DIR}/Resources/MobileVLCKit/patches/*.patch
        cd ..
    fi
fi

spopd

#
# Build time
#

out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
    info "Building tools"
    spushd ${ROOT_DIR}/libvlc/vlc/extras/tools
    ./bootstrap
    make
    make .buildgas
    spopd #libvlc/vlc/extras/tools
fi

buildLibVLC() {
    ARCH="$1"
    PLATFORM="$2"
    OSSTYLE=iPhone

    if [ "$DEBUG" = "yes" ]; then
        OPTIM="-O0"
    else
        OPTIM="-O3"
    fi

    if [ "$TVOS" = "yes" ]; then
        OSSTYLE=AppleTV
    fi
    if [ "$MACOS" = "yes" ]; then
        OSSTYLE=MacOSX
        PLATFORM=
    fi

    ACTUAL_ARCH=`get_actual_arch $ARCH`

    info "Compiling ${ARCH} (${ACTUAL_ARCH}) with SDK version ${SDK_VERSION}, platform ${PLATFORM}"

    SDKROOT=`xcode-select -print-path`/Platforms/${OSSTYLE}${PLATFORM}.platform/Developer/SDKs/${OSSTYLE}${PLATFORM}${SDK_VERSION}.sdk

    if [ ! -d "${SDKROOT}" ]
    then
        echo "*** ${SDKROOT} does not exist, please install required SDK, or set SDKROOT manually. ***"
        exit 1
    fi

    # we need an identifier here to differenciate the flat from the fat binary folders
    local PLATFORM_IDENTIFIER=$PLATFORM
    if [ "$MACOS" = "yes" ]; then
        PLATFORM_IDENTIFIER="OS"
    fi

    BUILDDIR="${VLCROOT}/build-${OSSTYLE}${PLATFORM_IDENTIFIER}/${ACTUAL_ARCH}"
    PREFIX="${VLCROOT}/install-${OSSTYLE}${PLATFORM_IDENTIFIER}/${ACTUAL_ARCH}"
    # We create an unversioned host triplet here, because otherwise compilations for the same
    # architecture but different operating systems will make autoconf believe that we are not
    # actually crosscompiling (as the triplet would be the same for iPhone and Mac with ARM-64)
    HOST_TRIPLET="${ARCH}-apple-darwin"

    export PLATFORM=$PLATFORM
    export SDK_VERSION=$SDK_VERSION
    export VLCSDKROOT=$SDKROOT

    EXTRA_CFLAGS="-isysroot ${SDKROOT}"
    EXTRA_LDFLAGS="-arch ${ACTUAL_ARCH}"

    if [ "$PLATFORM" = "OS" ]; then
    if [ "$ARCH" != "aarch64" ]; then
    EXTRA_CFLAGS+=" -mcpu=cortex-a8 -${OSVERSIONMINCFLAG}-version-min=${SDK_MIN}"
    else
    EXTRA_CFLAGS+=" -${OSVERSIONMINCFLAG}-version-min=${SDK_MIN}"
    fi
    else
    if [ "$MACOS" = "yes" ]; then
    EXTRA_CFLAGS+=" -${OSVERSIONMINCFLAG}-version-min=${SDK_MIN}"
    else
    EXTRA_CFLAGS+=" -${OSVERSIONMINCFLAG}-simulator-version-min=${SDK_MIN}"
    fi
    fi

    if [ "$BITCODE" = "yes" ]; then
    EXTRA_CFLAGS+=" -fembed-bitcode"
    fi

    if [ "$PLATFORM" = "Simulator" ]; then
        # Use the new ABI on simulator, else we can't build
        export OBJCFLAGS="-fobjc-abi-version=2 -fobjc-legacy-dispatch ${OBJCFLAGS}"
    fi

    if [ "$PLATFORM" = "Simulator" ]; then
        EXTRA_CFLAGS+=" -arch ${ACTUAL_ARCH}"
        EXTRA_LDFLAGS+=" -Wl,-${OSVERSIONMINLDFLAG}_simulator_version_min,${SDK_MIN}"
    else
        EXTRA_CFLAGS+=" -arch ${ACTUAL_ARCH}"
        EXTRA_LDFLAGS+=" -Wl,-${OSVERSIONMINLDFLAG}_version_min,${SDK_MIN}"
    fi

    export CFLAGS="${EXTRA_CFLAGS}"
    export CPPFLAGS="${EXTRA_CFLAGS}"
    export CXXFLAGS="${EXTRA_CFLAGS}"
    export OBJCFLAGS="${EXTRA_CFLAGS}"
    export LDFLAGS="${EXTRA_LDFLAGS}"

    spushd ${VLCROOT}/contrib

    info "Compiling third-party libraries"

    mkdir -p "${VLCROOT}/contrib/${OSSTYLE}${PLATFORM}-${ARCH}"
    cd "${VLCROOT}/contrib/${OSSTYLE}${PLATFORM}-${ARCH}"

    if [ "$PLATFORM" = "OS" ]; then
        export AS="gas-preprocessor.pl ${CC}"
        export ASCPP="gas-preprocessor.pl ${CC}"
        export CCAS="gas-preprocessor.pl ${CC}"
        if [ "$ARCH" = "aarch64" ]; then
            export GASPP_FIX_XCODE5=1
        fi
    fi

    if [ "$TVOS" = "yes" ]; then
        CUSTOMOSOPTIONS="--disable-libarchive"
    fi
    if [ "$MACOS" = "yes" ]; then
        CUSTOMOSOPTIONS="--disable-fontconfig --disable-bghudappkit --disable-twolame --disable-microdns --disable-SDL --disable-SDL_image --disable-cddb --disable-bluray"
    fi
    if [ "$IOS" = "yes" ]; then
        CUSTOMOSOPTIONS=""
    fi

    BUILD_TRIPLET=$(vlcGetBuildTriplet)

    if [ "$MACOS" = "yes" ]; then
        # The following symbols do not exist on the minimal macOS version (10.7), so they are disabled
        # here. This allows compilation also with newer macOS SDKs.
        # Added in 10.15

        # Added symbols between 10.7 and 10.11
        export ac_cv_func_ffsll=no
        export ac_cv_func_flsll=no
        export ac_cv_func_fdopendir=no
        export ac_cv_func_openat=no
        export ac_cv_func_fstatat=no
        export ac_cv_func_readlinkat=no

        # Added symbols between 10.7 and 10.9
        export ac_cv_func_memset_s=no

        # libnetwork does not exist yet on 10.7 (used by libcddb)
        export ac_cv_lib_network_connect=no
    fi
    # The following symbols do not exist on the minimal iOS version (7.0), so they are disabled
    # here. This allows compilation also with newer iOS SDKs

    # Added symbols in macOS 10.12 / iOS 10 / watchOS 3
    export ac_cv_func_basename_r=no
    export ac_cv_func_clock_getres=no
    export ac_cv_func_clock_gettime=no
    export ac_cv_func_clock_settime=no
    export ac_cv_func_dirname_r=no
    export ac_cv_func_getentropy=no
    export ac_cv_func_mkostemp=no
    export ac_cv_func_mkostemps=no
    export ac_cv_func_timingsafe_bcmp=no

    # Added symbols in macOS 10.13 / iOS 11 / watchOS 4 / tvOS 11
    export ac_cv_func_open_wmemstream=no
    export ac_cv_func_fmemopen=no
    export ac_cv_func_open_memstream=no
    export ac_cv_func_futimens=no
    export ac_cv_func_utimensat=no

    # Added symbol in macOS 10.14 / iOS 12 / tvOS 9
    export ac_cv_func_thread_get_register_pointer_values=no

    # Added symbols in macOS 10.15 / iOS 13 / tvOS 13
    export ac_cv_func_aligned_alloc=no
    export ac_cv_func_timespec_get=no

    export USE_FFMPEG=1
    ../bootstrap --build=${BUILD_TRIPLET} --host=${HOST_TRIPLET} --prefix=${VLCROOT}/contrib/${OSSTYLE}${PLATFORM_IDENTIFIER}-${HOST_TRIPLET}-${ARCH} --disable-gpl \
        --enable-ad-clauses \
        --disable-gnuv3 \
        --disable-disc \
        --disable-sdl \
        --disable-SDL_image \
        --disable-iconv \
        --enable-zvbi \
        --disable-kate \
        --disable-caca \
        --disable-gettext \
        --disable-mpcdec \
        --enable-upnp \
        --disable-gme \
        --disable-srt \
        --disable-tremor \
        --enable-vorbis \
        --disable-sidplay2 \
        --disable-samplerate \
        --disable-goom \
        --disable-vncserver \
        --disable-orc \
        --disable-schroedinger \
        --disable-libmpeg2 \
        --disable-chromaprint \
        --disable-mad \
        --enable-fribidi \
        --enable-libxml2 \
        --enable-freetype2 \
        --enable-ass \
        --disable-fontconfig \
        --disable-gpg-error \
        --disable-vncclient \
        --disable-gnutls \
        --disable-lua \
        --disable-luac \
        --disable-aribb24 \
        --disable-aribb25 \
        --enable-vpx \
        --enable-libdsm \
        --enable-smb2 \
        --enable-libplacebo \
        --disable-sparkle \
        --disable-growl \
        --disable-breakpad \
        --disable-ncurses \
        --disable-asdcplib \
        --enable-soxr \
        ${CUSTOMOSOPTIONS} \
        --enable-taglib > ${out}

    rm -f config.mak
    echo "EXTRA_CFLAGS += ${EXTRA_CFLAGS}" >> config.mak
    echo "EXTRA_LDFLAGS += ${EXTRA_LDFLAGS}" >> config.mak
    make fetch -j$MAKE_JOBS
    make -j$MAKE_JOBS > ${out}

    spopd # ${VLCROOT}/contrib

    if ! [ -e ${VLCROOT}/configure ]; then
        info "Bootstraping vlc"
        ${VLCROOT}/bootstrap  > ${out}
    fi

    mkdir -p ${BUILDDIR}
    spushd ${BUILDDIR}

	export CPPFLAGS="${EXTRA_CFLAGS}"
	export CFLAGS="${EXTRA_CFLAGS}"
	export CXXFLAGS="${EXTRA_CFLAGS}"
	export OBJCFLAGS="${EXTRA_CFLAGS}"
	export LDFLAGS="${EXTRA_LDFLAGS}"

    if [ "$DEBUG" = "yes" ]; then
        DEBUGFLAG="--enable-debug"
    else
        export CFLAGS="${EXTRA_CFLAGS} -DNDEBUG"
    fi

    if [ "$SCARY" = "yes" ]; then
        SCARYFLAG="--enable-dvbpsi --enable-avcodec"
    else
        SCARYFLAG="--disable-dca --disable-dvbpsi --disable-avcodec --disable-avformat --disable-zvbi --enable-vpx"
    fi

    if [ "$TVOS" != "yes" -a \( "$ARCH" = "armv7" -o "$ARCH" = "armv7s" \) ];then
        export ac_cv_arm_neon=yes
    else
        export ac_cv_arm_neon=no
    fi

    # Available but not authorized
    export ac_cv_func_daemon=no
    export ac_cv_func_fork=no

    if [ "${VLCROOT}/configure" -nt config.log -o \
         "${THIS_SCRIPT_PATH}" -nt config.log ]; then
         info "Configuring vlc"

    ${VLCROOT}/configure \
        --prefix="${PREFIX}" \
        --host="${HOST_TRIPLET}" \
        --with-contrib="${VLCROOT}/contrib/${OSSTYLE}${PLATFORM_IDENTIFIER}-${HOST_TRIPLET}-${ARCH}" \
        --enable-static \
        ${DEBUGFLAG} \
        ${SCARYFLAG} \
        --disable-macosx \
        --disable-macosx-qtkit \
        --disable-macosx-avfoundation \
        --disable-shared \
        --enable-opus \
        --disable-faad \
        --disable-lua \
        --disable-a52 \
        --enable-fribidi \
        --disable-qt --disable-skins2 \
        --disable-vcd \
        --disable-vlc \
        --disable-vlm \
        --disable-nls \
        --disable-sse \
        --disable-notify \
        --enable-live555 \
        --enable-realrtsp \
        --enable-swscale \
        --disable-projectm \
        --enable-libass \
        --enable-libxml2 \
        --disable-goom \
        --disable-dvdread \
        --disable-dvdnav \
        --disable-bluray \
        --disable-linsys \
        --disable-libva \
        --disable-gme \
        --disable-tremor \
        --enable-vorbis \
        --disable-fluidsynth \
        --disable-jack \
        --disable-pulse \
        --disable-mtp \
        --enable-ogg \
        --enable-speex \
        --enable-theora \
        --enable-flac \
        --disable-screen \
        --enable-freetype \
        --enable-taglib \
        --enable-smb2 \
        --disable-mmx \
        --disable-sparkle \
        --disable-addonmanagermodules \
        --disable-mad > ${out}
    fi

    info "Building libvlc"
    make -j$MAKE_JOBS > ${out}

    info "Installing libvlc"
    make install > ${out}

    find ${PREFIX}/lib/vlc/plugins -name *.a -type f -exec cp '{}' ${PREFIX}/lib/vlc/plugins \;
    rm -rf "${PREFIX}/contribs"
    cp -R "${VLCROOT}/contrib/${OSSTYLE}${PLATFORM_IDENTIFIER}-${HOST_TRIPLET}-${ARCH}" "${PREFIX}/contribs"

    info "Removing unneeded modules"
    blacklist="
    stats
    access_bd
    shm
    access_imem
    oldrc
    real
    hotkeys
    gestures
    dynamicoverlay
    rss
    ball
    marq
    audiobargraph_
    clone
    mosaic
    osdmenu
    puzzle
    mediadirs
    t140
    ripple
    motion
    sharpen
    grain
    posterize
    mirror
    wall
    scene
    blendbench
    psychedelic
    alphamask
    netsync
    audioscrobbler
    motiondetect
    motionblur
    export
    smf
    podcast
    bluescreen
    erase
    stream_filter_record
    speex_resampler
    remoteosd
    gradient
    logger
    visual
    fb
    aout_file
    invert
    sepia
    wave
    hqdn3d
    headphone_channel_mixer
    gaussianblur
    gradfun
    extract
    colorthres
    antiflicker
    anaglyph
    remap
    oldmovie
    vhs
    fingerprinter
    output_udp
    output_livehttp
    "

    if [ "$SCARY" = "no" ]; then
    blacklist="${blacklist}
    dts
    dvbsub
    svcd
    hevc
    packetizer_mlp
    a52
    vc1
    uleaddvaudio
    librar
    libvoc
    avio
    chorus_flanger
    smooth
    cvdsub
    libmod
    libdash
    libmpgv
    dolby_surround
    mpegaudio"
    fi

    echo ${blacklist}

    for i in ${blacklist}
    do
        find ${PREFIX}/lib/vlc/plugins -name *$i* -type f -exec rm '{}' \;
    done

    spopd
}

buildMobileKit() {
    PLATFORM="$1"

    cleantheenvironment

    if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
        if [ "$TVOS" = "yes" ]; then
            # this variable is read by libvlc's contrib build script
            # to create the required build environment
            # for historical raisons, tvOS is a special flavor of iOS
            # so we need to export both variables
            export BUILDFORIOS="yes"
            export BUILDFORTVOS="yes"
            info "Building libvlc for tvOS"
        fi
        if [ "$MACOS" = "yes" ]; then
            # macOS is the default build environment for libvlc's contrib
            # build scripts, so we don't need to export anything
            info "Building libvlc for macOS"
        fi
        if [ "$IOS" = "yes" ]; then
            # this variable is read by libvlc's contrib build script
            # to create the required build environment
            export BUILDFORIOS="yes"
            info "Building libvlc for iOS"
        fi

        export AR="`xcrun --find ar`"
        export CC="`xcrun --find clang`"
        export CXX="`xcrun --find clang++`"
        export NM="`xcrun --find nm`"
        export OBJC="`xcrun --find clang`"
        export RANLIB="`xcrun --find ranlib`"
        export STRINGS="`xcrun --find strings`"
        export STRIP="`xcrun --find strip`"

        if [ "$FARCH" = "all" ];then
            if [ "$TVOS" = "yes" ]; then
                if [ "$PLATFORM" = "iphonesimulator" ]; then
                    buildLibVLC "x86_64" "Simulator"
                    buildLibVLC "aarch64" "Simulator"
                else
                    buildLibVLC "aarch64" "OS"
                fi
            fi
            if [ "$MACOS" = "yes" ]; then
                buildLibVLC "x86_64" "OS"
                buildLibVLC "aarch64" "OS"
            fi
            if [ "$IOS" = "yes" ]; then
                if [ "$PLATFORM" = "iphonesimulator" ]; then
                    buildLibVLC "i386" "Simulator"
                    buildLibVLC "x86_64" "Simulator"
                    buildLibVLC "aarch64" "Simulator"
                else
                    buildLibVLC "armv7" "OS"
                    buildLibVLC "armv7s" "OS"
                    buildLibVLC "aarch64" "OS"
                fi
            fi
        else
            if [ "$FARCH" != "x86_64" -a "$FARCH" != "aarch64" -a "$FARCH" != "i386" \
              -a "$FARCH" != "armv7" -a "$FARCH" != "armv7s" ];then
                echo "*** Framework ARCH: ${FARCH} is invalid ***"
                exit 1
            fi

            local buildPlatform=""
            if [ "$PLATFORM" = "iphonesimulator" ]; then
                if [ "$FARCH" == "x86_64" -o "$FARCH" == "i386" -o "$FARCH" == "aarch64" ];then
                    buildPlatform="Simulator"
                fi
            else
                if [ "$FARCH" == "armv7" -o "$FARCH" == "armv7s" -o "$FARCH" == "aarch64" ];then
                    buildPlatform="OS"
                fi
            fi
            if [ ! -z "$buildPlatform" ];then
                buildLibVLC $FARCH $buildPlatform
            fi
        fi
    fi
}

if [ "$BUILD_DEVICE" != "no" ]; then
    buildMobileKit iphoneos
fi
if [ "$BUILD_SIMULATOR" != "no" ]; then
    buildMobileKit iphonesimulator
fi

DEVICEARCHS=""
SIMULATORARCHS=""

get_symbol()
{
    echo "$1" | grep vlc_entry_$2|cut -d" " -f 3|sed 's/_vlc/vlc/'
}

collect_symbols_and_libraries() {
    PROJECT_DIR=`pwd`
    OSSTYLE="$1"
    info "building universal static libs for OS style $OSSTYLE"

    # remove old module list
    rm -f $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    rm -f $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig
    touch $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    touch $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig

    VLCMODULES=""
    VLCNEONMODULES=""
    SIMULATORARCHS=""
    CONTRIBLIBS=""
    DEVICEARCHS=""
    NEONARCHS=""

    # arm64 got the lowest number of modules
    arch="aarch64"
    if [ "$FARCH" != "all" ];then
        arch="$FARCH"
    elif [ "$BUILD_SIMULATOR" = "yes" ]; then
        arch="x86_64"
    fi

    actual_arch=`get_actual_arch $arch`

    if [ -d libvlc/vlc/install-"$OSSTYLE"OS ];then
        spushd libvlc/vlc/install-"$OSSTYLE"OS
        for i in `ls .`
        do
            local iarch="`get_arch $i`"
            if [ "$FARCH" == "all" -o "$FARCH" = "$iarch" ];then
                DEVICEARCHS="$DEVICEARCHS $iarch"
            fi
        done

        if (! is_simulator_arch $arch);then
            info "IPHONE OS: $arch"
            spushd $actual_arch/lib/vlc/plugins
            for i in `ls *.a`
            do
                VLCMODULES="$i $VLCMODULES"
            done
            spopd # $actual_arch/lib/vlc/plugins
        fi

        if [ "$OSSTYLE" = "MacOSX" ];then
            info "macOS: $actual_arch"
            spushd $actual_arch/lib/vlc/plugins
            for i in `ls *.a`
            do
                VLCMODULES="$i $VLCMODULES"
            done
            spopd # $actual_arch/lib/vlc/plugins
        fi

        if [ "$OSSTYLE" = "iPhone" -a \
            \( "$FARCH" = "all" -o "$FARCH" = "armv7" -o "$FARCH" = "armv7s" \) ]; then
            # collect ARMv7/s specific neon modules
            if [ "$FARCH" = "all" ];then
                NEONARCHS="armv7 armv7s"
                spushd armv7/lib/vlc/plugins
            else
                NEONARCHS=$FARCH
                spushd $FARCH/lib/vlc/plugins
            fi
            for i in `ls *.a | grep neon`
            do
                VLCNEONMODULES="$i $VLCNEONMODULES"
            done
            spopd # armv7/lib/vlc/plugins
        fi
        spopd # vlc-install-"$OSSTYLE"OS
    fi

   if [ -d ${VLCROOT}/install-"$OSSTYLE"Simulator ];then
        spushd ${VLCROOT}/install-"$OSSTYLE"Simulator
            for i in `ls .`
            do
                local iarch="`get_arch $i`"
                if [ "$FARCH" == "all" -o "$FARCH" = "$iarch" ];then
                    SIMULATORARCHS="$SIMULATORARCHS $iarch"
                fi
            done

            if (is_simulator_arch $arch);then
                info "SIMU OS: $arch"
                spushd $arch/lib/vlc/plugins
                    for i in `ls *.a`
                    do
                        VLCMODULES="$i $VLCMODULES"
                    done
                spopd # $iarch/lib/vlc/plugins
            fi
        spopd # vlc-install-"$OSSTYLE"Simulator
    fi

    spushd libvlc/vlc

    # collect contrib libraries
    local contriblocation=""
    if [ -d ${VLCROOT}/contrib/"$OSSTYLE"Simulator-$arch-apple-darwin-$arch/lib ];then
        contriblocation="contrib/"$OSSTYLE"Simulator-$arch-apple-darwin-$arch/lib"
    else
        contriblocation="contrib/"$OSSTYLE"OS-$arch-apple-darwin-$arch/lib"
    fi
    spushd $contriblocation
    for i in `ls *.a`
    do
        CONTRIBLIBS="$i $CONTRIBLIBS"
    done
    spopd # contriblocation

    # create module list
    info "creating module list"
    echo "// This file is autogenerated by $(basename $0)\n\n" > $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    echo "// This file is autogenerated by $(basename $0)\n\n" > $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig

    BUILTINS="const void *vlc_static_modules[] = {\n";
    COREFILES="libvlc.a libvlccore.a vlc/libcompat.a"

    SIMULATORLDFLAGS=""
    OSLDFLAGS=""
    DEFINITIONS=""

    info "device archs: $DEVICEARCHS"
    info "simulator archs: $SIMULATORARCHS"

    # add core libraries to LDFLAGS
    for file in $COREFILES
    do
        info "...$file"

        for i in $DEVICEARCHS
        do
            actual_arch=`get_actual_arch $i`
            DEVICELDFLAGS+="\$(PROJECT_DIR)/libvlc/vlc/install-"$OSSTYLE"OS/$actual_arch/lib/$file "
        done

        for i in $SIMULATORARCHS
        do
            actual_arch=`get_actual_arch $i`
            SIMULATORLDFLAGS+="\$(PROJECT_DIR)/libvlc/vlc/install-"$OSSTYLE"Simulator/$actual_arch/lib/$file "
        done
    done

    # add contrib libraries to LDFLAGS
    for file in $CONTRIBLIBS
    do
        info "...$file"

        for i in $DEVICEARCHS
        do
            actual_arch=`get_actual_arch $i`
            DEVICELDFLAGS+="\$(PROJECT_DIR)/libvlc/vlc/install-"$OSSTYLE"OS/$actual_arch/contribs/lib/$file "
        done

        for i in $SIMULATORARCHS
        do
            actual_arch=`get_actual_arch $i`
            SIMULATORLDFLAGS+="\$(PROJECT_DIR)/libvlc/vlc/install-"$OSSTYLE"Simulator/$actual_arch/contribs/lib/$file "
        done
    done

    # add VLC plugins to LDFLAGS
    for file in $VLCMODULES
    do
        info "...$file"
        for i in $DEVICEARCHS
        do
            actual_arch=`get_actual_arch $i`
            DEVICELDFLAGS+="\$(PROJECT_DIR)/libvlc/vlc/install-"$OSSTYLE"OS/$actual_arch/lib/vlc/plugins/$file "

            symbols=$(nm -g -arch $actual_arch install-"$OSSTYLE"OS/$actual_arch/lib/vlc/plugins/$file)
            entryname=$(get_symbol "$symbols" _)
            DEFINITIONS+="int $entryname (int (*)(void *, void *, int, ...), void *);\n";
            BUILTINS+=" $entryname,\n"
        done

        for i in $SIMULATORARCHS
        do
            actual_arch=`get_actual_arch $i`
            SIMULATORLDFLAGS+="\$(PROJECT_DIR)/libvlc/vlc/install-"$OSSTYLE"Simulator/$actual_arch/lib/vlc/plugins/$file "
        done
        info "...$entryname"
    done;

    # we only have ARM NEON modules for 32bit so this is limited to iOS
    if [ "$OSSTYLE" = "iPhone" ]; then
        BUILTINS+="#ifdef __arm__\n"
        DEFINITIONS+="#ifdef __arm__\n"
        for file in $VLCNEONMODULES
        do
            iter="0"
            for i in $NEONARCHS
            do
                actual_arch=`get_actual_arch $i`
                DEVICELDFLAGS+="\$(PROJECT_DIR)/libvlc/vlc/install-"$OSSTYLE"OS/$actual_arch/lib/vlc/plugins/$file "
                if [ "$iter" = "0" ]; then
                    symbols=$(nm -g -arch $actual_arch install-"$OSSTYLE"OS/$actual_arch/lib/vlc/plugins/$file)
                    entryname=$(get_symbol "$symbols" _)
                    DEFINITIONS+="int $entryname (int (*)(void *, void *, int, ...), void *);\n";
                    BUILTINS+=" $entryname,\n"
                    iter="1"
                    info "...$entryname"
                fi
            done
        done;
        BUILTINS+="#endif\n"
        DEFINITIONS+="#endif\n"
    fi

    BUILTINS="$BUILTINS NULL\n};\n"

    echo "$DEFINITIONS\n$BUILTINS" > $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    echo "VLC_PLUGINS_DEVICE_LDFLAGS=$DEVICELDFLAGS\nVLC_PLUGINS_SIMULATOR_LDFLAGS=$SIMULATORLDFLAGS" > $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig

    spopd # vlc
}

if [ "$TVOS" = "yes" ]; then
    collect_symbols_and_libraries "AppleTV"
fi
if [ "$MACOS" = "yes" ]; then
    collect_symbols_and_libraries "MacOSX"
fi
if [ "$IOS" = "yes" ]; then
    collect_symbols_and_libraries "iPhone"
fi

info "all done"

if [ "$BUILD_DYNAMIC_FRAMEWORK" != "no" ]; then
if [ "$TVOS" = "yes" ]; then
    info "Building dynamic TVVLCKit.xcframework"

    frameworks=""
    platform=""
    if [ "$FARCH" = "all" ] || (! is_simulator_arch $FARCH);then
        platform="appletvos"
        buildxcodeproj MobileVLCKit "TVVLCKit" ${platform}
        dsymfolder=$PROJECT_DIR/build/TVVLCKit-${platform}.xcarchive/dSYMs/TVVLCKit.framework.dSYM
        bcsymbolmapfolder=$PROJECT_DIR/build/TVVLCKit-${platform}.xcarchive/BCSymbolMaps
        spushd $bcsymbolmapfolder
        for i in `ls *.bcsymbolmap`
        do
            bcsymbolmap=$bcsymbolmapfolder/$i
        done
        spopd
        frameworks="$frameworks -framework TVVLCKit-${platform}.xcarchive/Products/Library/Frameworks/TVVLCKit.framework -debug-symbols $dsymfolder -debug-symbols $bcsymbolmap"
    fi
    if [ "$FARCH" = "all" ] || (is_simulator_arch $arch);then
        platform="appletvsimulator"
        buildxcodeproj MobileVLCKit "TVVLCKit" ${platform}
        dsymfolder=$PROJECT_DIR/build/TVVLCKit-${platform}.xcarchive/dSYMs/TVVLCKit.framework.dSYM
        frameworks="$frameworks -framework TVVLCKit-${platform}.xcarchive/Products/Library/Frameworks/TVVLCKit.framework -debug-symbols $dsymfolder"
    fi

    # Assumes both platforms were built currently
    spushd build
    rm -rf TVVLCKit.xcframework
    xcodebuild -create-xcframework $frameworks -output TVVLCKit.xcframework
    spopd # build

    info "Build of dynamic TVVLCKit.xcframework completed"
fi
if [ "$IOS" = "yes" ]; then
    info "Building dynamic MobileVLCKit.xcframework"

    frameworks=""
    platform=""
    if [ "$FARCH" = "all" ] || (! is_simulator_arch $FARCH);then
        platform="iphoneos"
        buildxcodeproj MobileVLCKit "MobileVLCKit" ${platform}
        dsymfolder=$PROJECT_DIR/build/MobileVLCKit-${platform}.xcarchive/dSYMs/MobileVLCKit.framework.dSYM
        bcsymbolmapfolder=$PROJECT_DIR/build/MobileVLCKit-${platform}.xcarchive/BCSymbolMaps
        frameworks="$frameworks -framework MobileVLCKit-${platform}.xcarchive/Products/Library/Frameworks/MobileVLCKit.framework -debug-symbols $dsymfolder"
        if [ -d ${bcsymbolmapfolder} ];then
            info "Bitcode support found"
            spushd $bcsymbolmapfolder
            for i in `ls *.bcsymbolmap`
            do
                frameworks+=" -debug-symbols $bcsymbolmapfolder/$i"
            done
            spopd
        fi
    fi
    if [ "$FARCH" = "all" ] || (is_simulator_arch $arch);then
        platform="iphonesimulator"
        buildxcodeproj MobileVLCKit "MobileVLCKit" ${platform}
        dsymfolder=$PROJECT_DIR/build/MobileVLCKit-${platform}.xcarchive/dSYMs/MobileVLCKit.framework.dSYM
        frameworks="$frameworks -framework MobileVLCKit-${platform}.xcarchive/Products/Library/Frameworks/MobileVLCKit.framework -debug-symbols $dsymfolder"
    fi

    # Assumes both platforms were built currently
    spushd build
    rm -rf MobileVLCKit.xcframework
    xcodebuild -create-xcframework $frameworks -output MobileVLCKit.xcframework
    spopd # build

    info "Build of dynamic MobileVLCKit.xcframework completed"
fi
fi
if [ "$BUILD_DYNAMIC_FRAMEWORK" != "no" ]; then
if [ "$MACOS" = "yes" ]; then
    info "Building dynamic VLCKit.framework"

    buildxcodeproj VLCKit "VLCKit" "macosx"

    # remove intermediate build result we don't need to keep
    spushd build
    mv VLCKit-macosx.xcarchive/Products/Library/Frameworks/VLCKit.framework VLCKit.framework
    spopd # build

    info "Build of VLCKit.framework completed"
fi
fi
