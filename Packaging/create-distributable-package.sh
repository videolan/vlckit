#!/bin/sh
set -e

info()
{
    local green="\033[1;32m"
    local normal="\033[0m"
    echo "[${green}Package${normal}] $1"
}

spushd()
{
    pushd "$1" > /dev/null
}

spopd()
{
    popd > /dev/null
}

IOS=no
TVOS=no
MACOS=no
XROS=no
WATCHOS=no
BUILDFORALL=no
VERBOSE=no
USEZIP=no
USECOMPRESSEDARCHIVE=yes
USEDMG=no

usage()
{
cat << EOF
usage: $0 [options]

Package VLCKit

  By default, VLCKit will be packaged as a tar.xz archive.
  You can use the options below to package a different flavor of VLCKit
  or/and to store the binaries in a zip or a dmg file instead.

OPTIONS:
   -h            Show some help
   -v            Be verbose
   -x            Package VLCKit for macOS
   -m            Package VLCKit for iOS
   -t            Package VLCKit for tvOS
   -i            Package VLCKit for xrOS
   -w            Package VLCKit for watchOS
   -a            Package VLCKit for all enabled OS
   -z            Use zip file format
   -d            Use dmg file format
EOF

}

while getopts "hvmxiwtza" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         m)
             IOS=yes
             ;;
         t)
             TVOS=yes
             ;;
         i)
             XROS=yes
             ;;
         w)
             WATCHOS=yes
             ;;
         x)
             MACOS=yes
             ;;
         a)
             BUILDFORALL=yes
             ;;
         z)
             USEZIP=yes
             ;;
         z)
             USEDMG=yes
             USECOMPRESSEDARCHIVE=no
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

root=`dirname $0`/../

DMGFOLDERNAME=""
DMGITEMNAME=""

if [ "$MACOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-macOS-binary"
    else
        DMGFOLDERNAME="VLCKit for macOS - binary package"
    fi
    DMGITEMNAME="VLCKit-macOS-REPLACEWITHVERSION"
fi
if [ "$IOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-iOS-binary"
    else
        DMGFOLDERNAME="VLCKit for iOS - binary package"
    fi
    DMGITEMNAME="VLCKit-iOS-REPLACEWITHVERSION"
fi
if [ "$TVOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-tvOS-binary"
    else
        DMGFOLDERNAME="VLCKit for tvOS - binary package"
    fi
    DMGITEMNAME="VLCKit-tvOS-REPLACEWITHVERSION"
fi
if [ "$XROS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-xrOS-binary"
    else
        DMGFOLDERNAME="VLCKit for xrOS - binary package"
    fi
    DMGITEMNAME="VLCKit-xrOS-REPLACEWITHVERSION"
fi
if [ "$WATCHOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-watchOS-binary"
    else
        DMGFOLDERNAME="VLCKit for watchOS - binary package"
    fi
    DMGITEMNAME="VLCKit-watchOS-REPLACEWITHVERSION"
fi
if [ "$BUILDFORALL" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-binary"
    else
        DMGFOLDERNAME="VLCKit - binary package"
    fi
    DMGITEMNAME="VLCKit-REPLACEWITHVERSION"
fi

info "checking for distributable binary package"

BUILD_DIR=`pwd`/build
frameworks=""

spushd ${root}
if [ "$MACOS" = "yes" ]; then
    if [ ! -e "build/macOS/VLCKit.xcframework" ]; then
        info "VLCKit for macOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -x -f
    fi
    dsymfolder=$BUILD_DIR/VLCKit-macosx.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-macosx.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
fi
if [ "$TVOS" = "yes" ]; then
    if [ ! -e "build/tvOS/VLCKit.xcframework" ]; then
        info "VLCKit for tvOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -f -t
    fi
    dsymfolder=$BUILD_DIR/VLCKit-appletvsimulator.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-appletvsimulator.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
    dsymfolder=$BUILD_DIR/VLCKit-appletvos.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-appletvos.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
fi
if [ "$IOS" = "yes" ]; then
    if [ ! -e "build/iOS/VLCKit.xcframework" ]; then
        info "VLCKit for iOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -f
    fi
    dsymfolder=$BUILD_DIR/VLCKit-iphonesimulator.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-iphonesimulator.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
    dsymfolder=$BUILD_DIR/VLCKit-iphoneos.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-iphoneos.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
fi
if [ "$XROS" = "yes" ]; then
    if [ ! -e "build/xrOS/VLCKit.xcframework" ]; then
        info "VLCKit for xrOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -i -f
    fi
    dsymfolder=$BUILD_DIR/VLCKit-xrsimulator.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-xrsimulator.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
    dsymfolder=$BUILD_DIR/VLCKit-xros.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-xros.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
fi
if [ "$WATCHOS" = "yes" ]; then
    if [ ! -e "build/watchOS/VLCKit.xcframework" ]; then
        info "VLCKit for xrOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -w -f
    fi
    dsymfolder=$BUILD_DIR/VLCKit-watchsimulator.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-watchsimulator.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
    dsymfolder=$BUILD_DIR/VLCKit-watchos.xcarchive/dSYMs/VLCKit.framework.dSYM
    frameworks="$frameworks -framework $BUILD_DIR/VLCKit-watchos.xcarchive/Products/Library/Frameworks/VLCKit.framework -debug-symbols $dsymfolder"
fi

info "Deleting previous data"
rm -rf "${DMGFOLDERNAME}"

info "Collecting items"
mkdir -p "${DMGFOLDERNAME}"
mkdir -p "${DMGFOLDERNAME}/Sample Code"
if [ "$BUILDFORALL" = "yes" ]; then
	PROJECT_DIR=`pwd`
	rm -rf build/VLCKit.xcframework
    xcodebuild -create-xcframework $frameworks -output build/VLCKit.xcframework
    cp -R build/VLCKit.xcframework "${DMGFOLDERNAME}"
else
if [ "$MACOS" = "yes" ]; then
    cp -R build/macOS/VLCKit.xcframework "${DMGFOLDERNAME}"
    cp -R Examples/macOS/* "${DMGFOLDERNAME}/Sample Code"
fi
if [ "$TVOS" = "yes" ]; then
    cp -R build/tvOS/VLCKit.xcframework "${DMGFOLDERNAME}"
fi
if [ "$XROS" = "yes" ]; then
    cp -R build/xrOS/VLCKit.xcframework "${DMGFOLDERNAME}"
fi
if [ "$WATCHOS" = "yes" ]; then
    cp -R build/watchOS/VLCKit.xcframework "${DMGFOLDERNAME}"
fi
if [ "$IOS" = "yes" ]; then
    cp -R build/iOS/VLCKit.xcframework "${DMGFOLDERNAME}"
    cp -R Examples/iOS/* "${DMGFOLDERNAME}/Sample Code"
fi
fi
cp -R Documentation "${DMGFOLDERNAME}"
cp COPYING "${DMGFOLDERNAME}"
cp NEWS "${DMGFOLDERNAME}"
spushd "${DMGFOLDERNAME}"
mv NEWS NEWS.txt
mv COPYING COPYING.txt
spopd

if [ "$USEDMG" = "yes" ]; then
    info "Creating disk-image"
    rm -f ${DMGITEMNAME}-rw.dmg
    hdiutil create -srcfolder "${DMGFOLDERNAME}" "${DMGITEMNAME}-rw.dmg" -scrub -format UDRW
    mkdir -p ./mount

    info "Moving file icons around"
    hdiutil attach -readwrite -noverify -noautoopen -mountRoot ./mount ${DMGITEMNAME}-rw.dmg
    if [ "$MOBILE" = "no" ]; then
    osascript Packaging/dmg_setup.scpt "${DMGFOLDERNAME}"
    else
        if [ "$TV" = "no" ]; then
            osascript Packaging/mobile_dmg_setup.scpt "${DMGFOLDERNAME}"
        fi
    fi
    hdiutil detach ./mount/"${DMGFOLDERNAME}"

    info "Compressing disk-image"
    rm -f ${DMGITEMNAME}.dmg
    hdiutil convert "${DMGITEMNAME}-rw.dmg" -format UDBZ -o "${DMGITEMNAME}.dmg"
    rm -f ${DMGITEMNAME}-rw.dmg
    rm -rf "${DMGFOLDERNAME}"
else
    if [ "$USEZIP" = "yes" ]; then
        info "Creating zip-archive"
        zip -y -r ${DMGITEMNAME}.zip "${DMGFOLDERNAME}"
    else
        info "Creating xz-archive"
        tar -cJf ${DMGITEMNAME}.tar.xz "${DMGFOLDERNAME}"
    fi
fi

spopd

info "Distributable package created"
