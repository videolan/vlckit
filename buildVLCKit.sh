#!/bin/sh
# Copyright (C) Pierre d'Herbemont, 2010
# Copyright (C) Felix Paul Kühne, 2012-2016

set -e

FORWARDEDOPTIONS=""

if [ -z "$MAKE_JOBS" ]; then
    CORE_COUNT=`sysctl -n machdep.cpu.core_count`
    let MAKE_JOBS=$CORE_COUNT+1
fi

usage()
{
cat << EOF
This is a LEGACY WRAPPER to retain compatibility
------> UPGRADE YOUR BUILD SYSTEM <------
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

while getopts "hvwsfbdntlk:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             FORWARDEDOPTIONS+=" -v"
             ;;
         d)
             FORWARDEDOPTIONS+=" -d"
             ;;
         w)
             FORWARDEDOPTIONS+=" -w"
             ;;
         n)
             FORWARDEDOPTIONS+=" -n"
             ;;
         l)
             FORWARDEDOPTIONS+=" -l"
             ;;
         k)
             FORWARDEDOPTIONS+=" -k" $OPTARG
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

./buildMobileVLCKit.sh -x $FORWARDEDOPTIONS

exit 0
