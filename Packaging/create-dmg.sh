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
VERBOSE=no
USEZIP=no

usage()
{
cat << EOF
usage: $0 [options]

Build vlc in the current directory

OPTIONS:
   -h            Show some help
   -v            Be verbose
   -m            Package MobileVLCKit
   -z            Use zip file format
EOF

}

while getopts "hvmz" OPTION
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

if [ "$MOBILE" = "yes" ]; then
if [ "$USEZIP" = "yes" ]; then
    DMGFOLDERNAME="MobileVLCKit-binary"
else
    DMGFOLDERNAME="MobileVLCKit - binary package"
fi
    DMGITEMNAME="MobileVLCKit-REPLACEWITHVERSION"
fi

info "checking for distributable binary package"

spushd ${root}
if [ "$MOBILE" = "no" ]; then
if [ ! -e "VLCKit" ]; then
    info "VLCKit not found for distribution, creating..."
    if [ "$VERBOSE" = "yes" ]; then
        make VLCKit V=1
    else
        make VLCKit
    fi
fi
else
if [ ! -e "build/MobileVLCKit.framework" ]; then
    info "MobileVLCKit not found for distribution, creating... this will take long"
    ./buildMobileVLCKit.sh -f
fi
fi

if [ ! -e "${DMGFOLDERNAME}" ]; then
info "Collecting items"
mkdir -p "${DMGFOLDERNAME}"
mkdir -p "${DMGFOLDERNAME}/Sample Code"
if [ "$MOBILE" = "no" ]; then
cp -R VLCKit/* "${DMGFOLDERNAME}"
cp -R Examples_OSX/* "${DMGFOLDERNAME}/Sample Code"
else
cp -R build/MobileVLCKit.framework "${DMGFOLDERNAME}"
cp -R Examples_iOS/* "${DMGFOLDERNAME}/Sample Code"
cp COPYING "${DMGFOLDERNAME}"
fi
cp NEWS "${DMGFOLDERNAME}"
spushd "${DMGFOLDERNAME}"
mv NEWS NEWS.txt
mv COPYING COPYING.txt
spopd
rm -f ${DMGITEMNAME}-rw.dmg
fi

if [ "$USEZIP" = "no" ]; then
info "Creating disk-image"
hdiutil create -srcfolder "${DMGFOLDERNAME}" "${DMGITEMNAME}-rw.dmg" -scrub -format UDRW
mkdir -p ./mount

info "Moving file icons around"
hdiutil attach -readwrite -noverify -noautoopen -mountRoot ./mount ${DMGITEMNAME}-rw.dmg
if [ "$MOBILE" = "no" ]; then
osascript Packaging/dmg_setup.scpt "${DMGFOLDERNAME}"
else
osascript Packaging/mobile_dmg_setup.scpt "${DMGFOLDERNAME}"
fi
hdiutil detach ./mount/"${DMGFOLDERNAME}"

info "Compressing disk-image"
rm -f ${DMGITEMNAME}.dmg
hdiutil convert "${DMGITEMNAME}-rw.dmg" -format UDBZ -o "${DMGITEMNAME}.dmg"
rm -f ${DMGITEMNAME}-rw.dmg
rm -rf "${DMGFOLDERNAME}"
else
info "Creating zip-archive"
zip -r ${DMGITEMNAME}.zip "${DMGFOLDERNAME}"
fi

spopd

info "Distributable package created"
