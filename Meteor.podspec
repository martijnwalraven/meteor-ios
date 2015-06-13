Pod::Spec.new do |s|
  s.name         = "Meteor"
  s.version      = File.read('VERSION')
  s.summary      = "Meteor iOS."
  s.description  = <<-DESC
    Meteor iOS integrates native iOS apps with the Meteor platform through DDP.
    DESC
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.homepage     = "https://github.com/martijnwalraven/meteor-ios"
  s.authors      = { "Martijn Walraven" => "martijn@martijnwalraven.com" }
  s.source       = { :git => "https://github.com/martijnwalraven/meteor-ios.git", :tag => s.version.to_s }

  s.ios.deployment_target = '7.0'
  s.requires_arc = true

  s.source_files = 'Meteor/**/*.{h,m}'
  s.public_header_files = `./Scripts/find_headers.rb --project Meteor --target "Meteor iOS" --public`.split("\n")
  s.private_header_files = `./Scripts/find_headers.rb --project Meteor --target "Meteor iOS" --private`.split("\n")
      
	s.frameworks = 'CoreData'
  
  s.dependency 'PocketSocket'
  s.dependency 'InflectorKit'
  s.dependency 'SimpleKeychain'
end
