#!/bin/sh
# Copyright (C) Mike JS. Choi, 2018
# Copyright (C) 2018 VLC authors and VideoLAN

set -e

error()
{
  local red="\033[31m"
  local normal="\033[0m"
  echo "${red}error:${normal} $1"
}

ASSET_DIR="Assets"

PWD=$(pwd | xargs basename);

if [ ${PWD} = "vlckit" ] || [ ${PWD} = "project" ] ; then
  cd Tests
elif [ ${PWD} != "Tests" ]; then
  error "Running program from unknown directory. Please move to project's root directory; vlckit"
  exit 1
fi

if [ -d ${ASSET_DIR}/.git ]; then
  cd ${ASSET_DIR}
  git reset --hard
  git pull origin master
else
  git clone https://code.videolan.org/videolan/TestAssets.git ${ASSET_DIR}

  if [ $? -ne 0 ]; then
    error "Please remove all files in vlckit/Tests/${ASSET_DIR} and try again"
    exit 1
  fi
fi
