# Rakefile
# Copyright (C) 2018 Mike JS Choi
# Copyright (C) 2018 VLC authors and VideoLAN
# $Id$
#
# Authors: Mike JS. Choi <mkchoi212 # icloud.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
#
# ------------------------------------------------------------- Constants ------

SDK_SIM = 'iphonesimulator11.3'
SDK_SIM_DEST = "'platform=iOS Simulator,name=iPhone 7,OS=11.3'"

SCHEME_IOS = 'MobileVLCKitTests'
PROJECT_IOS = 'MobileVLCKit.xcodeproj'

VLC_FLAGS_IOS = '-dva x86_64'

# ----------------------------------------------------------------- Tasks ------

desc 'Build VLCKit (iOS)'
task 'build:vlckit:ios' do
  puts 'Building VLCKit (iOS)'

  plugin_file = 'Resources/MobileVLCKit/vlc-plugins-iPhone.h'
  required_dirs = ['./libvlc/vlc/install-iPhoneSimulator', './libvlc/vlc/build-iPhoneSimulator']

  if File.exist?(plugin_file) && dirs_exist?(required_dirs)
    puts 'Found pre-existing build directory. Skipping build'
  else
    sh "./compileAndBuildVLCKit.sh #{VLC_FLAGS_IOS}"
  end
end

desc 'Run MobileVLCKit tests'
task 'test:ios' do
  puts 'Running tests for MobileVLCKit'
  sh "xcodebuild -project #{PROJECT_IOS} -scheme #{SCHEME_IOS} -sdk #{SDK_SIM} -destination #{SDK_SIM_DEST} test"
end

# ------------------------------------------------------------- Functions ------

def dirs_exist?(directories)
  directories.each do |dir|
    return false unless Dir.exist?(dir)
  end
end
