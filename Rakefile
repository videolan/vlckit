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

PROJECT_MOBILE = 'MobileVLCKit.xcodeproj'

SDK_SIM_IOS = 'iphonesimulator11.3'

SDK_SIM_DEST_IOS = "'platform=iOS Simulator,name=iPhone 7,OS=11.3'"

SCHEME_IOS = 'MobileVLCKitTests'

VLC_FLAGS_IOS = '-dva x86_64'

DERIVED_DATA_PATH = 'DerivedData'
COVERAGE_REPORT_PATH = 'Tests/Coverage'

XCPRETTY = "xcpretty && exit ${PIPESTATUS[0]}"

# ----------------------------------------------------------------- Tasks ------

desc 'Build MobileVLCKit'
task 'build:vlckit:ios' do
  puts 'Building MobileVLCKit'

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
  sh "xcodebuild -derivedDataPath #{DERIVED_DATA_PATH}/#{SCHEME_IOS} -project #{PROJECT_MOBILE} -scheme #{SCHEME_IOS} -sdk #{SDK_SIM_IOS} -destination #{SDK_SIM_DEST_IOS} test | #{XCPRETTY}"
end

desc 'Generate code coverage reports (MobileVLCKit)'
task 'codecov:ios' do
  puts 'Generating code coverage reports (MobileVLCKit)'
  generate_coverage(SCHEME_IOS)
end

# ------------------------------------------------------------- Functions ------

def generate_coverage(scheme)
  report_name = "#{COVERAGE_REPORT_PATH}/#{scheme}_coverage.txt"
  scheme_derived_data = "#{DERIVED_DATA_PATH}/#{scheme}"

  if Dir.exist?(scheme_derived_data)
    sh "mkdir -p #{COVERAGE_REPORT_PATH}"
    sh "xcrun xccov view #{scheme_derived_data}/Logs/Test/*.xccovreport > #{report_name}"
    sh "cat #{report_name}"
  else
    puts "#{scheme} has not been tested yet. Please run its tests first"
  end
end

def dirs_exist?(directories)
  directories.each do |dir|
    return false unless Dir.exist?(dir)
  end
end
