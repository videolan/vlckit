#!/bin/sh
# Copyright (C) Pierre d'Herbemont, 2010
# Copyright (C) Felix Paul Kühne, 2012-2019

set -e

BUILD_DEVICE=yes
BUILD_SIMULATOR=yes
BUILD_STATIC_FRAMEWORK=no
BUILD_DYNAMIC_FRAMEWORK=no
SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`
SDK_MIN=9.0
VERBOSE=no
DISABLEDEBUG=no
CONFIGURATION="Debug"
NONETWORK=no
SKIPLIBVLCCOMPILATION=no
TVOS=no
MACOS=no
IOS=yes
BITCODE=no
OSVERSIONMINCFLAG=iphoneos
OSVERSIONMINLDFLAG=ios
ROOT_DIR=empty
FARCH="all"

TESTEDHASH="6e223d67a" # libvlc hash that this version of VLCKit is build on

usage()
{
cat << EOF
usage: $0 [-s] [-v] [-k sdk]

OPTIONS
   -k       Specify which sdk to use (see 'xcodebuild -showsdks', current: ${SDK})
   -v       Be more verbose
   -s       Build for simulator
   -f       Build framework for device and simulator
   -d       Disable Debug
   -n       Skip script steps requiring network interaction
   -l       Skip libvlc compilation
   -t       Build for tvOS
   -x       Build for macOS / Mac OS X
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
     echo "[${green}info${normal}] $1"
}

buildxcodeproj()
{
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

    if [ "$DISABLEDEBUG" = "yes" ]; then
        DEBUGFLAG="--disable-debug"
    else
        DEBUGFLAG=""
    fi
    if [ "$VERBOSE" = "yes" ]; then
        VERBOSEFLAG="--verbose"
    else
        VERBOSEFLAG=""
    fi
    info "Compiling ${ARCH} with SDK version ${SDK_VERSION}, platform ${PLATFORM}"

    ACTUAL_ARCH=`get_actual_arch $ARCH`
    BUILDDIR="${VLCROOT}/build-${PLATFORM}-${ACTUAL_ARCH}"

    mkdir -p ${BUILDDIR}
    spushd ${BUILDDIR}
    
    ../extras/package/apple/build.sh --arch=$ARCH --sdk=${PLATFORM}${SDK_VERSION} ${DEBUGFLAG} ${VERBOSEFLAG}

    spopd # builddir

    info "Finished compiling libvlc for ${ARCH} with SDK version ${SDK_VERSION}, platform ${PLATFORM}"
}

buildMobileKit() {
    PLATFORM="$1"

    if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
        if [ "$FARCH" = "all" ];then
            if [ "$TVOS" = "yes" ]; then
                if [ "$PLATFORM" = "iphonesimulator" ]; then
                    buildLibVLC "x86_64" "appletvsimulator"
                else
                    buildLibVLC "aarch64" "appletvos"
                fi
            fi
            if [ "$MACOS" = "yes" ]; then
                buildLibVLC "x86_64" "macosx"
            fi
            if [ "$IOS" = "yes" ]; then
                if [ "$PLATFORM" = "iphonesimulator" ]; then
                    buildLibVLC "i386" $PLATFORM
                    buildLibVLC "x86_64" $PLATFORM
                else
                    buildLibVLC "armv7" $PLATFORM
                    buildLibVLC "armv7s" $PLATFORM
                    buildLibVLC "aarch64" $PLATFORM
                fi
            fi
        else
            if [ "$FARCH" != "x86_64" -a "$FARCH" != "aarch64" -a "$FARCH" != "i386" \
              -a "$FARCH" != "armv7" -a "$FARCH" != "armv7s" ];then
                echo "*** Framework ARCH: ${FARCH} is invalid ***"
                exit 1
            fi
            if (is_simulator_arch $FARCH);then
                if [ "$TVOS" = "yes" ]; then
                    PLATFORM="appletvsimulator"
                fi
                if [ "$IOS" = "yes" ]; then
                    PLATFORM="iphonesimulator"
                fi
                if [ "$MACOS" = "yes" ]; then
                    PLATFORM="macosx"
                fi
            else
                if [ "$TVOS" = "yes" ]; then
                    PLATFORM="appletvos"
                fi
                if [ "$IOS" = "yes" ]; then
                    PLATFORM="iphoneos"
                fi
                if [ "$MACOS" = "yes" ]; then
                    PLATFORM="macosx"
                fi
            fi

            buildLibVLC $FARCH "$PLATFORM"
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
        files="build-"$OSSTYLE"os-$actual_arch/vlc-"$OSSTYLE"os${SDK_VERSION}-$actual_arch/lib/$FILEPATH$FILE $files"
    done

    for i in $SIMULATORARCHS
    do
        actual_arch=`get_actual_arch $i`
        files="build-"$OSSTYLE"simulator-$actual_arch/vlc-"$OSSTYLE"simulator${SDK_VERSION}-$actual_arch/lib/$FILEPATH$FILE $files"
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

    for i in $DEVICEARCHS
    do
        files="build-"$OSSTYLE"os-$i/contrib/$i-"$OSSTYLE"os/lib/$LIBNAME $files"
    done
    for i in $SIMULATORARCHS
    do
        files="build-"$OSSTYLE"simulator-$i/contrib/$i-"$OSSTYLE"simulator/lib/$LIBNAME $files"
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
    VLCMODULECATEGORYNAMES=""
    VLCNEONMODULES=""
    SIMULATORARCHS=""
    CONTRIBLIBS=""
    DEVICEARCHS=""

    arch="aarch64"
    if [ "$FARCH" != "all" ];then
        arch="$FARCH"
    elif [ "$BUILD_SIMULATOR" = "yes" ]; then
        arch="x86_64"
    fi

    actual_arch=`get_actual_arch $arch`

    # arm64 got the lowest number of modules, so we iterate here
    if [ -d ${VLCROOT}/build-"$OSSTYLE"os-arm64 ];then
        if [ "$OSSTYLE" = "iphone" ];then
            if [ "$FARCH" = "all" ];then
                DEVICEARCHS="arm64 armv7 armv7s"
            fi
        fi
        if [ "$OSSTYLE" = "appletv" ];then
            if [ "$FARCH" = "all" ];then
                DEVICEARCHS="arm64"
            fi
        fi
        VLCMODULES=""
        CONTRIBLIBS=""

        spushd ${VLCROOT}/build-"$OSSTYLE"os-arm64/vlc-"$OSSTYLE"os${SDK_VERSION}-arm64/lib/vlc/plugins/
        for f in `ls -F`
        do
            VLCMODULECATEGORYNAMES="$f $VLCMODULECATEGORYNAMES"
            for i in `ls $f*.a`
            do
                VLCMODULES="$i $VLCMODULES"
            done
        done
        spopd

        spushd ${VLCROOT}/build-"$OSSTYLE"os-arm64/contrib/arm64-"$OSSTYLE"os/lib
        for i in `ls *.a`
        do
            CONTRIBLIBS="$i $CONTRIBLIBS"
        done
        spopd
    fi

    if [ "$OSSTYLE" != "appletv" ];then
        # if we have an armv7(s) slice, we should search for and include NEON modules
        if [ -d ${VLCROOT}/build-"$OSSTYLE"os-armv7 ];then
            spushd ${VLCROOT}/build-"$OSSTYLE"os-armv7/vlc-"$OSSTYLE"os${SDK_VERSION}-armv7/lib/vlc/plugins/
            for f in `ls -F`
            do
                for i in `ls $f*.a | grep neon`
                do
                    VLCNEONMODULES="$i $VLCNEONMODULES"
                done
            done
            spopd
        fi
    fi

    # x86_64 got the lowest number of modules, so we iterate here
    if [ -d ${VLCROOT}/build-"$OSSTYLE"simulator-x86_64 ];then
        if [ "$OSSTYLE" = "iphone" ];then
            if [ "$FARCH" = "all" ];then
                SIMULATORARCHS="x86_64 i386"
            fi
        fi
        if [ "$OSSTYLE" = "appletv" ];then
            if [ "$FARCH" = "all" ];then
                DEVICEARCHS="x86_64"
            fi
        fi
        VLCMODULES=""
        CONTRIBLIBS=""
        VLCMODULECATEGORYNAMES=""

        spushd ${VLCROOT}/build-"$OSSTYLE"simulator-x86_64/vlc-"$OSSTYLE"simulator${SDK_VERSION}-x86_64/lib/vlc/plugins/
        for f in `ls -F`
        do
            VLCMODULECATEGORYNAMES="$f $VLCMODULECATEGORYNAMES"
            for i in `ls $f*.a`
            do
                VLCMODULES="$i $VLCMODULES"
            done
        done
        spopd

        spushd ${VLCROOT}/build-"$OSSTYLE"simulator-x86_64/contrib/x86_64-"$OSSTYLE"simulator/lib
        for i in `ls *.a`
        do
            CONTRIBLIBS="$i $CONTRIBLIBS"
        done
        spopd
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

    # add missing destination folders based on module category names
    for i in $VLCMODULECATEGORYNAMES
    do
        mkdir install-$OSSTYLE/plugins/$i
    done

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
    spopd

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
        symbols=$(nm -g -arch $actual_arch ${VLCROOT}/install-$OSSTYLE/plugins/$file)
        entryname=$(get_symbol "$symbols" _)
        DEFINITIONS+="int $entryname (int (*)(void *, void *, int, ...), void *);\n";
        BUILTINS+=" $entryname,\n"
        LDFLAGS+="${VLCROOT}/install-$OSSTYLE/plugins/$file "
        info "...$entryname"
    done;

    # we only have ARM NEON modules for 32bit so this is limited to iOS
    if [ "$OSSTYLE" = "iphone" ]; then
        BUILTINS+="#ifdef __arm__\n"
        DEFINITIONS+="#ifdef __arm__\n"
        for file in $VLCNEONMODULES
        do
            symbols=$(nm -g -arch $actual_arch ${VLCROOT}/install-$OSSTYLE/plugins/$file)
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
}

while getopts "hvsfbdxntlk:a:e:" OPTION
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
         d)  CONFIGURATION="Release"
             DISABLEDEBUG=yes
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
             SDK_MIN=10.2
             OSVERSIONMINCFLAG=tvos
             OSVERSIONMINLDFLAG=tvos
             ;;
         x)
             MACOS=yes
             IOS=no
             BITCODE=no
             SDK_VERSION=`xcrun --sdk macosx --show-sdk-version`
             SDK_MIN=10.11
             OSVERSIONMINCFLAG=macosx
             OSVERSIONMINLDFLAG=macosx
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
            git clone https://git.videolan.org/git/vlc.git vlc
            info "Applying patches to vlc.git"
            cd vlc
            git checkout -B localBranch ${TESTEDHASH}
            git branch --set-upstream-to=origin/master localBranch
            git am ${ROOT_DIR}/libvlc/patches/*.patch
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
            git am ${ROOT_DIR}/libvlc/patches/*.patch
            cd ..
        fi
    fi

    spopd
fi

fetch_python3_path() {
    PYTHON3_PATH=$(echo /Library/Frameworks/Python.framework/Versions/3.*/bin | awk '{print $1;}')
    if [ ! -d "${PYTHON3_PATH}" ]; then
        PYTHON3_PATH=""
    fi
}

#
# Build time
#

out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
    info "Building tools"

    fetch_python3_path
    export PATH="${PYTHON3_PATH}:${VLCROOT}/extras/tools/build/bin:${VLCROOT}/contrib/${TARGET}/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    spushd ${VLCROOT}/extras/tools
    ./bootstrap
    make
    make .buildgas
    make .buildxz
    make .buildtar
    make .buildmeson
    make .buildninja
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
    build_universal_static_lib "iphone"
fi

info "all done"

if [ "$BUILD_STATIC_FRAMEWORK" != "no" ]; then
if [ "$TVOS" = "yes" ]; then
    info "Building static TVVLCKit.framework"

    lipo_libs=""
    platform=""
    if [ "$FARCH" = "all" ] || (! is_simulator_arch $FARCH);then
        platform="appletvos"
        buildxcodeproj MobileVLCKit "TVVLCKit" ${platform}
        lipo_libs="$lipo_libs ${CONFIGURATION}-appletvos/libTVVLCKit.a"
    fi
    if [ "$FARCH" = "all" ] || (is_simulator_arch $arch);then
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
    cp -pr ${CONFIGURATION}-${platform}/Modules TVVLCKit.framework/Modules
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
    cp -pr ${CONFIGURATION}-${platform}/Modules MobileVLCKit.framework/Modules
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
