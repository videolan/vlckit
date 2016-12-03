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

MOBILE=no
TV=no
VERBOSE=no
USEZIP=no

usage()
{
cat << EOF
usage: $0 [options]

Package VLCKit

  By default, VLCKit for macOS will be packaged as a disk-image.
  You can use the options below to package a different flavor of VLCKit
  or/and to store the binaries in a zip file instead.

OPTIONS:
   -h            Show some help
   -v            Be verbose
   -m            Package MobileVLCKit
   -t            Package TVVLCKit
   -z            Use zip file format
EOF

}

while getopts "hvmtz" OPTION
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
             MOBILE=yes
             ;;
         t)
             MOBILE=yes
             TV=yes
             ;;
         z)
             USEZIP=yes
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

DMGFOLDERNAME="VLCKit - binary package"
DMGITEMNAME="VLCKit-REPLACEWITHVERSION"

if [ "$USEZIP" = "yes" ]; then
    DMGFOLDERNAME="VLCKit-binary"
fi

if [ "$MOBILE" = "yes" ]; then
    if [ "$USEZIP" = "yes" ]; then
        DMGFOLDERNAME="MobileVLCKit-binary"
    else
        DMGFOLDERNAME="MobileVLCKit - binary package"
    fi
    DMGITEMNAME="MobileVLCKit-REPLACEWITHVERSION"
fi
if [ "$TV" = "yes" ]; then
    if [ "$USEZIP" = "yes" ]; then
        DMGFOLDERNAME="TVVLCKit-binary"
    else
        DMGFOLDERNAME="TVVLCKit - binary package"
    fi
    DMGITEMNAME="TVVLCKit-REPLACEWITHVERSION"
fi

info "checking for distributable binary package"

spushd ${root}
if [ "$MOBILE" = "no" ]; then
    if [ ! -e "build/Release/VLCKit.framework" ]; then
        info "VLCKit not found for distribution, creating..."
        ./buildVLCKit.sh
    fi
else
    if [ "$TV" = "yes" ]; then
        if [ ! -e "build/TVVLCKit.framework" ]; then
            info "TVVLCKit not found for distribution, creating... this will take long"
            ./buildMobileVLCKit.sh -f -t
        fi
    else
        if [ ! -e "build/MobileVLCKit.framework" ]; then
            info "MobileVLCKit not found for distribution, creating... this will take long"
            ./buildMobileVLCKit.sh -f
        fi
    fi
fi

info "Deleting previous data"
rm -rf "${DMGFOLDERNAME}"

info "Collecting items"
mkdir -p "${DMGFOLDERNAME}"
mkdir -p "${DMGFOLDERNAME}/Sample Code"
if [ "$MOBILE" = "no" ]; then
    cp -R build/Release/VLCKit.framework "${DMGFOLDERNAME}"
    cp -R Examples/macOS/* "${DMGFOLDERNAME}/Sample Code"
    cp -R doc "${DMGFOLDERNAME}"
    cp COPYING "${DMGFOLDERNAME}"
else
    if [ "$TV" = "yes" ]; then
        cp -R build/TVVLCKit.framework "${DMGFOLDERNAME}"
    else
        cp -R build/MobileVLCKit.framework "${DMGFOLDERNAME}"
        cp -R Examples/iOS/* "${DMGFOLDERNAME}/Sample Code"
    fi
    cp -R doc "${DMGFOLDERNAME}"
    cp COPYING "${DMGFOLDERNAME}"
fi
cp NEWS "${DMGFOLDERNAME}"
spushd "${DMGFOLDERNAME}"
mv NEWS NEWS.txt
mv COPYING COPYING.txt
spopd
rm -f ${DMGITEMNAME}-rw.dmg

if [ "$USEZIP" = "no" ]; then
info "Creating disk-image"
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
    info "Creating zip-archive"
    zip -y -r ${DMGITEMNAME}.zip "${DMGFOLDERNAME}"
fi

spopd

info "Distributable package created"
