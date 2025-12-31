# Podfile for SAS360Capture
# Run 'pod install' in the project directory after adding this file

platform :ios, '15.0'

target 'SAS360CaptureApp' do
  use_frameworks!
  
  # OpenCV for panorama stitching
  pod 'OpenCV', '~> 4.3'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
