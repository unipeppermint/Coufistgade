# Podfile
#
# CocoaPods 只为 Firebase 而引入。CLAUDE.md 的默认是「优先原生框架、不引第三方
# 依赖」，这里是显式例外：远程推送要走 FCM，没有可替代的原生实现。
#
# 引入之后，打开项目要用 coufistgade.xcworkspace，不再是 .xcodeproj。
# 命令行同理：xcodebuild -workspace coufistgade.xcworkspace -scheme coufistgade

platform :ios, '18.0'

# 关掉 pod install 的使用数据上报。
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target 'coufistgade' do
  use_frameworks!

  # 只装 Messaging（推送）。Analytics 没装 —— FCM 不需要它，装了反而多一份
  # 数据收集要在隐私清单里申报。要加的时候在这里加一行，不需要动别处。
  pod 'FirebaseMessaging', '~> 12.18'

  # 测试 target 不自己链接 Firebase，只借用头文件与框架搜索路径。
  # `@testable import coufistgade` 会连带解析 AppDelegate 里的 Firebase import，
  # 没有这一段时测试编译会报找不到模块。
  target 'coufistgadeTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Pods 各自声明的最低版本比本项目低，会刷一屏 deployment target 警告。
      # 对齐到 app 的 18.0：低于它的系统本来就装不上这个 app。
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    end
  end

  # CocoaPods 嵌入 framework 的那一步是 shell 脚本调 rsync，Xcode 15 起默认开启的
  # 脚本沙盒会拒绝它写进 .app/Frameworks/，报一串
  # "Sandbox: rsync(...) deny(1) file-write-create"。整个项目关掉这一项。
  #
  # 写在这里而不是只改一次 pbxproj：Xcode 新建 target 时会重新带上 YES，
  # 让它每次 pod install 都被压平，比依赖谁记得手动改可靠。
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.user_project.native_targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
    aggregate_target.user_project.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
    aggregate_target.user_project.save
  end
end
