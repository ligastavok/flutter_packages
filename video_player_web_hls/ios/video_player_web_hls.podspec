#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'video_player_web_hls'
  s.version          = '0.0.1'
  s.summary          = 'Web video player with HLS Support'
  s.description      = <<-DESC
temp fake url_launcher_web plugin
                       DESC
  s.homepage         = 'https://vcs.app-ses.com/projects/MOB/repos/video_player_web_hls/browse'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Balvinder' => 'balvindersi2@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '8.0'
end
