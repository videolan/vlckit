#!/usr/bin/env bash

set -e

CLEAN=yes
DEPLOY_MOBILEVLCKIT=no
DEPLOY_TVVLCKIT=no
DEPLOY_MACOSVLCKIT=no
TEST_MODE=no

BUILD_MOBILEVLCKIT="./compileAndBuildVLCKit.sh -vf"
CREATE_DISTRIBUTION_PACKAGE="./create-distributable-package.sh"
STABLE_UPLOAD_URL="https://download.videolan.org/cocoapods/unstable/"
MOBILE_PODSPEC="MobileVLCKit-unstable.podspec"
TV_PODSPEC="TVVLCKit-unstable.podspec"
MACOS_PODSPEC="VLCKit.podspec"

# Note: create-distributable-package script is building VLCKit(s) if not found.
# Note: by default, VLCKit will be build if no option is passed.

usage()
{
cat << EOF
usage: $0 [options]

OPTIONS
    -d      Disable cleaning of build directory
    -m      Deploy MobileVLCKit
    -t      Deploy TVVLCKit
    -x      Deploy VLCKit for macOS
    -l      Start test for build phases
EOF
}

while getopts "hdmtlx" OPTION
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
         x)
            DEPLOY_MACOSVLCKIT=yes
            ;;
         l)
            TEST_MODE=yes
            ;;
         \?)
            usage
            exit 1
            ;;
     esac
done
shift "$((OPTIND-1))"

VERSION=""
VERSION_DELIMITER="3.0.1a"
ROOT_DIR="$(dirname "$(pwd)")"
UPLOAD_URL=""
VLC_HASH=""
VLCKIT_HASH=""
DISTRIBUTION_PACKAGE=""
DISTRIBUTION_PACKAGE_SHA=""
TARGET=""

##################
# Helper methods #
##################

spushd()
{
    pushd $1 2>&1> /dev/null
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
    log "Info" "Starting cleaning..."
    if [ -d "build" ]; then
        rm -rf "$ROOT_DIR/build"
    else
        log "Warning" "Build directory not found!"
    fi
    log "Info" "Build directory cleaned"
}

buildMobileVLCKit()
{
    log "Info" "Starting MobileVLCKit build..."

    local option="$1"

    if ! $BUILD_MOBILEVLCKIT $option; then
        log "Error" "MobileVLCKit build failed"
        rm -fr "build/"
        exit 1
    fi
    log "Info" "MobileVLCKit build finished!"
}

getVLCHashes()
{
    VLCKIT_HASH=$(git rev-parse --short HEAD)
    VERSION=$(git describe --tags HEAD)
    VLC_HASH=`awk -F'"' '/TESTEDHASH=/ {print $2}' compileAndBuildVLCKit.sh`
}

renamePackage()
{
    if [ "$1" = "-m" ]; then
        TARGET="VLCKit-iOS"
    elif [ "$1" = "-t" ]; then
        TARGET="VLCKit-tvOS"
    elif [ "$1" = "-x" ]; then
        TARGET="VLCKit-macOS"
    fi
    getVLCHashes

    local packageName="${TARGET}-REPLACEWITHVERSION.tar.xz"

    if [ -f $packageName ]; then
        DISTRIBUTION_PACKAGE="${TARGET}-${VERSION}-${VLCKIT_HASH}-${VLC_HASH}.tar.xz"
        mv $packageName "$DISTRIBUTION_PACKAGE"
        log "Info" "Finished renaming package with name: ${DISTRIBUTION_PACKAGE}"
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
    DISTRIBUTION_PACKAGE_SHA=$(shasum -a 256 "$DISTRIBUTION_PACKAGE" | cut -d " " -f 1)
    log "Info" "Distribution package checksum: ${DISTRIBUTION_PACKAGE_SHA}"
}

bumpPodspec()
{
    local podVersion="s.version   = '${VERSION}'"
    local uploadURL=":http => '${UPLOAD_URL}${DISTRIBUTION_PACKAGE}'"
    local podSHA=":sha256 => '${DISTRIBUTION_PACKAGE_SHA}'"

    perl -i -pe's#s.version.*#'"${podVersion}"'#g' $1
    perl -i -pe's#:http.*#'"${uploadURL},"'#g' $1
    perl -i -pe's#:sha256.*#'"${podSHA}"'#g' $1
}

gitCommit()
{
    local podspec="$1"

    git add "$podspec"
    git commit -m "${podspec}: Update version to ${VERSION}"
}

startPodTesting()
{
    # Testing on a side even though it ressembles podDeploy() for future tests.
    log "Info" "Starting local tests..."
    spushd "Packaging/podspecs"
        if bumpPodspec $CURRENT_PODSPEC && \
           pod spec lint --verbose $CURRENT_PODSPEC ; then
            log "Info" "Testing succesfull!"
        else
            log "Error" "Testing failed."
        fi
        git checkout $CURRENT_PODSPEC
   spopd #Packaging/podspecs
   rm ${DISTRIBUTION_PACKAGE}
   rm -rf ${TARGET}-binary
   log "Warning" "All files generated during tests have been removed."
}

podDeploy()
{
   log "Info" "Starting podspec operations..."
    spushd "Packaging/podspecs"
        if bumpPodspec $CURRENT_PODSPEC && \
           pod spec lint --verbose $CURRENT_PODSPEC && \
           pod trunk push $CURRENT_PODSPEC && \
           gitCommit $CURRENT_PODSPEC; then
            log "Info" "Podpsec operations successfully finished!"
        else
            git checkout $CURRENT_PODSPEC
            log "Error" "Podspec operations failed."
        fi
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

setCurrentPodspec()
{
    # Addded extra precision of target to protect against future targets
    if [ "$DEPLOY_MOBILEVLCKIT" = "yes" ]; then
        CURRENT_PODSPEC=$MOBILE_PODSPEC
    elif [ "$DEPLOY_TVVLCKIT" = "yes" ]; then
        CURRENT_PODSPEC=$TV_PODSPEC
    elif [ "DEPLOY_MACOSVLCKIT" = "yes" ]; then
        CURRENT_PODSPEC=$MACOS_PODSPEC
    fi
}

podOperations()
{
    if [ "$TEST_MODE" = "yes" ]; then
        startPodTesting
    else
        podDeploy
        log "Info" "Removing distribution package ${DISTRIBUTION_PACKAGE} and build directory ${TARGET}-binary."
        rm ${DISTRIBUTION_PACKAGE}
        rm -rf ${TARGET}-binary
    fi
}
##################
# Command Center #
##################

# Currently, mobile and tv cannot be deployed at the same time.
if [ "$DEPLOY_MOBILEVLCKIT" = "yes" ] && [ "$DEPLOY_TVVLCKIT" = "yes" ]; then
    log "Error" "Cannot depoy MobileVLCKit and TVVLCKit at the same time!"
    exit 1
fi

if [ "$CLEAN" = "yes" ]; then
    clean
fi

# Used to send parameter to the other scripts.
options=""
if [ "$DEPLOY_MOBILEVLCKIT" = "yes" ]; then
    options="-m"
elif [ "$DEPLOY_TVVLCKIT" = "yes" ]; then
    options="-t"
elif [ "$DEPLOY_MACOSVLCKIT" = "yes" ]; then
    options="-x"
fi

UPLOAD_URL=${STABLE_UPLOAD_URL}

spushd "$ROOT_DIR"
    buildMobileVLCKit $options
    setCurrentPodspec
    packageBuild $options
    renamePackage $options
    getSHA
    # Note: Disable uploading and podoperations for now.
    #uploadPackage
    #podOperations
spopd #ROOT_DIR
