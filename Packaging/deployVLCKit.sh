#!/usr/bin/env bash

set -e

CLEAN=yes
DEPLOY_MOBILEVLCKIT=no
DEPLOY_TVVLCKIT=no

BUILD_MOBILEVLCKIT="./buildMobileVLCKit.sh -vf"
CREATE_DISTRIBUTION_PACKAGE="./create-distributable-package.sh -z"
STABLE_UPLOAD_URL="https://download.videolan.org/cocoapods/unstable/"

usage()
{
cat << EOF
usage: $0 [options] version

OPTIONS
    -d      Disable cleaning of build directory
    -m      Deploy MobileVLCKit
    -t      Deploy TVVLCKit
EOF
}

# Note: Need argument error handling on: version option, the options are ignored
while getopts "hdmt:" OPTION
do
     case $OPTION in
         h)
            usage
            exit 1
            ;;
         d)
            CLEAN=no
            ;;
         m)
            DEPLOY_MOBILEVLCKIT=yes
            ;;
         t)
            DEPLOY_TVVLCKIT=yes
            ;;
         \?)
            usage
            exit 1
            ;;
     esac
done
shift $((OPTIND-1))

VERSION=$1
if [[ -z $VERSION ]]; then
    echo "Please specify a version."
    exit 1
fi

ROOT_DIR="$(dirname "$(pwd)")"
UPLOAD_URL=""
VLC_HASH=""
VLCKIT_HASH=""
DISTRIBUTION_PACKAGE=""
DISTRIBUTION_PACKAGE_SHA=""

##################
# Helper methods #
##################

spushd()
{
    pushd $1 2>&1 /dev/null
}

spopd()
{
    popd 2>&1> /dev/null
}

log()
{
    local green='\033[1;32m'
    local orange='\033[1;91m'
    local red='\033[1;31m'
    local normal='\033[0m'
    local color=$green
    local msgType=$1

    if [ "$1" = "Warning" ]; then
        color=$orange
        msgType="Warning"
    elif [ "$1" = "Error" ]; then
        color=$red
        msgType="Error"
    fi
    echo -e "[${color}${msgType}${normal}] $2"
}

clean()
{
    log "Info" "Starting the build purge..."
    pwd
    if [ -d "build" ]; then
        rm -rf "$ROOT_DIR/build"
    else
        log "warning" "Build directory not found!"
    fi
    log "Info" "Build directory cleaned"
}

buildMobileVLCKit()
{
    log "Info" "Staring MobileVLCKit build..."
    if ! $BUILD_MOBILEVLCKIT; then
        log "error" "MobileVLCKit build failed"
        exit 1
    fi
    log "Info" "MobileVLCKit build finished!"
}

getVLCHashes()
{
    VLC_HASH=""
    VLCKIT_HASH=$(git rev-parse --short HEAD)

    spushd "libvlc/vlc"
        VLC_HASH=$(git rev-parse --short HEAD)
    spopd #libvlc/vlc
}

renamePackage()
{
    local target=""

    if [ "$1" = "-m" ]; then
        target="MobileVLCKit"
    else
        target="TVVLCKit"
    fi

    getVLCHashes

    local packageName="${target}-REPLACEWITHVERSION.zip"
    # git rev-parse --short HEAD in vlckit et vlc
    if [ -f $packageName ]; then
        DISTRIBUTION_PACKAGE="${target}-${VERSION}-${VLCKIT_HASH}-${VLC_HASH}.zip"
        mv $packageName "$DISTRIBUTION_PACKAGE"
        log "Info" "Finished renaming package!"
    fi
}

packageBuild()
{
    spushd "Packaging"
        if ! $CREATE_DISTRIBUTION_PACKAGE "$1"; then
            log "Error" "Failed to package!"
            exit 1
        fi
    spopd #Packaging
}

getSHA()
{
    log "Info" "Getting SHA from distrubition package..."
    DISTRIBUTION_PACKAGE_SHA=$(shasum -a 256 "$DISTRIBUTION_PACKAGE" | cut -d " " -f 1 )
}

bumpPodspec()
{
    local podVersion="s.version   = '${VERSION}'"
    local uploadURL=":http => '${UPLOAD_URL}${DISTRIBUTION_PACKAGE}'"
    local podSHA=":sha256 => '${DISTRIBUTION_PACKAGE_SHA}'"

    # NOTE: sed -i '' because macOS
    sed -i '' 's#.*s.version.*#'"  ${podVersion}"'#' "$1"
    sed -i '' 's#.*:http.*#'"    ${uploadURL}",'#' "$1"
    sed -i '' 's#.*sha256.*#'"    ${podSHA}"'#' "$1"
}


gitCommit()
{
    local podspec="$1"

    git add "$podspec"
    git commit -m "Update podspecs"
}

podDeploy()
{
    local podspec=""

    if [ "$DEPLOY_MOBILEVLCKIT" = "yes" ]; then
        podspec="MobileVLCKit-unstable.podspec"
    else
        podspec="TVVLCKit-unstable.podspec"
    fi

    spushd "Packaging/podspecs"
        log "Info" "Starting podspec update..."
        bumpPodspec $podspec
        log "Info" "Starting pod spec lint..."
        pod spec lint --verbose $podspec
        log "Info" "Starting pod trunk push..."
        pod trunk push $podspec
        gitCommit $podspec
    spopd #Packaging/podspecs
}

checkIfExistOnRemote()
{
    if ! curl --head --silent "$1" | head -n 1 | grep -q 404; then
        return 0
    else
        return 1
    fi
}

uploadPackage()
{
    # handle upload of distribution package.

    if [ "$DISTRIBUTION_PACKAGE" = "" ]; then
        log "Error" "Distribution package not found!"
        exit 1
    fi

    while read -r -n 1 -p "The package is ready please upload it to \"${UPLOAD_URL}\", press a key to continue when uploaded [y,a,r]: " response
    do
        printf '\r'
        case $response in
            y)
                log "Info" "Checking for: '${UPLOAD_URL}${DISTRIBUTION_PACKAGE}'..."
                if checkIfExistOnRemote "${UPLOAD_URL}${DISTRIBUTION_PACKAGE}"; then
                    log "Info" "Package found on ${UPLOAD_URL}!"
                    break
                fi
                log "Warning" "Package not found on ${UPLOAD_URL}!"
                ;;
            a)
                log "Warning" "Aborting deployment process!"
                exit 1
                ;;
            *)
                ;;
        esac
    done
}

##################
# Command Center #
##################

if [ "$CLEAN" = "yes" ]; then
    clean
fi

options=""
if [ "$DEPLOY_MOBILEVLCKIT" = "yes" ]; then
    options="-m"
elif [ "$DEPLOY_TVVLCKIT" = "yes" ]; then
    options="-t"
fi

UPLOAD_URL=${STABLE_UPLOAD_URL}


spushd "$ROOT_DIR"
    # Note: the current packaging script is building vlckit(s) if not found.
    buildMobileVLCKit
    packageBuild $options
    renamePackage $options
    getSHA
    uploadPackage
    podDeploy

spopd #ROOT_DIR
