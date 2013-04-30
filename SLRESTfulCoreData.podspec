Pod::Spec.new do |spec|
  spec.name         = 'SLRESTfulCoreData'
  spec.version      = '1.0.2'
  spec.platform     = :ios, '5.0'
  spec.license      = 'MIT'
  spec.source       = { :git => 'https://github.com/OliverLetterer/SLRESTfulCoreData.git', :tag => spec.version.to_s }
  spec.frameworks   = 'Foundation', 'UIKit', 'CoreData'
  spec.requires_arc = true
  spec.homepage     = 'https://github.com/OliverLetterer/SLRESTfulCoreData'
  spec.summary      = 'Map your REST API to your CoreData model in minutes.'
  spec.author       = { 'Oliver Letterer' => 'oliver.letterer@gmail.com' }

  spec.default_subspec = 'Complete'

  spec.subspec 'Core' do |sp|
    sp.source_files = 'SLRESTfulCoreData/SLRESTfulCoreData/*.{h,m}', 'SLRESTfulCoreData/SLRESTfulCoreData/**/*.{h,m}', 'SLRESTfulCoreData/SLRESTfulCoreData/Framework Additions/**/**/*.{h,m}'
  end

  spec.subspec 'Complete' do |sp|
    sp.dependency 'SLRESTfulCoreData/Core'

    sp.dependency 'AFNetworking', '>= 1.2.1'
    sp.dependency 'AFRESTfulCoreDataBackgroundQueue', '>= 1.0.1'
    sp.dependency 'SLCoreDataStack', '>= 0.1.0'
  end
end