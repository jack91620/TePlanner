# TePlanner Flutter 迁移指南

## 概述

本文档描述将 TePlanner 从微信小程序迁移到 Flutter 跨平台应用的完整方案。

### 迁移原因

1. **沿途搜索 API 成本高**：腾讯地图 alongby API 费用过高
2. **跨平台需求**：同时支持 iOS 和 Android
3. **更好的用户体验**：原生应用性能更优

### 技术决策

| 决策项 | 选择 | 原因 |
|--------|------|------|
| 开发框架 | Flutter | 跨平台、性能好、生态成熟 |
| 地图 SDK | 高德 Flutter 插件 | 国内最佳选择 |
| 沿途搜索 | 后端多点周边搜索 | Flutter 插件暂不支持沿途搜索 |
| iOS 构建 | GitHub Actions | Windows 无法直接构建 iOS |

---

# 第一部分：开发环境配置

## 1. Windows 环境配置

### 1.1 安装 Flutter SDK

**下载地址**：https://docs.flutter.dev/get-started/install/windows

```powershell
# 1. 下载并解压 Flutter SDK 到 C:\flutter

# 2. 添加环境变量
# 方法：系统属性 → 高级 → 环境变量 → 系统变量 → Path → 编辑 → 新建
# 添加：C:\flutter\bin

# 3. 打开新的 PowerShell 窗口，验证安装
flutter --version

# 预期输出：
# Flutter 3.x.x • channel stable
# Framework • revision xxxxx
# Engine • revision xxxxx
# Tools • Dart x.x.x • DevTools x.x.x
```

### 1.2 安装 Android Studio

**下载地址**：https://developer.android.com/studio

安装步骤：

1. 运行安装程序，选择 "Standard" 安装
2. 安装完成后，打开 Android Studio
3. 进入 **Settings → Languages & Frameworks → Android SDK**
4. 在 **SDK Tools** 标签页，勾选安装：
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
   - Android Emulator
   - Android SDK Platform-Tools

### 1.3 配置 Android 模拟器

1. 打开 Android Studio
2. 点击 **More Actions → Virtual Device Manager**
3. 点击 **Create Device**
4. 选择设备：**Pixel 6** (或其他)
5. 选择系统镜像：**API 34** (Android 14)
6. 点击 **Finish** 完成创建

### 1.4 安装 VS Code 扩展

打开 VS Code，安装以下扩展：

| 扩展名称 | 作者 | 用途 |
|---------|------|------|
| Flutter | Dart Code | Flutter 开发支持 |
| Dart | Dart Code | Dart 语言支持 |
| Flutter Widget Snippets | Alexis Villegas | 代码片段 |
| Error Lens | Alexander | 行内错误显示 |

### 1.5 验证环境配置

```powershell
flutter doctor -v
```

**期望输出**（所有项目打勾）：

```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Windows Version (Windows 10/11)
[✓] Android toolchain - develop for Android devices
[✓] Android Studio (version 2023.x)
[✓] VS Code (version 1.8x.x)
[✓] Connected device (1 available)
[✓] Network resources
```

### 1.6 常见问题解决

**问题 1：Android license not accepted**
```powershell
flutter doctor --android-licenses
# 输入 y 接受所有许可证
```

**问题 2：找不到 Android SDK**
```powershell
flutter config --android-sdk "C:\Users\你的用户名\AppData\Local\Android\Sdk"
```

**问题 3：cmdline-tools 未安装**
- 打开 Android Studio → Settings → SDK Tools
- 勾选 "Android SDK Command-line Tools (latest)"
- 点击 Apply 安装

---

## 2. iOS 构建配置（GitHub Actions）

由于 Windows 无法直接构建 iOS 应用，我们使用 GitHub Actions 的 macOS runner。

### 2.1 创建 GitHub Actions 工作流

创建文件：`.github/workflows/build.yml`

```yaml
name: Build Flutter App

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:  # 允许手动触发

jobs:
  # Android 构建
  build-android:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Build APK
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  # iOS 构建
  build-ios:
    runs-on: macos-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Build iOS (no codesign)
        run: flutter build ios --release --no-codesign

      - name: Upload iOS build
        uses: actions/upload-artifact@v4
        with:
          name: ios-build
          path: build/ios/iphoneos/
```

### 2.2 iOS 签名配置（后续步骤）

正式发布时需要：

1. 申请 Apple Developer 账号（$99/年）
2. 创建 App ID、证书和 Provisioning Profile
3. 在 GitHub Secrets 中配置签名信息
4. 更新工作流使用 fastlane 签名

---

## 3. 高德地图 SDK 配置

### 3.1 申请 API Key

1. 访问 [高德开放平台](https://lbs.amap.com/)
2. 注册/登录账号
3. 进入控制台 → 应用管理 → 创建新应用
4. 添加 Key：
   - Android Key（需要 SHA1 和包名）
   - iOS Key（需要 Bundle ID）

### 3.2 获取 Android SHA1

```powershell
# 开发环境 debug key
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# 或者在项目目录下运行
cd android
./gradlew signingReport
```

### 3.3 配置 Android

编辑 `android/app/src/main/AndroidManifest.xml`：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 权限 -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>

    <application ...>
        <!-- 高德地图 API Key -->
        <meta-data
            android:name="com.amap.api.v2.apikey"
            android:value="你的Android Key"/>

        <!-- 定位服务 -->
        <service android:name="com.amap.api.location.APSService"/>
    </application>
</manifest>
```

### 3.4 配置 iOS

编辑 `ios/Runner/Info.plist`：

```xml
<dict>
    <!-- 高德地图 API Key -->
    <key>amap_api_key</key>
    <string>你的iOS Key</string>

    <!-- 定位权限描述 -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>需要您的位置信息以显示当前位置和规划路线</string>

    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>需要您的位置信息以在后台更新导航</string>
</dict>
```

---

# 第二部分：项目架构

## 1. 目录结构

```
teplanner_flutter/
├── lib/
│   ├── main.dart                     # 应用入口
│   ├── app.dart                      # App 根组件
│   │
│   ├── config/                       # 配置
│   │   ├── api_config.dart           # API 地址配置
│   │   ├── map_config.dart           # 地图 Key 配置
│   │   └── theme.dart                # 主题配置
│   │
│   ├── models/                       # 数据模型
│   │   ├── user.dart                 # 用户模型
│   │   ├── vehicle.dart              # 车辆模型
│   │   ├── route.dart                # 路线模型
│   │   ├── charging_station.dart     # 充电站模型
│   │   └── location.dart             # 位置模型
│   │
│   ├── services/                     # 服务层
│   │   ├── api/
│   │   │   ├── api_client.dart       # HTTP 客户端
│   │   │   ├── auth_api.dart         # 认证 API
│   │   │   ├── vehicle_api.dart      # 车辆 API
│   │   │   └── route_api.dart        # 路线 API
│   │   ├── auth_service.dart         # 认证服务
│   │   ├── vehicle_service.dart      # 车辆服务
│   │   ├── route_service.dart        # 路线服务
│   │   └── storage_service.dart      # 本地存储
│   │
│   ├── providers/                    # 状态管理 (Riverpod)
│   │   ├── auth_provider.dart        # 认证状态
│   │   ├── vehicle_provider.dart     # 车辆状态
│   │   ├── route_provider.dart       # 路线状态
│   │   └── location_provider.dart    # 位置状态
│   │
│   ├── screens/                      # 页面
│   │   ├── home/
│   │   │   ├── home_screen.dart      # 首页
│   │   │   └── widgets/
│   │   │       ├── search_panel.dart
│   │   │       └── vehicle_status.dart
│   │   ├── route_result/
│   │   │   ├── route_result_screen.dart
│   │   │   └── widgets/
│   │   ├── search/
│   │   │   └── search_screen.dart
│   │   ├── vehicle_binding/
│   │   │   └── vehicle_binding_screen.dart
│   │   ├── profile/
│   │   │   └── profile_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   │
│   ├── widgets/                      # 可复用组件
│   │   ├── common/
│   │   │   ├── loading_overlay.dart
│   │   │   └── error_view.dart
│   │   ├── map/
│   │   │   ├── te_map.dart           # 地图封装
│   │   │   └── map_markers.dart
│   │   ├── search_bar.dart
│   │   ├── charging_station_card.dart
│   │   └── draggable_panel.dart
│   │
│   ├── routes/                       # 路由配置
│   │   └── app_router.dart
│   │
│   └── utils/                        # 工具类
│       ├── constants.dart
│       ├── extensions.dart
│       └── helpers.dart
│
├── assets/
│   ├── icons/                        # 图标（从小程序迁移）
│   ├── images/
│   └── fonts/
│
├── test/                             # 测试
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── android/                          # Android 原生配置
├── ios/                              # iOS 原生配置
├── pubspec.yaml                      # 依赖配置
└── README.md
```

## 2. 核心依赖

`pubspec.yaml`:

```yaml
name: teplanner
description: Tesla EV Route Planner with charging optimization
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # 核心
  flutter_riverpod: ^2.4.9      # 状态管理
  go_router: ^13.0.1            # 路由

  # 网络
  dio: ^5.4.0                   # HTTP 客户端
  connectivity_plus: ^5.0.2     # 网络状态检测

  # 存储
  shared_preferences: ^2.2.2    # 简单键值存储
  flutter_secure_storage: ^9.0.0 # 安全存储（Token）

  # 地图
  amap_flutter_map: ^3.0.0      # 高德地图
  amap_flutter_location: ^3.0.0 # 高德定位

  # UI
  flutter_slidable: ^3.0.1      # 滑动操作
  shimmer: ^3.0.0               # 加载骨架屏
  cached_network_image: ^3.3.1  # 图片缓存
  flutter_svg: ^2.0.9           # SVG 支持

  # 工具
  intl: ^0.18.1                 # 国际化/日期格式
  url_launcher: ^6.2.2          # 打开外部链接
  package_info_plus: ^5.0.1     # 应用信息

  # 图标
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.8
  mockito: ^5.4.4               # 测试 Mock

flutter:
  uses-material-design: true

  assets:
    - assets/icons/
    - assets/images/

  fonts:
    - family: PingFang
      fonts:
        - asset: assets/fonts/PingFang-Regular.ttf
        - asset: assets/fonts/PingFang-Medium.ttf
          weight: 500
        - asset: assets/fonts/PingFang-Bold.ttf
          weight: 700
```

## 3. 核心代码示例

### 3.1 API 客户端

`lib/services/api/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});

class ApiClient {
  final Ref _ref;
  late final Dio _dio;

  ApiClient(this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 自动添加 Token
        final token = await _ref.read(storageServiceProvider).getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // 统一错误处理
        if (error.response?.statusCode == 401) {
          // Token 过期，清除登录状态
          _ref.read(storageServiceProvider).clearToken();
        }
        handler.next(error);
      },
    ));
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}
```

### 3.2 路线服务

`lib/services/route_service.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route.dart';
import 'api/api_client.dart';

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService(ref.read(apiClientProvider));
});

class RouteService {
  final ApiClient _api;

  RouteService(this._api);

  /// 规划路线
  Future<PlannedRoute> planRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? originName,
    String? destName,
    int? currentSoc,
    int? targetSoc,
  }) async {
    final response = await _api.post('/routes/plan', data: {
      'origin': {
        'latitude': originLat,
        'longitude': originLng,
        'name': originName,
      },
      'destination': {
        'latitude': destLat,
        'longitude': destLng,
        'name': destName,
      },
      'current_soc': currentSoc,
      'target_soc': targetSoc,
    });

    return PlannedRoute.fromJson(response.data);
  }

  /// 发送导航到车辆
  Future<void> sendToVehicle(String routeId) async {
    await _api.post('/routes/navigate/$routeId');
  }

  /// 获取历史路线
  Future<List<PlannedRoute>> getHistory() async {
    final response = await _api.get('/routes/');
    return (response.data as List)
        .map((json) => PlannedRoute.fromJson(json))
        .toList();
  }
}
```

### 3.3 地图组件

`lib/widgets/map/te_map.dart`:

```dart
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:flutter/material.dart';
import '../../config/map_config.dart';

class TeMap extends StatefulWidget {
  final LatLng? initialPosition;
  final double initialZoom;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final void Function(AMapController)? onMapCreated;
  final void Function(LatLng)? onTap;

  const TeMap({
    super.key,
    this.initialPosition,
    this.initialZoom = 12,
    this.markers,
    this.polylines,
    this.onMapCreated,
    this.onTap,
  });

  @override
  State<TeMap> createState() => _TeMapState();
}

class _TeMapState extends State<TeMap> {
  AMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return AMapWidget(
      apiKey: AMapApiKey(
        androidKey: MapConfig.androidKey,
        iosKey: MapConfig.iosKey,
      ),
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition ??
            const LatLng(39.909187, 116.397451), // 默认北京
        zoom: widget.initialZoom,
      ),
      markers: widget.markers ?? {},
      polylines: widget.polylines ?? {},
      myLocationStyleOptions: MyLocationStyleOptions(
        true,
        circleFillColor: Colors.blue.withOpacity(0.1),
        circleStrokeColor: Colors.blue,
        circleStrokeWidth: 1,
      ),
      onMapCreated: (controller) {
        _controller = controller;
        widget.onMapCreated?.call(controller);
      },
      onTap: (latLng) {
        widget.onTap?.call(latLng);
      },
    );
  }

  /// 移动到指定位置
  void moveTo(LatLng position, {double? zoom}) {
    _controller?.moveCamera(
      CameraUpdate.newLatLngZoom(position, zoom ?? widget.initialZoom),
    );
  }

  /// 缩放以显示所有标记点
  void fitBounds(List<LatLng> points, {EdgeInsets padding = const EdgeInsets.all(50)}) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    _controller?.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        padding.left,
      ),
    );
  }
}
```

### 3.4 状态管理示例

`lib/providers/route_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route.dart';
import '../models/location.dart';
import '../services/route_service.dart';

// 路线规划状态
enum RoutePlanningState { idle, planning, success, error }

// 路线状态
class RouteState {
  final RoutePlanningState state;
  final PlannedRoute? route;
  final String? error;
  final Location? origin;
  final Location? destination;

  const RouteState({
    this.state = RoutePlanningState.idle,
    this.route,
    this.error,
    this.origin,
    this.destination,
  });

  RouteState copyWith({
    RoutePlanningState? state,
    PlannedRoute? route,
    String? error,
    Location? origin,
    Location? destination,
  }) {
    return RouteState(
      state: state ?? this.state,
      route: route ?? this.route,
      error: error ?? this.error,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
    );
  }
}

// 路线 Provider
class RouteNotifier extends StateNotifier<RouteState> {
  final RouteService _routeService;

  RouteNotifier(this._routeService) : super(const RouteState());

  void setOrigin(Location origin) {
    state = state.copyWith(origin: origin);
  }

  void setDestination(Location destination) {
    state = state.copyWith(destination: destination);
  }

  Future<void> planRoute() async {
    if (state.origin == null || state.destination == null) return;

    state = state.copyWith(state: RoutePlanningState.planning);

    try {
      final route = await _routeService.planRoute(
        originLat: state.origin!.latitude,
        originLng: state.origin!.longitude,
        originName: state.origin!.name,
        destLat: state.destination!.latitude,
        destLng: state.destination!.longitude,
        destName: state.destination!.name,
      );

      state = state.copyWith(
        state: RoutePlanningState.success,
        route: route,
      );
    } catch (e) {
      state = state.copyWith(
        state: RoutePlanningState.error,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const RouteState();
  }
}

final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>((ref) {
  return RouteNotifier(ref.read(routeServiceProvider));
});
```

---

# 第三部分：迁移计划

## 阶段概览

| 阶段 | 周期 | 目标 | 产出 |
|------|------|------|------|
| Phase 1 | 2 周 | 项目搭建 | 可运行的框架 |
| Phase 2 | 3 周 | 地图 + 路线规划 | 核心功能 MVP |
| Phase 3 | 2 周 | Tesla 集成 | 完整功能 |
| Phase 4 | 2 周 | UI 完善 + 测试 | 稳定版本 |
| Phase 5 | 1 周 | iOS 发布 | App Store |

**总计：10 周**

---

## Phase 1：项目搭建（第 1-2 周）

### Week 1 任务

- [ ] 创建 Flutter 项目 `flutter create teplanner`
- [ ] 配置目录结构
- [ ] 添加核心依赖 (pubspec.yaml)
- [ ] 配置 Android 权限 (AndroidManifest.xml)
- [ ] 配置 iOS 权限 (Info.plist)
- [ ] 实现 API Client (Dio)
- [ ] 实现 Storage Service
- [ ] 创建数据模型 (User, Vehicle, Route, ChargingStation)

### Week 2 任务

- [ ] 配置 Riverpod
- [ ] 实现 Auth Provider
- [ ] 配置 GoRouter 路由
- [ ] 实现主题配置
- [ ] 创建基础 UI 组件（按钮、输入框、卡片）
- [ ] 配置 GitHub Actions CI/CD
- [ ] 实现启动页 (Splash Screen)

### 验收标准

- 应用可在 Android 模拟器运行
- API 请求可正常发送
- 页面路由正常工作

---

## Phase 2：地图与路线规划（第 3-5 周）

### Week 3 任务

- [ ] 集成高德地图 SDK
- [ ] 实现 TeMap 地图组件
- [ ] 实现定位功能
- [ ] 实现地图标记 (Markers)
- [ ] 实现路线绘制 (Polyline)
- [ ] 迁移地图图标资源

### Week 4 任务

- [ ] 实现搜索页面 UI
- [ ] 实现地点搜索（调用后端 API）
- [ ] 实现搜索建议/自动补全
- [ ] 实现地址选择确认
- [ ] 实现可拖动面板组件 (DraggablePanel)

### Week 5 任务

- [ ] 实现首页 UI
- [ ] 实现起点/终点选择流程
- [ ] 调用后端路线规划 API
- [ ] 实现路线结果页面
- [ ] 显示充电站列表和详情
- [ ] 实现路线地图展示

### 验收标准

- 地图正常显示和交互
- 可搜索地点并选择
- 可规划路线并显示结果
- 充电站信息正确展示

---

## Phase 3：Tesla 集成（第 6-7 周）

### Week 6 任务

- [ ] 实现 Tesla OAuth 页面
- [ ] 调用后端获取 OAuth URL
- [ ] 处理 OAuth 回调 (Deep Link / URL Scheme)
- [ ] 实现 Token 安全存储
- [ ] 实现车辆列表获取

### Week 7 任务

- [ ] 实现车辆状态展示
- [ ] 实现唤醒车辆功能
- [ ] 实现发送导航到车辆
- [ ] 处理车辆离线状态
- [ ] 实现车辆选择切换

### 验收标准

- Tesla 账号可正常绑定
- 车辆状态可正常获取
- 导航可发送到车辆

---

## Phase 4：UI 完善与测试（第 8-9 周）

### Week 8 任务

- [ ] 完善首页 UI 细节
- [ ] 完善路线结果页 UI
- [ ] 完善个人中心页
- [ ] 实现加载状态 (Shimmer)
- [ ] 实现错误状态处理
- [ ] 适配不同屏幕尺寸
- [ ] 实现页面转场动画

### Week 9 任务

- [ ] 编写单元测试 (Services)
- [ ] 编写 Widget 测试 (UI)
- [ ] 集成测试 (关键流程)
- [ ] 性能优化
- [ ] 内存泄漏检测
- [ ] Bug 修复

### 验收标准

- UI 与设计稿一致
- 所有主流程测试通过
- 无明显性能问题

---

## Phase 5：iOS 发布（第 10 周）

### 任务清单

- [ ] 申请 Apple Developer 账号
- [ ] 创建 App ID
- [ ] 创建开发/发布证书
- [ ] 创建 Provisioning Profile
- [ ] 配置 GitHub Actions iOS 签名
- [ ] 构建并上传到 TestFlight
- [ ] 内部测试
- [ ] 准备 App Store 截图和描述
- [ ] 提交审核

### 验收标准

- iOS 版本可在 TestFlight 安装
- 通过 App Store 审核

---

# 第四部分：后端适配

## 需要修改的后端模块

### 1. 认证模块

**新增 Apple Sign In 支持**：

```python
# backend/app/api/v1/auth.py

@router.post("/auth/apple/login")
async def apple_login(
    id_token: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Apple Sign In 登录
    1. 验证 Apple ID Token
    2. 创建或更新用户
    3. 返回 JWT Token
    """
    # 验证 Apple ID Token
    apple_user = await verify_apple_token(id_token)

    # 查找或创建用户
    user = await get_or_create_user(
        db,
        apple_id=apple_user.sub,
        email=apple_user.email,
    )

    # 生成 JWT
    token = create_access_token(user.id)

    return {"token": token, "user": user}
```

### 2. 多点周边搜索

**替代昂贵的沿途搜索 API**：

```python
# backend/app/integrations/tencent_map/client.py

async def search_charging_along_route_v2(
    self,
    polyline: List[Tuple[float, float]],
    interval_km: float = 50,
) -> List[Dict[str, Any]]:
    """
    多点周边搜索（替代 alongby API）

    策略：沿路线每 50km 取一个采样点，对每个点做周边搜索
    """
    # 1. 采样点
    sample_points = self._sample_points(polyline, interval_km)

    # 2. 并行搜索
    tasks = [
        self.search_nearby(lat, lng, "充电站", radius=30000)
        for lat, lng in sample_points
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    # 3. 合并去重
    seen_ids = set()
    merged = []
    for result in results:
        if isinstance(result, Exception):
            continue
        for poi in result:
            if poi["id"] not in seen_ids:
                seen_ids.add(poi["id"])
                # 过滤：只保留高速服务区
                if self._is_service_area(poi["title"]):
                    merged.append(poi)

    return merged

def _is_service_area(self, name: str) -> bool:
    """判断是否是高速服务区"""
    keywords = ["服务区", "停车区"]
    return any(k in name for k in keywords)
```

---

# 第五部分：API 对照表

## 小程序 → Flutter API 对照

| 小程序 API | Flutter 替代 | 备注 |
|------------|-------------|------|
| `wx.request` | `Dio` | HTTP 请求 |
| `wx.getStorageSync` | `SharedPreferences` | 简单存储 |
| `wx.setStorageSync` | `SharedPreferences` | 简单存储 |
| `wx.getLocation` | `amap_flutter_location` | 定位 |
| `wx.createMapContext` | `AMapWidget` | 地图 |
| `wx.showToast` | `ScaffoldMessenger.showSnackBar` | 轻提示 |
| `wx.showLoading` | `showDialog` + `CircularProgressIndicator` | 加载中 |
| `wx.showModal` | `showDialog` + `AlertDialog` | 对话框 |
| `wx.navigateTo` | `GoRouter.push` | 页面跳转 |
| `wx.navigateBack` | `GoRouter.pop` | 返回 |
| `wx.openLocation` | `url_launcher` | 打开地图 App |
| `wx.setClipboardData` | `Clipboard.setData` | 复制到剪贴板 |
| `wx.getSystemInfo` | `MediaQuery` / `Platform` | 系统信息 |

## 组件映射

| 小程序组件 | Flutter 组件 |
|-----------|-------------|
| `<view>` | `Container` / `Column` / `Row` |
| `<text>` | `Text` |
| `<image>` | `Image` |
| `<button>` | `ElevatedButton` / `TextButton` |
| `<input>` | `TextField` |
| `<scroll-view>` | `ListView` / `SingleChildScrollView` |
| `<map>` | `AMapWidget` |
| `<picker>` | `showDatePicker` / `showModalBottomSheet` |

---

# 附录

## 常用命令

```bash
# 创建项目
flutter create --org com.yourcompany teplanner

# 运行（开发模式）
flutter run

# 运行指定设备
flutter run -d <device_id>

# 列出设备
flutter devices

# 热重载
r  # 在运行时按 r

# 热重启
R  # 在运行时按 R

# 构建 APK
flutter build apk --release

# 构建 iOS
flutter build ios --release

# 运行测试
flutter test

# 分析代码
flutter analyze

# 清理构建
flutter clean

# 更新依赖
flutter pub get
flutter pub upgrade
```

## 参考资源

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言文档](https://dart.dev/guides)
- [Riverpod 文档](https://riverpod.dev/)
- [高德 Flutter 插件](https://lbs.amap.com/api/flutter/summary)
- [GoRouter 文档](https://pub.dev/packages/go_router)

---

*文档版本：1.0*
*创建日期：2026-01-07*
