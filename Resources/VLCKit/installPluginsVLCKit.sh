#!/bin/sh
#
# Pre-Compile.sh
#
# Script that installs libvlc plugins inside VLCKit.

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

echo "running installPluginsVLCKit.sh"

TARGET_BUILD_DIR="${CONFIGURATION_BUILD_DIR}"
CONTENTS_FOLDER_PATH="VLCKit.framework/Versions/A"

if test "${ACTION}" != "build"; then
if test "${ACTION}" != "install"; then
    echo "This script is supposed to run from xcodebuild or Xcode"
    exit 1
fi
fi

lib="lib"
plugins="plugins"
share="share"
include="include"
target="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}"
target_lib="${target}/${lib}"            # Should we consider using a different well-known folder like shared resources?
target_plugins="${target}/${plugins}"    # Should we consider using a different well-known folder like shared resources?
target_share="${target}/${share}"        # Should we consider using a different well-known folder like shared resources?
linked_libs=""
prefix=".libs"
suffix="dylib"
num_archs=$(echo `echo $ARCHS | wc -w`)

##########################
# @function vlc_install_object(src_lib, dest_dir, type, lib_install_prefix, destination_name, suffix)
# @description Installs the specified library into the destination folder, automatically changes the references to dependencies
# @param src_lib     source library to copy to the destination directory
# @param dest_dir    destination directory where the src_lib should be copied to
vlc_install_object() {
    local src_lib=${1}
    local dest_dir=${2}
    local type=${3}
    local lib_install_prefix=${4}
    local destination_name=${5}
    local suffix=${6}

    if [ $type = "library" ]; then
        local install_name="@loader_path/lib"
    elif [ $type = "module" ]; then
        local install_name="@loader_path/plugins"
    fi
    if [ "$destination_name" != "" ]; then
        local lib_dest="$dest_dir/$destination_name$suffix"
        local lib_name=`basename $destination_name`
    else
        local lib_dest="$dest_dir/`basename $src_lib`$suffix"
        local lib_name=`basename $src_lib`
    fi

    if [ "x$lib_install_prefix" != "x" ]; then
        local lib_install_prefix="$lib_install_prefix"
    else
        local lib_install_prefix="@loader_path/../lib"
    fi

    if test ! -e ${src_lib}; then
        return
    fi

    if ( (test ! -e ${lib_dest}) || test ${src_lib} -nt ${lib_dest} ); then

        mkdir -p ${dest_dir}

        # Lets copy the library from the source folder to our new destination folder
        if [ "${type}" = "bin" ]; then
            install -m 755 ${src_lib} ${lib_dest}
        else
            install -m 644 ${src_lib} ${lib_dest}
        fi

        # Update the dynamic library so it will know where to look for the other libraries
        echo "Installing ${type} `basename ${lib_dest}`"

        if [ "${type}" = "library" ]; then
            # Change the reference of libvlc.1 stored in the usr directory to libvlc.dylib in the framework's library directory
            install_name_tool -id "${install_name}/${lib_name}" ${lib_dest} > /dev/null
        fi

        if [ "${type}" != "data" ]; then
            # Iterate through each installed library and modify the references to other dynamic libraries to match the framework's library directory
            for linked_lib in `otool -L ${lib_dest}  | grep '(' | sed 's/\((.*)\)//'`; do
                local name=`basename ${linked_lib}`
                case "${linked_lib}" in
                    */vlc_build_dir/* | */vlc_install_dir/* | *vlc* | */extras/contrib/*)
                        if test -e ${linked_lib}; then
                            install_name_tool -change "$linked_lib" "${lib_install_prefix}/${name}" "${lib_dest}"
                            linked_libs="${linked_libs} ${ref_lib}"
                            vlc_install_object ${linked_lib} ${target_lib} "library"
                        fi
                        ;;
                esac
            done
        fi
     fi
}
# @function vlc_install_object
##########################


##########################
# Create a symbolic link in the root of the framework
mkdir -p ${target_lib}
mkdir -p ${target_plugins}

if [ "$RELEASE_MAKEFILE" != "yes" ] ; then
    pushd `pwd` > /dev/null
    cd ${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}

    ln -sf Versions/Current/${lib} .
    ln -sf Versions/Current/${plugins} .
    ln -sf Versions/Current/${include} .
    ln -sf Versions/Current/${share} .

    popd > /dev/null
fi

##########################
# Build the lib folder (Same as VLCKit.framework/lib in Makefile)
echo "Building lib folder..."

spushd ${VLC_SRC_DIR}/install-macos/lib

vlc_install_object libvlccore.*.dylib ${target_lib} "library"
vlc_install_object libvlc.*.dylib ${target_lib} "library"

spopd # install-macos/lib

spushd ${target_lib}

ln -s libvlc.* libvlc.dylib
ln -s libvlccore.* libvlccore.dylib

spopd # ${target_lib}

##########################
# Build the plugins folder (Same as VLCKit.framework/plugins in Makefile)
echo "Building plugins folder..."
# Figure out what plugins are available to install

spushd ${VLC_SRC_DIR}/install-macos/lib/vlc/plugins
for folder in `ls -d */`
do
    cd ${folder}
    ITERDIR=`pwd`
    for i in `ls *.dylib`
    do
        vlc_install_object ${ITERDIR}/$i ${target_plugins} "module"
    done
    cd ..
done
spopd # install-macos/lib/vlc/plugins

exit 0

##########################
# Build the share folder
echo "Building share folder..."
echo ${VLC_BUILD_DIR}
pbxcp="cp -R -L"
mkdir -p ${target_share}
if test -d ${VLC_BUILD_DIR}/share/lua; then
    $pbxcp ${VLC_BUILD_DIR}/share/lua ${target_share}
fi
if test -d ${main_build_dir}/share/lua; then
    $pbxcp ${main_build_dir}/share/lua ${target_share}
fi
