# Uncomment the next line to define a global platform for your project
platform :osx, '10.15'

target 'Pock' do

  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # PockKit
  pod 'PockKit', :git => 'https://github.com/pock/pockkit.git', :commit => '335bc4c0edb4c9ad1beabe294f70cd39300dc577'

  # Utils
  pod 'Magnet', '3.4.0'
  pod 'Zip', '2.1.2'

end

# Older podspecs still target macOS 10.9. Align them with the host app so
# current Swift SDK availability checking uses the actual supported minimum.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
    end
  end
end
