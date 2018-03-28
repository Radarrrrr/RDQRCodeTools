Pod::Spec.new do |s|

  s.name         = "RDQRCodeTools"
  s.version      = "1.0.0"
  s.summary      = "tools for create and scan qr code"
  s.homepage     = "https://github.com/Radarrrrr/RDQRCodeTools"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Radar" => "imryd@163.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/Radarrrrr/RDQRCodeTools.git", :tag => "1.0.0" }
  s.source_files  = "RDQRCodeTools/*"
  s.requires_arc = true

end