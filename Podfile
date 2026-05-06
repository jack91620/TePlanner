platform :ios, '17.0'
project 'TePlannerApp.xcodeproj'

# Static linkage matches Android's behavior of bundling AMap into the app
# binary; also avoids dynamic-framework code-signing complications during
# `xcodebuild` from CLI.
use_frameworks! :linkage => :static

target 'TePlannerApp' do
  pod 'AMap3DMap'    # 3D 地图 SDK，含定位
  pod 'AMapSearch'   # POI / 路径 / 地理编码搜索
  pod 'AMapLocation' # 定位 SDK
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      # AMap pods occasionally bundle ARM-only slices; keep build flags
      # consistent so simulator x86_64 + arm64 both link.
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
