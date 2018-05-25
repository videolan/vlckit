#!/bin/sh
# Copyright (C) Pierre d'Herbemont, 2010
# Copyright (C) Felix Paul Kühne, 2012-2017

set -e

BUILD_DEVICE=yes
BUILD_SIMULATOR=yes
BUILD_STATIC_FRAMEWORK=no
BUILD_DYNAMIC_FRAMEWORK=no
SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`
SDK_MIN=7.0
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
OSVERSIONMINCFLAG=miphoneos-version-min
OSVERSIONMINLDFLAG=ios_version_min
ROOT_DIR=empty
FARCH="all"

TESTEDHASH="d3c5d18" # libvlc hash that this version of VLCKit is build on

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
   -e       External VLC source path
EOF
}

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
     echo -e "[${green}info${normal}] $1"
}

cleantheenvironment()
{
    export AS=""
    export CCAS=""
    export ASCPP=""
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
                architectures="x86_64"
            else
                architectures="arm64"
            fi
        fi
        if [ "$IOS" = "yes" ]; then
            if [ "$PLATFORM" = "iphonesimulator" ]; then
                architectures="i386 x86_64"
            else
                architectures="armv7 armv7s arm64"
            fi
        fi
    else
        architectures=`get_actual_arch $FARCH`
    fi

    local bitcodeflag=""
    if [ "$BITCODE" = "yes" ]; then
        bitcodeflag="BITCODE_GENERATION_MODE=bitcode"
    fi

    local defs="$GCC_PREPROCESSOR_DEFINITIONS"
    if [ "$SCARY" = "no" ]; then
        defs="$defs NOSCARYCODECS"
    fi

    xcodebuild -project "$1.xcodeproj" \
               -target "$target" \
               -sdk $PLATFORM$SDK \
               -configuration ${CONFIGURATION} \
               ARCHS="${architectures}" \
               IPHONEOS_DEPLOYMENT_TARGET=${SDK_MIN} \
               GCC_PREPROCESSOR_DEFINITIONS="$defs" \
               ${bitcodeflag} \
               > ${out}
}

buildLibVLC() {
    ARCH="$1"
    PLATFORM="$2"
    OSSTYLE=iPhone

    if [ "$DEBUG" = "yes" ]; then
        OPTIM="-O0 -g"
    else
        OPTIM="-O3 -g"
    fi

    if [ "$TVOS" = "yes" ]; then
        OSSTYLE=AppleTV
    fi
    if [ "$MACOS" = "yes" ]; then
        OSSTYLE=MacOSX
        PLATFORM=
    fi

    ACTUAL_ARCH=`get_actual_arch $ARCH`

    info "Compiling ${ARCH} with SDK version ${SDK_VERSION}, platform ${PLATFORM}"

    SDKROOT=`xcode-select -print-path`/Platforms/${OSSTYLE}${PLATFORM}.platform/Developer/SDKs/${OSSTYLE}${PLATFORM}${SDK_VERSION}.sdk

    if [ ! -d "${SDKROOT}" ]
    then
        echo "*** ${SDKROOT} does not exist, please install required SDK, or set SDKROOT manually. ***"
        exit 1
    fi

    BUILDDIR="${VLCROOT}/build-${OSSTYLE}${PLATFORM}/${ACTUAL_ARCH}"
    PREFIX="${VLCROOT}/install-${OSSTYLE}${PLATFORM}/${ACTUAL_ARCH}"
    TARGET="${ARCH}-apple-darwin14"

    # partially clean the environment
    export CFLAGS=""
    export CPPFLAGS=""
    export CXXFLAGS=""
    export OBJCFLAGS=""
    export LDFLAGS=""

    export PLATFORM=$PLATFORM
    export SDK_VERSION=$SDK_VERSION
    export VLCSDKROOT=$SDKROOT

    OBJCFLAGS="${OPTIM}"
    CFLAGS="-isysroot ${SDKROOT} -arch ${ACTUAL_ARCH} ${OPTIM}"
    EXTRA_CFLAGS="-arch ${ACTUAL_ARCH}"
    LDFLAGS="-arch ${ACTUAL_ARCH}"
    EXTRA_LDFLAGS="-arch ${ACTUAL_ARCH}"

    CFLAGS+=" -${OSVERSIONMINCFLAG}=${SDK_MIN}"
    EXTRA_CFLAGS+=" -${OSVERSIONMINCFLAG}=${SDK_MIN}"
    LDFLAGS+=" -Wl,-${OSVERSIONMINLDFLAG},${SDK_MIN}"
    EXTRA_LDFLAGS+=" -Wl,-${OSVERSIONMINLDFLAG},${SDK_MIN}"

    if [ "$PLATFORM" = "OS" ]; then
        if [ "$ARCH" != "aarch64" ]; then
            CFLAGS+=" -mcpu=cortex-a8"
            EXTRA_CFLAGS+=" -mcpu=cortex-a8"
        fi
    else # Simulator platform
        LDFLAGS+=" -v"

        # Use the new ABI on simulator, else we can't build
        OBJCFLAGS+=" -fobjc-abi-version=2 -fobjc-legacy-dispatch"
    fi

    if [ "$BITCODE" = "yes" ]; then
        CFLAGS+=" -fembed-bitcode"
    fi

    export CFLAGS="${CFLAGS}"
    export CXXFLAGS="${CFLAGS}"
    export CPPFLAGS="${CFLAGS}"
    export OBJCFLAGS="${OBJCFLAGS}"
    export LDFLAGS="${LDFLAGS}"

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
    else
        export ASCPP="xcrun as"
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

    if [ "${TARGET}" = "x86_64-apple-darwin14" ];then
        BUILD=""
    else
        BUILD="--build=x86_64-apple-darwin14"
    fi

    if [ "$MACOS" = "yes" ]; then
        # The following symbols do not exist on the minimal macOS version (10.7), so they are disabled
        # here. This allows compilation also with newer macOS SDKs.
        # Added symbols in 10.13
        export ac_cv_func_open_wmemstream=no
        export ac_cv_func_fmemopen=no
        export ac_cv_func_open_memstream=no
        export ac_cv_func_futimens=no
        export ac_cv_func_utimensat=no

        # Added symbols between 10.11 and 10.12
        export ac_cv_func_basename_r=no
        export ac_cv_func_clock_getres=no
        export ac_cv_func_clock_gettime=no
        export ac_cv_func_clock_settime=no
        export ac_cv_func_dirname_r=no
        export ac_cv_func_getentropy=no
        export ac_cv_func_mkostemp=no
        export ac_cv_func_mkostemps=no

        # Added symbols between 10.7 and 10.11
        export ac_cv_func_ffsll=no
        export ac_cv_func_flsll=no
        export ac_cv_func_fdopendir=no
        export ac_cv_func_openat=no
        export ac_cv_func_fstatat=no
        export ac_cv_func_readlinkat=no
    else
        # The following symbols do not exist on the minimal iOS version (7.0), so they are disabled
        # here. This allows compilation also with newer iOS SDKs
        # Added symbols between 7.x and 10.x
        export ac_cv_func_basename_r=no
        export ac_cv_func_clock_getres=no
        export ac_cv_func_clock_gettime=no
        export ac_cv_func_clock_settime=no
        export ac_cv_func_dirname_r=no
        export ac_cv_func_getentropy=no
        export ac_cv_func_mkostemp=no
        export ac_cv_func_mkostemps=no
        export ac_cv_func_open_memstream=no
        export ac_cv_func_futimens=no
    fi

    export USE_FFMPEG=1
    ../bootstrap ${BUILD} --host=${TARGET} --prefix=${VLCROOT}/contrib/${OSSTYLE}-${TARGET}-${ARCH} --disable-gpl \
        --enable-ad-clauses \
        --disable-disc \
        --disable-sdl \
        --disable-SDL_image \
        --disable-iconv \
        --enable-zvbi \
        --disable-kate \
        --disable-caca \
        --disable-gettext \
        --disable-mpcdec \
        --disable-upnp \
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
        --enable-libplacebo \
        --disable-sparkle \
        --disable-growl \
        --disable-breakpad \
        --disable-ncurses \
        --disable-asdcplib \
        --enable-soxr \
        ${CUSTOMOSOPTIONS} \
        --enable-taglib > ${out}

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

    if [ "$DEBUG" = "yes" ]; then
        DEBUGFLAG="--enable-debug"
    else
        export CFLAGS="${CFLAGS} -DNDEBUG"
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
        --host="${TARGET}" \
        --with-contrib="${VLCROOT}/contrib/${OSSTYLE}-${TARGET}-${ARCH}" \
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
        --disable-httpd \
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
    cp -R "${VLCROOT}/contrib/${OSSTYLE}-${TARGET}-${ARCH}" "${PREFIX}/contribs"

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
    magnify
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
    magnify
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
    demuxdump
    fingerprinter
    output_udp
    output_livehttp
    libmux
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

        export AR=`xcrun -f ar`
        export RANLIB=`xcrun -f ranlib`
        export CC=`xcrun -f clang`
        export OBJC=`xcrun -f clang`
        export CXX=`xcrun -f clang++`
        export LD=`xcrun -f ld`
        export STRIP=`xcrun -f strip`
        export CPPFLAGS=-E
        export CXXCPPFLAGS=-E
        unset AS
        unset CCAS

        if [ "$FARCH" = "all" ];then
            if [ "$TVOS" = "yes" ]; then
                if [ "$PLATFORM" = "iphonesimulator" ]; then
                    buildLibVLC "x86_64" "Simulator"
                else
                    buildLibVLC "aarch64" "OS"
                fi
            fi
            if [ "$MACOS" = "yes" ]; then
                buildLibVLC "x86_64" "OS"
            fi
            if [ "$IOS" = "yes" ]; then
                if [ "$PLATFORM" = "iphonesimulator" ]; then
                    buildLibVLC "i386" "Simulator"
                    buildLibVLC "x86_64" "Simulator"
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
                if [ "$FARCH" == "x86_64" -o "$FARCH" == "i386" ];then
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

doVLCLipo() {
    FILEPATH="$1"
    FILE="$2"
    PLUGIN="$3"
    OSSTYLE="$4"
    files=""

    info "...$FILEPATH$FILE"

    for i in $DEVICEARCHS
    do
        actual_arch=`get_actual_arch $i`
        files="install-"$OSSTYLE"OS/$actual_arch/lib/$FILEPATH$FILE $files"
    done

    for i in $SIMULATORARCHS
    do
        actual_arch=`get_actual_arch $i`
        files="install-"$OSSTYLE"Simulator/$actual_arch/lib/$FILEPATH$FILE $files"
    done

    if [ "$PLUGIN" != "no" ]; then
        lipo $files -create -output install-$OSSTYLE/plugins/$FILE
    else
        lipo $files -create -output install-$OSSTYLE/core/$FILE
    fi
}

doContribLipo() {
    LIBNAME="$1"
    OSSTYLE="$2"
    files=""

    info "...$LIBNAME"

    for i in $DEVICEARCHS $SIMULATORARCHS
    do
        files="contrib/$OSSTYLE-$i-apple-darwin14-$i/lib/$LIBNAME $files"
    done

    lipo $files -create -output install-$OSSTYLE/contrib/$LIBNAME
}

get_symbol()
{
    echo "$1" | grep vlc_entry_$2|cut -d" " -f 3|sed 's/_vlc/vlc/'
}

build_universal_static_lib() {
    PROJECT_DIR=`pwd`
    OSSTYLE="$1"
    info "building universal static libs for OS style $OSSTYLE"

    # remove old module list
    rm -f $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    rm -f $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig
    touch $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    touch $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig

    if [ "$OSSTYLE" != "MacOSX" ]; then
        spushd ${VLCROOT}
        rm -rf install-$OSSTYLE
        mkdir install-$OSSTYLE
        mkdir install-$OSSTYLE/core
        mkdir install-$OSSTYLE/contrib
        mkdir install-$OSSTYLE/plugins
        spopd # vlc
    else
        spushd ${VLCROOT}/install-$OSSTYLE
        rm -rf core
        rm -rf contrib
        rm -rf plugins
        ln -s x86_64/lib core
        ln -s x86_64/contribs/lib contrib
        ln -s x86_64/lib/vlc/plugins plugins
        spopd # vlc
    fi

    VLCMODULES=""
    VLCNEONMODULES=""
    SIMULATORARCHS=""
    CONTRIBLIBS=""
    DEVICEARCHS=""

    # arm64 got the lowest number of modules
    arch="aarch64"
    if [ "$FARCH" != "all" ];then
        arch="$FARCH"
    fi
    actual_arch=`get_actual_arch $arch`

    if [ -d ${VLCROOT}/install-"$OSSTYLE"OS ];then
        spushd ${VLCROOT}/install-"$OSSTYLE"OS
        for i in `ls .`
        do
            local iarch="`get_arch $i`"
            if [ "$FARCH" == "all" -o "$FARCH" = "$iarch" ];then
                DEVICEARCHS="$DEVICEARCHS $iarch"
            fi
        done

        if (! is_simulator_arch $arch);then
            echo "IPHONE OS: $arch"
            spushd $actual_arch/lib/vlc/plugins
            for i in `ls *.a`
            do
                VLCMODULES="$i $VLCMODULES"
            done
            spopd # $actual_arch/lib/vlc/plugins
        fi

        if [ "$OSSTYLE" != "AppleTV" -a \
            \( "$FARCH" = "all" -o "$FARCH" = "armv7" -o "$FARCH" = "armv7s" \) ]; then
            # collect ARMv7/s specific neon modules
            if [ "$FARCH" = "all" ];then
                spushd armv7/lib/vlc/plugins
            else
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

        if (is_simulator_arch $arch);then
            echo "SIMU OS: $arch"
            spushd $actual_arch/lib/vlc/plugins
            for i in `ls *.a`
            do
                VLCMODULES="$i $VLCMODULES"
            done
            spopd # $actual_arch/lib/vlc/plugins
        fi
        for i in `ls .`
        do
            local iarch="`get_arch $i`"
            if [ "$FARCH" == "all" -o "$FARCH" = "$iarch" ];then
                SIMULATORARCHS="$SIMULATORARCHS $iarch"
            fi
        done
        spopd # vlc-install-"$OSSTYLE"Simulator
    fi

    if [ "$OSSTYLE" = "MacOSX" ]; then
        if [ -d ${VLCROOT}/install-"$OSSTYLE" ];then
            spushd ${VLCROOT}/install-"$OSSTYLE"
            echo `pwd`
            echo "macOS: $arch"
            spushd $arch/lib/vlc/plugins
            for i in `ls *.a`
            do
                VLCMODULES="$i $VLCMODULES"
            done
            spopd # $actual_arch/lib/vlc/plugins

            spopd # vlc-install-"$OSSTYLE"
        fi
    fi

    spushd ${VLCROOT}

    # collect contrib libraries
    spushd contrib/$OSSTYLE-$arch-apple-darwin14-$arch/lib
    for i in `ls *.a`
    do
        CONTRIBLIBS="$i $CONTRIBLIBS"
    done
    spopd # contrib/$OSSTYLE-$arch-apple-darwin14-$arch/lib

    # lipo all the vlc libraries and its plugins
    if [ "$OSSTYLE" != "MacOSX" ]; then
        doVLCLipo "" "libvlc.a" "no" $OSSTYLE
        doVLCLipo "" "libvlccore.a" "no" $OSSTYLE
        doVLCLipo "vlc/" "libcompat.a" "no" $OSSTYLE
        for i in $VLCMODULES
        do
            doVLCLipo "vlc/plugins/" $i "yes" $OSSTYLE
        done

        # lipo contrib libraries
        for i in $CONTRIBLIBS
        do
            doContribLipo $i $OSSTYLE
        done

        if [ "$OSSTYLE" != "AppleTV" ]; then
            # lipo the remaining NEON plugins
            DEVICEARCHS=""
            for i in armv7 armv7s; do
                local iarch="`get_arch $i`"
                if [ "$FARCH" == "all" -o "$FARCH" = "$iarch" ];then
                    DEVICEARCHS="$DEVICEARCHS $iarch"
                fi
            done
            SIMULATORARCHS=""
            for i in $VLCNEONMODULES
            do
                doVLCLipo "vlc/plugins/" $i "yes" $OSSTYLE
            done
        fi
    fi

    # create module list
    info "creating module list"
    echo "// This file is autogenerated by $(basename $0)\n\n" > $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    echo "// This file is autogenerated by $(basename $0)\n\n" > $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig

    # arm64 got the lowest number of modules
    BUILTINS="const void *vlc_static_modules[] = {\n"; \

    LDFLAGS=""
    DEFINITIONS=""

    # add contrib libraries to LDFLAGS
    for file in $CONTRIBLIBS
    do
        LDFLAGS+="${VLCROOT}/install-$OSSTYLE/contrib/$file "
    done

    for file in $VLCMODULES
    do
        symbols=$(nm -g -arch $actual_arch install-$OSSTYLE/plugins/$file)
        entryname=$(get_symbol "$symbols" _)
        DEFINITIONS+="int $entryname (int (*)(void *, void *, int, ...), void *);\n";
        BUILTINS+=" $entryname,\n"
        LDFLAGS+="${VLCROOT}/install-$OSSTYLE/plugins/$file "
        info "...$entryname"
    done;

    # we only have ARM NEON modules for 32bit so this is limited to iOS
    if [ "$OSSTYLE" = "iPhone" ]; then
        BUILTINS+="#ifdef __arm__\n"
        DEFINITIONS+="#ifdef __arm__\n"
        for file in $VLCNEONMODULES
        do
            symbols=$(nm -g -arch $actual_arch install-$OSSTYLE/plugins/$file)
            entryname=$(get_symbol "$symbols" _)
            DEFINITIONS+="int $entryname (int (*)(void *, void *, int, ...), void *);\n";
            BUILTINS+=" $entryname,\n"
            LDFLAGS+="${VLCROOT}/install-$OSSTYLE/plugins/$file "
            info "...$entryname"
        done;
        BUILTINS+="#endif\n"
        DEFINITIONS+="#endif\n"
    fi

    BUILTINS="$BUILTINS NULL\n};\n"

    echo "$DEFINITIONS\n$BUILTINS" >> $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.h
    echo "VLC_PLUGINS_LDFLAGS=$LDFLAGS" >> $PROJECT_DIR/Resources/MobileVLCKit/vlc-plugins-$OSSTYLE.xcconfig

    spopd # vlc
}

while getopts "hvwsfbdxntlk:a:e:" OPTION
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
             BUILD_STATIC_FRAMEWORK=no
             ;;
         f)
             BUILD_DEVICE=yes
             BUILD_SIMULATOR=yes
             BUILD_STATIC_FRAMEWORK=yes
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
             BUILD_STATIC_FRAMEWORK=yes
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
             SDK_MIN=9.0
             OSVERSIONMINCFLAG=mtvos-version-min
             OSVERSIONMINLDFLAG=tvos_version_min
             ;;
         x)
             MACOS=yes
             IOS=no
             BITCODE=no
             SDK_VERSION=`xcrun --sdk macosx --show-sdk-version`
             SDK_MIN=10.9
             OSVERSIONMINCFLAG=mmacosx-version-min
             OSVERSIONMINLDFLAG=macosx_version_min
             BUILD_DEVICE=yes
             FARCH=x86_64
             BUILD_DYNAMIC_FRAMEWORK=yes
             BUILD_STATIC_FRAMEWORK=no
             ;;
         e)
             VLCROOT=$OPTARG
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
ROOT_DIR=`pwd`
spopd

if [ "$VLCROOT" = "" ]; then
    VLCROOT=${ROOT_DIR}/libvlc/vlc
    info "Preparing build dirs"

    mkdir -p libvlc
    spushd libvlc

    if [ "$NONETWORK" != "yes" ]; then
        if ! [ -e vlc ]; then
            git clone https://git.videolan.org/git/vlc/vlc-3.0.git vlc
            info "Applying patches to vlc.git"
            cd vlc
            git checkout -B localBranch ${TESTEDHASH}
            git branch --set-upstream-to=origin/master localBranch
            git am ${ROOT_DIR}/Resources/MobileVLCKit/patches/*.patch
            if [ $? -ne 0 ]; then
                git am --abort
                info "Applying the patches failed, aborting git-am"
                exit 1
            fi
            cd ..
        else
            cd vlc
            git pull --rebase
            git reset --hard ${TESTEDHASH}
            git am ${ROOT_DIR}/Resources/MobileVLCKit/patches/*.patch
            cd ..
        fi
    fi

    spopd
fi

export PATH="${VLCROOT}/extras/tools/build/bin:${VLCROOT}/contrib/${TARGET}/bin:${VLC_PATH}:/usr/bin:/bin:/usr/sbin:/sbin"

echo `pwd`

#
# Build time
#

out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
    info "Building tools"
    spushd ${VLCROOT}/extras/tools
    ./bootstrap
    make
    make .gas
    spopd #${VLCROOT}/extras/tools
fi

if [ "$BUILD_DEVICE" != "no" ]; then
    buildMobileKit iphoneos
fi
if [ "$BUILD_SIMULATOR" != "no" ]; then
    buildMobileKit iphonesimulator
fi

DEVICEARCHS=""
SIMULATORARCHS=""

if [ "$TVOS" = "yes" ]; then
    build_universal_static_lib "AppleTV"
fi
if [ "$MACOS" = "yes" ]; then
    build_universal_static_lib "MacOSX"
fi
if [ "$IOS" = "yes" ]; then
    build_universal_static_lib "iPhone"
fi

info "all done"

if [ "$BUILD_STATIC_FRAMEWORK" != "no" ]; then
if [ "$TVOS" = "yes" ]; then
    info "Building static TVVLCKit.framework"

    lipo_libs=""
    platform=""
    if [ -d ${VLCROOT}/install-AppleTVOS ];then
        platform="appletvos"
        buildxcodeproj MobileVLCKit "TVVLCKit" ${platform}
        lipo_libs="$lipo_libs ${CONFIGURATION}-appletvos/libTVVLCKit.a"
    fi
    if [ -d ${VLCROOT}/install-AppleTVSimulator ];then
        platform="appletvsimulator"
        buildxcodeproj MobileVLCKit "TVVLCKit" ${platform}
        lipo_libs="$lipo_libs ${CONFIGURATION}-appletvsimulator/libTVVLCKit.a"
    fi

    # Assumes both platforms were built currently
    spushd build
    rm -rf TVVLCKit.framework && \
    mkdir TVVLCKit.framework && \
    lipo -create ${lipo_libs} -o TVVLCKit.framework/TVVLCKit && \
    chmod a+x TVVLCKit.framework/TVVLCKit && \
    cp -pr ${CONFIGURATION}-${platform}/TVVLCKit TVVLCKit.framework/Headers
    spopd # build

    info "Build of static TVVLCKit.framework completed"
fi
if [ "$IOS" = "yes" ]; then
    info "Building static MobileVLCKit.framework"

    lipo_libs=""
    platform=""
    if [ "$FARCH" = "all" ] || (! is_simulator_arch $FARCH);then
        platform="iphoneos"
        buildxcodeproj MobileVLCKit "MobileVLCKit" ${platform}
        lipo_libs="$lipo_libs ${CONFIGURATION}-iphoneos/libMobileVLCKit.a"
    fi
    if [ "$FARCH" = "all" ] || (is_simulator_arch $arch);then
        platform="iphonesimulator"
        buildxcodeproj MobileVLCKit "MobileVLCKit" ${platform}
        lipo_libs="$lipo_libs ${CONFIGURATION}-iphonesimulator/libMobileVLCKit.a"
    fi

    # Assumes both platforms were built currently
    spushd build
    rm -rf MobileVLCKit.framework && \
    mkdir MobileVLCKit.framework && \
    lipo -create ${lipo_libs} -o MobileVLCKit.framework/MobileVLCKit && \
    chmod a+x MobileVLCKit.framework/MobileVLCKit && \
    cp -pr ${CONFIGURATION}-${platform}/MobileVLCKit MobileVLCKit.framework/Headers
    spopd # build

    info "Build of static MobileVLCKit.framework completed"
fi
fi
if [ "$BUILD_DYNAMIC_FRAMEWORK" != "no" ]; then
if [ "$MACOS" = "yes" ]; then
    info "Building VLCKit.framework"

    buildxcodeproj VLCKit "VLCKit" "macosx"

    # remove intermediate build result we don't need to keep
    spushd build
    rm ${CONFIGURATION}/libStaticLibVLC.a
    spopd # build

    info "Build of VLCKit.framework completed"
fi
fi
