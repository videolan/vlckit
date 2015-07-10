#!/bin/sh
# Copyright (C) Pierre d'Herbemont, 2010
# Copyright (C) Felix Paul Kühne, 2012-2015

set -e

BUILD_DEVICE=yes
BUILD_SIMULATOR=yes
BUILD_STATIC_FRAMEWORK=no
SDK=`xcrun --sdk iphoneos --show-sdk-version`
SDK_MIN=7.0
VERBOSE=no
CONFIGURATION="Release"
NONETWORK=no
SKIPLIBVLCCOMPILATION=no
SCARY=yes

TESTEDHASH=bfd01076

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
   -w       Build a limited stack of non-scary libraries only
   -y		Build universal static libraries
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

    local architectures=""
    if [ "$PLATFORM" = "iphonesimulator" ]; then
        architectures="i386 x86_64"
    else
        architectures="armv7 armv7s arm64"
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
               > ${out}
}

while getopts "hvwsfdnlk:" OPTION
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

mkdir -p MobileVLCKit/ImportedSources

spushd MobileVLCKit/ImportedSources

if [ "$NONETWORK" != "yes" ]; then
if ! [ -e vlc ]; then
git clone git://git.videolan.org/vlc.git vlc
info "Applying patches to vlc.git"
cd vlc
git checkout -B localBranch ${TESTEDHASH}
git branch --set-upstream-to=origin/master localBranch
git am ../../patches/*.patch
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
git am ../../patches/*.patch
cd ..
fi
fi

spopd

#
# Build time
#

buildMobileKit() {
    PLATFORM="$1"

    info "Building for $PLATFORM"

    spushd MobileVLCKit/ImportedSources

    if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
    spushd vlc/extras/package/ios
    info "Building vlc"
    args=""
    if [ "$VERBOSE" = "yes" ]; then
        args="${args} -v"
    fi
    if [ "$CONFIGURATION" = "Debug" ]; then
        args="${args} -d"
    fi
    if [ "$SCARY" = "no" ]; then
        args="${args} -w"
    fi
    if [ "$PLATFORM" = "iphonesimulator" ]; then
        args="${args} -s"
        ./build.sh -a i386 ${args} -k "${SDK}" && ./build.sh -a x86_64 ${args} -k "${SDK}"
    else
        ./build.sh -a armv7 ${args} -k "${SDK}" && ./build.sh -a armv7s ${args} -k "${SDK}" && ./build.sh -a aarch64 ${args} -k "${SDK}"
    fi

    spopd
    fi

    spopd # MobileVLCKit/ImportedSources

    info "Build for $PLATFORM completed"
}

if [ "$BUILD_DEVICE" != "no" ]; then
    buildMobileKit iphoneos
fi
if [ "$BUILD_SIMULATOR" != "no" ]; then
    buildMobileKit iphonesimulator
fi

DEVICEARCHS=""
SIMULATORARCHS=""

doVLCLipo() {
    FILEPATH="$1"
    FILE="$2"
    PLUGIN="$3"
    files=""

    info "...$FILEPATH$FILE"

    for i in $DEVICEARCHS
    do
        files="install-ios-OS/$i/lib/$FILEPATH$FILE $files"
    done

    for i in $SIMULATORARCHS
    do
        files="install-ios-Simulator/$i/lib/$FILEPATH$FILE $files"
    done

    if [ "$PLUGIN" != "no" ]; then
        lipo $files -create -output install-ios/plugins/$FILE
    else
        lipo $files -create -output install-ios/core/$FILE
    fi
}

doContribLipo() {
    LIBNAME="$1"
    files=""

    info "...$LIBNAME"

    for i in $DEVICEARCHS
    do
        if [ "$i" != "arm64" ]; then
            files="contrib/$i-apple-darwin11-$i/lib/$LIBNAME $files"
        else
            files="contrib/aarch64-apple-darwin11-aarch64/lib/$LIBNAME $files"
        fi
    done

    for i in $SIMULATORARCHS
    do
        files="contrib/$i-apple-darwin11-$i/lib/$LIBNAME $files"
    done

    lipo $files -create -output install-ios/contrib/$LIBNAME
}

get_symbol()
{
    echo "$1" | grep vlc_entry_$2|cut -d" " -f 3|sed 's/_vlc/vlc/'
}

info "building universal static libs"
PROJECT_DIR=`pwd`

# remove old module list
rm -f $PROJECT_DIR/MobileVLCKit/vlc-plugins.h
rm -f $PROJECT_DIR/MobileVLCKit/vlc-plugins.xcconfig

spushd MobileVLCKit/ImportedSources/vlc
rm -rf install-ios
mkdir install-ios
mkdir install-ios/core
mkdir install-ios/contrib
mkdir install-ios/plugins
spopd # vlc

spushd MobileVLCKit/ImportedSources/vlc/install-ios-OS
for i in `ls .`
do
	DEVICEARCHS="$DEVICEARCHS $i"
done
spopd # vlc-install-ios-OS

spushd MobileVLCKit/ImportedSources/vlc/install-ios-Simulator
for i in `ls .`
do
	SIMULATORARCHS="$SIMULATORARCHS $i"
done
spopd # vlc-install-ios-Simulator

# arm64 got the lowest number of modules
VLCMODULES=""
spushd MobileVLCKit/ImportedSources/vlc/install-ios-OS/arm64/lib/vlc/plugins
for i in `ls *.a`
do
	VLCMODULES="$i $VLCMODULES"
done
spopd # vlc/install-ios-OS/arm64/lib/vlc/plugins

# collect ARMv7/s specific neon modules
VLCNEONMODULES=""
spushd MobileVLCKit/ImportedSources/vlc/install-ios-OS/armv7/lib/vlc/plugins
for i in `ls *.a | grep neon`
do
	VLCNEONMODULES="$i $VLCNEONMODULES"
done
spopd # vlc/install-ios-OS/armv7/lib/vlc/plugins

spushd MobileVLCKit/ImportedSources/vlc

# lipo all the vlc libraries and its plugins
doVLCLipo "" "libvlc.a" "no"
doVLCLipo "" "libvlccore.a" "no"
doVLCLipo "vlc/" "libcompat.a" "no"
for i in $VLCMODULES
do
	doVLCLipo "vlc/plugins/" $i "yes"
done

# lipo contrib libraries
CONTRIBLIBS=""
spushd contrib/armv7-apple-darwin11-armv7/lib
for i in `ls *.a`
do
	CONTRIBLIBS="$i $CONTRIBLIBS"
done
spopd # contrib/armv7-apple-darwin11-armv7/lib
for i in $CONTRIBLIBS
do
	doContribLipo $i
done

# lipo the remaining NEON plugins
DEVICEARCHS="armv7 armv7s"
SIMULATORARCHS=""
for i in $VLCNEONMODULES
do
	doVLCLipo "vlc/plugins/" $i "yes"
done

# create module list
info "creating module list"
echo "// This file is autogenerated by $(basename $0)\n\n" > $PROJECT_DIR/MobileVLCKit/vlc-plugins.h
echo "// This file is autogenerated by $(basename $0)\n\n" > $PROJECT_DIR/MobileVLCKit/vlc-plugins.xcconfig

# arm64 got the lowest number of modules
BUILTINS="const void *vlc_static_modules[] = {\n"; \

LDFLAGS=""
DEFINITIONS=""

# add contrib libraries to LDFLAGS
for file in $CONTRIBLIBS
do
	LDFLAGS+="\$(PROJECT_DIR)/MobileVLCKit/ImportedSources/vlc/install-ios/contrib/$file "
done

for file in $VLCMODULES
do
	symbols=$(nm -g -arch armv7 install-ios/plugins/$file)
	entryname=$(get_symbol "$symbols" _)
	DEFINITIONS+="int $entryname (int (*)(void *, void *, int, ...), void *);\n";
	BUILTINS+=" $entryname,\n"
	LDFLAGS+="\$(PROJECT_DIR)/MobileVLCKit/ImportedSources/vlc/install-ios/plugins/$file "
	info "...$entryname"
done;

BUILTINS+="#ifdef __arm__\n"
DEFINITIONS+="#ifdef __arm__\n"
for file in $VLCNEONMODULES
do
	symbols=$(nm -g -arch armv7 install-ios/plugins/$file)
	entryname=$(get_symbol "$symbols" _)
	DEFINITIONS+="int $entryname (int (*)(void *, void *, int, ...), void *);\n";
	BUILTINS+=" $entryname,\n"
	LDFLAGS+="\$(PROJECT_DIR)/MobileVLCKit/ImportedSources/vlc/install-ios/plugins/$file "
	info "...$entryname"
done;
BUILTINS+="#endif\n"
DEFINITIONS+="#endif\n"

BUILTINS="$BUILTINS NULL\n};\n"

echo "$DEFINITIONS\n$BUILTINS" > $PROJECT_DIR/MobileVLCKit/vlc-plugins.h
echo "VLC_PLUGINS_LDFLAGS=$LDFLAGS" > $PROJECT_DIR/MobileVLCKit/vlc-plugins.xcconfig

spopd # vlc

info "all done"

if [ "$BUILD_STATIC_FRAMEWORK" != "no" ]; then
    info "Building static MobileVLCKit.framework"

    buildxcodeproj MobileVLCKit "MobileVLCKit" iphoneos
    buildxcodeproj MobileVLCKit "MobileVLCKit" iphonesimulator

    # Assumes both platforms were built currently
    spushd build
    rm -rf MobileVLCKit.framework && \
    mkdir MobileVLCKit.framework && \
    lipo -create Release-iphoneos/libMobileVLCKit.a \
                 Release-iphonesimulator/libMobileVLCKit.a \
              -o MobileVLCKit.framework/MobileVLCKit && \
    chmod a+x MobileVLCKit.framework/MobileVLCKit && \
    cp -pr Release-iphoneos/include/MobileVLCKit MobileVLCKit.framework/Headers
    spopd # build

    info "Build of static MobileVLCKit.framework completed"
fi
