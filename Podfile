# platform :ios, '8.0'
# Uncomment this line if you're using Swift
use_frameworks!

target 'unnamedcast' do
  pod 'Freddy'
  pod 'RealmSwift'
  pod 'Alamofire', '~> 3.5' # 3.5 need for Swift 2.3 support, 4.0 needed for Swift 3.0
  pod 'PromiseKit/CorePromise'
  pod 'PromiseKit/UIKit'
  pod 'SDWebImage'
  pod 'Swinject'
end

target 'unnamedcastTests' do
  pod 'Freddy'
  pod 'RealmSwift'
  pod 'Alamofire', '~> 3.5'
  pod 'PromiseKit/CorePromise'
  pod 'PromiseKit/UIKit'
  pod 'SDWebImage'
  pod 'Swinject'
end

target 'unnamedcastUnitTests' do
  pod 'Freddy'
  pod 'RealmSwift'
  pod 'Alamofire', '~> 3.5'
  pod 'PromiseKit/UIKit'
  pod 'SDWebImage'
  pod 'Swinject'
end

target 'unnamedcastUITests' do
  pod 'SDWebImage'
  pod 'Swinject'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '2.3'
        end
    end
end
