Pod::Spec.new do |s|
  s.name      = 'VLCKit'
  s.version   = '4.0.0a10'
  s.summary   = "VLCKit is an Objective-C wrapper for libvlc's external interface on macOS."
  s.homepage  = 'https://code.videolan.org/videolan/VLCKit'
  s.license   = {
    :type => 'LGPL v2.1', :file => 'COPYING.txt'
  }
  s.documentation_url = 'https://wiki.videolan.org/VLCKit/'
  s.social_media_url = 'https://twitter.com/videolan'
  s.authors   = { "Pierre d'Herbemont" => "pdherbemont@videolan.org", "Felix Paul Kühne" => "fkuehne@videolabs.io", "Alexandre Janniaux" => "ajanni@videolabs.io", "Hank Anderson" => "ataganak@gmail.com", "Maxime Chapelet" => "umxprime@videolabs.io", "Carola Nitz" => "nitz.carola@googlemail.com", "Jean-Baptiste Kempf" => "jb@videolan.org", "Rafaël Carré" => "funman@videolan.org", "Faustino E. Osuna" => "riquedafreak@videolan.org", "Rémi Denis-Courmont" => "remi@remlab.net", "Faustino Osuna" => "riquedafreak@videolan.org", "Tanguy Krotoff" => "tkrotoff@gmail.com", "VideoLAN" => "videolan@videolan.org", "Derk-Jan Hartman" => "hartman@videolan.org", "Jean-Paul Saman" => "jpsaman@videolan.org", "Malte Tancred" => "malte@frontbase.com", "Mike Schrag" => "mschrag@pobox.com", "Sebastien Zwickert" => "dilaroga@free.fr", "Toralf Niebuhr" => "gmthor85@aim.com", "Emmanuel de Roux" => "lostbread@free.fr", "Daniel Mierswa" => "impulze@impulze.org", "Rune Botten" => "rbotten@gmail.com", "Konstantin Pavlov" => "thresh@videolan.org", "Pere Orga" => "gotrunks@gmail.com", "Philippe Coent" => "philippe.coent@gmail.com", "Andrey Utkin" => "andrey.krieger.utkin@gmail.com", "Brendon Justin" => "brendonjustin@gmail.com", "Sylver Bruneau" => "sylver.bruneau@gmail.com", "Gleb Pinigin" => "gpinigin@gmail.com", "Kuang Rufan" => "master@a1983.com.cn", "Paul Williamson" => "squarefrog@gmail.com", "David Fuhrmann" => "david.fuhrmann@googlemail.com", "Brion Vibber" => "brion@pobox.com", "Martin Storsjö" => "martin@martin.st", "Winston Weinert" => "winston@ml1.net", "Florent Pillet" => "fpillet@gmail.com", "Paulo Vitor Magacho da Silva" => "pvmagacho@gmail.com", "James Dumay" => "james.w.dumay@gmail.com", "Jörg Bleyel" => "jbleyel@gmx.net", "Aleksandr Matuzok" => "sherilynhope@gmail.com", "Pierre SAGASPE" => "pierre.sagaspe@me.com", "Shenggang Hu" => "mrhhsg@gmail.com", "Filipe Cabecinhas" => "vlc@filcab.net", "Jeremy Marchand" => "kodlian@users.noreply.github.com", "Andre Silva" => "andre.silva@blip.pt", "Stefan Schmidt-Bilkenroth" => "ssb@mac.com", "Benjamin Adolphi" => "b.adolphi@gmail.com" }
  s.source    = {
    :http => 'https://download.videolan.org/cocoapods/unstable/VLCKit-4.0.0a10-d962e05c-17860384.tar.xz',
    :sha256 => '8d3b1f8d1b6e4fc35d45b706a800a424a1b841d2dc5d4229817a3d7a000bf372'
  }
  s.vendored_framework = 'VLCKit.xcframework'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '11.0'
  s.ios.deployment_target = '9.0'
  s.visionos.deployment_target = '1.0'
  s.watchos.deployment_target = '7.4'
  s.frameworks = 'Foundation'
  s.libraries = 'iconv'
  s.requires_arc = false
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }

  # Exclude x86_64 architecture for xrSimulator
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=xrsimulator*]' => 'x86_64' }
end
