Pod::Spec.new do |s|
  s.name      = 'TVVLCKit-unstable'
  s.version   = '3.0.0a9'
  s.summary   = "TVVLCKit is an Objective-C wrapper for libvlc's external interface on tvOS."
  s.homepage  = 'https://code.videolan.org/videolan/VLCKit'
  s.license   = {
    :type => 'LGPLv2.1', :file => 'TVVLCKit-binary/COPYING.txt'
  }
  s.documentation_url = 'https://wiki.videolan.org/VLCKit/'
  s.platform  = :tvos
  s.authors   = { "Pierre d'Herbemont" => "pdherbemont@videolan.org", "Felix Paul Kühne" => "fkuehne@videolan.org", "Tobias Conradi" => "videolan@tobias-conradi.de", "Carola Nitz" => "caro@videolan.org" }
  s.source    = {
    :http => 'http://download.videolan.org/pub/cocoapods/unstable/TVVLCKit-unstable-3.0.0a9.zip'
  }
  s.ios.vendored_framework = 'TVVLCKit-binary/TVVLCKit.framework'
  s.source_files = 'TVVLCKit-binary/TVVLCKit.framework/Headers/*.h'
  s.public_header_files = 'TVVLCKit-binary/TVVLCKit.framework/Headers/*.h'
  s.tvos.deployment_target = '9.0'
  s.frameworks = 'CoreText', 'AVFoundation', 'AudioToolbox', 'OpenGLES'
  s.libraries = 'c++', 'xml2', 'z', 'bz2', 'iconv'
  s.requires_arc = false
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
