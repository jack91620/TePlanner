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
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      # AMap ships legacy fat binaries (arm64-device + x86_64-sim) and
      # forces EXCLUDED_ARCHS=arm64 on iphonesimulator. Apple Silicon
      # Macs need an arm64-simulator slice — scripts/retag-amap-for-sim.sh
      # rewrites the load commands to fake one. Drop the exclusion here.
      config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
    end
  end

  # Strip the same EXCLUDED_ARCHS line CocoaPods writes into the
  # generated .xcconfig files (the in-memory project mutation above
  # doesn't cover those — they're regenerated each pod install).
  Dir.glob(File.join(installer.config.installation_root,
                     'Pods/Target Support Files/**/*.xcconfig')).each do |path|
    contents = File.read(path)
    next unless contents.include?('EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64')
    File.write(path, contents.gsub(
      /^EXCLUDED_ARCHS\[sdk=iphonesimulator\*\] = arm64\s*$/,
      "// EXCLUDED_ARCHS removed: AMap arm64 slice retagged for simulator"
    ))
  end

  retag = File.join(installer.config.installation_root,
                    'scripts', 'retag-amap-for-sim.sh')
  if File.executable?(retag)
    unless system(retag, installer.config.installation_root.to_s)
      raise "retag-amap-for-sim.sh failed (exit $?)"
    end
  else
    Pod::UI.warn "retag script missing or not executable: #{retag}"
  end
end
