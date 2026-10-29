# AGENTS.md

给在本仓库里写代码的 AI / 自动化代理的协作指南。先读 [`README.md`](README.md) 了解功能与架构，本文件只讲「怎么改、别踩什么坑」。

## 项目速览

- **NullMap（零点地图）**：Flutter 联系人地图 App，记录朋友所在地并在高德地图上显示头像标记。
- **完整功能平台**：Android（高德 3D 地图 SDK）。iOS 只有 Flutter 外壳，地图为占位网格。
- **UI**：Material 3，`material_ui` 包（不是 `flutter/material.dart`），默认跟随壁纸动态取色。
- **最低 Dart**：`^3.13.7`；Android 构建用 **JDK 17**。
- 版本号在 `pubspec.yaml` 与 `lib/core/app_info.dart` 两处，必须同步。

## 常用命令

在仓库根目录（含 `pubspec.yaml` 的这一层）执行：

| 目的 | 命令 |
| --- | --- |
| 拉依赖 | `flutter pub get` |
| 静态检查 | `flutter analyze` |
| 单元 / Widget 测试 | `flutter test` |
| 生成多语言代码 | `flutter gen-l10n` |
| 调试运行 | `flutter run`（需要 arm64 真机） |
| 发布包 | `flutter build apk --release` 或 `flutter build appbundle --release` |
| 真机冒烟测试 | `flutter test integration_test/map_search_test.dart -d <设备序列号>` |
| 格式化 | `dart format lib test integration_test` |

本地没有 `android/key.properties` 时 Gradle 签名配置会失败。需要自建（内容见 README「高德 Key 与签名」），或只跑纯 Dart 的测试与分析。

## 代码地图

| 想改什么 | 去哪里 |
| --- | --- |
| 启动、主题/语言装配、通知点击导航 | `lib/main.dart` |
| 程序名 / 版本 / 开发者 / 仓库地址 | `lib/core/app_info.dart`（**唯一来源**） |
| 设置项、枚举、持久化键 | `lib/core/app_settings.dart` |
| 枚举值 → 显示文案 | `lib/core/l10n_labels.dart` |
| 联系人字段 / JSON / 旧数据迁移 | `lib/data/contact.dart` |
| 联系人读写 / 头像文件 | `lib/data/contact_store.dart` |
| 底部导航、跨页跳转入口 | `lib/screens/home_screen.dart` |
| 地图、标记同步、地点与联系人搜索 | `lib/screens/map_page.dart` |
| 联系人列表 / 筛选 / 详情 | `lib/screens/contacts_page.dart` |
| 新增/编辑、行政区划与地址候选 | `lib/screens/contact_edit_page.dart` |
| 高德 MethodChannel 的 Dart 封装 | `lib/services/amap_service.dart` |
| 地区变化检测与通知 | `lib/services/region_alerts.dart` |
| 原生地图视图 / 标记绘制 | `android/app/src/main/kotlin/io/stardito/nullmap/` |
| 用户可见文案 | `lib/l10n/app_zh.arb`（模板）+ `lib/l10n/app_en.arb` |

## 硬性约定

1. **只用 `package:material_ui/material_ui.dart`。**
   项目依赖的是 Material 3 分支包，`GlobalMaterialLocalizations` 也来自它。混用 `flutter/material.dart` 或 `flutter_localizations` 会因类型不同报 `No MaterialLocalizations found`，中文 Material 文案也会失效。理由见 `lib/core/localizations.dart` 顶部注释。

2. **不要硬编码用户可见文案。**
   在 `app_zh.arb`（模板）与 `app_en.arb` 同时加 key，然后 `flutter gen-l10n`。占位符要写 `@key.placeholders`。`lib/l10n/app_localizations*.dart` 是生成物，不要手改。枚举类选项的显示名统一走 `core/l10n_labels.dart`。

3. **版本号两处同步。**
   改 `pubspec.yaml` 的 `version: x.y.z+n` 时，同步改 `AppInfo.version` 与 `AppInfo.buildNumber`；`test/app_info_test.dart` 会校验，README 顶部的版本号也顺手更新。

4. **注释写中文，标识符写英文。**
   现有代码是「`///` 文档注释 + 行内中文解释原因」的风格，局部变量显式写类型（`final String x`）。新增代码保持一致，注释解释 *为什么*，不要复述代码。

5. **联系人数据必须向后兼容。**
   `Contact.fromJson` 对脏数据要宽容：缺 `id` 返回 `null`，类型不对按空串/`null` 处理，旧版 `location` 字段迁移到 `address`。加新字段时用默认值，别让老 `contacts.json` 直接读崩。

6. **落盘只走 `ContactStore` 的队列。**
   界面先 `notifyListeners()`，文件写入通过 `_schedulePersist()` 串行排队；不要在 UI 回调里直接 `writeAsString`。删除联系人时记得同时删头像文件。

7. **平台能力要降级，不要抛异常。**
   高德地图 / 原生检索 / 通知都只在 Android 可用，调用前判断 `Platform.isAndroid`（或 `AmapService.isSupported`）。通道异常统一转成空结果 / `unsupported` 状态，由界面提示，不让主流程崩。

8. **设置根页只保留三组入口。**
   「通用 / 外观与显示 / 关于项目」这个结构有测试断言（`test/widget_test.dart` 中的「设置页只有三个分组入口」）。新设置项加进对应子页面，而不是塞到根页；确实要加根入口就先改测试并说明原因。

9. **竖屏锁定。**
   `main()` 里 `setPreferredOrientations` 只允许 `portraitUp`，Android Manifest 与 iOS Info.plist 也各自锁了竖屏。不要为了某个页面单独放开旋转。

10. **不要提交敏感文件。**
    `android/key.properties`、`*.keystore` / `*.jks` 已被 `.gitignore` 忽略。`AndroidManifest.xml` 里的高德 Key 是公开的客户端 Key，但绑定「包名 + 签名 SHA1」；改包名或换签名时必须同步更新高德控制台的 Key 配置。

## 原生 ↔ Dart 契约

### 通道与视图

- MethodChannel：`io.stardito.nullmap/amap`
- PlatformView 类型：`io.stardito.nullmap/amap`（`MapPage.amapViewType` 与 `MainActivity` 注册名必须一致）
- AndroidView 的 `creationParams`：`{style: int, ring: int, primary: int}`
- **视图 key 必须包含 style / ring / primary**（`ValueKey('$ring-$primary-${style.index}')`）。这三个参数只在创建时传给原生，key 不变就不会重建，切换地图样式会「点了没反应」。

### 方法一览

| 方向 | 名称 | 参数 | 返回 |
| --- | --- | --- | --- |
| Dart → 原生 | `recenter` | — | `moved` / `locating` / `permission` / `starting` / `unsupported` |
| Dart → 原生 | `moveTo` | `lat`, `lng`, `title` | `moved` / `unsupported` |
| Dart → 原生 | `search` | `keyword` | `[{title, snippet, lat, lng, distance?}]` |
| Dart → 原生 | `inputTips` | `keyword`, `city` | 同上 |
| Dart → 原生 | `districts` | `keyword`, `level` | `[{name, adcode, level, lat, lng}]` |
| Dart → 原生 | `districtCenter` | `keyword`, `level` | `{lat, lng}` 或 `null`（行政区自身中心，不下钻） |
| Dart → 原生 | `currentAddress` | — | `{province, city, district}` 或 `null` |
| Dart → 原生 | `contacts` | `pins: [{id, lat, lng, name, avatar?, ring?}]` | `true` |
| 原生 → Dart | `markerTap` | `{ids: [String]}` | — |

改任何一端都要同步另一端与本节表格；`lat` / `lng` / `snippet` 这些键名是硬约定，不要改名。

**坐标来源与回退**：`Contact.latitude/longitude` 只存详细地址候选的坐标；省 / 市 / 区县候选的中心点存 `regionLatitude/regionLongitude`（`AmapDistrict.hasCenter`，0/0 视为缺失）。地图打点一律用 `isLocatable` 与 `mapLatitude/mapLongitude`，顺序是「详细地址 → 行政区中心」。旧数据只有行政区文字时，`MapPageState._backfillRegionCenters()` 会用 `districtCenter` 补全并写回；不要改成直接读 `latitude`，否则只有省市区的联系人会重新从地图上消失。

### 原生侧不可破坏的行为

- **隐私合规最先执行**：`MainActivity.onCreate` 中 `MapsInitializer.updatePrivacyShow/updatePrivacyAgree` 必须早于任何高德 SDK 调用，包括只查地址时创建定位客户端。
- **ABI 守卫**：高德只提供 arm64-v8a / armeabi-v7a 的 so。`AmapViewFactory` 检测到 x86 系 ABI 时返回 `UnsupportedAbiView` 占位，不要删掉这段判断，否则模拟器会 `UnsatisfiedLinkError`。
- **Debug 复用 Release 签名**是刻意的：高德 Key 校验签名 SHA1，换回 debug 签名会导致地图/POI 返回 `1008`。
- **Release 只打 arm64**：`androidComponents` 里剔除了 v7a / x86 / x86_64 并启用 `useLegacyPackaging`。要支持 32 位设备需同时改打包规则与测试结论。
- **标记恢复**：切换地图样式会重建 PlatformView，`AmapViewBridge.lastPins` 负责在新视图创建后恢复标记，`onCameraChangeFinish` 时按屏幕距离重新聚合（74dp 内叠放，最多 3 个头像 + `+N` 角标），并有 120ms 防抖。不要绕过 `renderPins()` 直接 `addMarker`。
- **点标记走 `markerTap`**：标记上的 `object` 是联系人 id 列表，高德自带信息窗已禁用，由 Dart 弹底部面板。多 id 表示叠放组，面板会先出列表。

## 地区提醒的约定

- 只在应用回到前台（`AppLifecycleState.resumed`）检查一次，不做后台常驻。
- 首次运行只记录基线、不发通知；`regionAlertLast` 为空时直接返回。
- 粒度由 `RegionGranularity` 决定（默认 `city`），联系人匹配用的是同一级字段。
- 通知 payload 格式固定为 `province|city`，`main.dart` 的导航与 `ContactsPage` 的筛选都依赖它；改格式要三处一起改。
- 通知文案走 ARB（`regionAlertTitle` / `regionAlertBody`），不要写死中文。

## 测试

- 提交前至少跑通：`flutter analyze`、`flutter test`。
- Widget 测试里地图是**非 Android 占位画布**，不要断言高德行为（检索、定位、标记点击），这些只能靠真机 `integration_test` 或手动验证。
- 测试用 `InMemorySharedPreferencesAsync` 注入设置，用 `ContactStore.open(directory: tempDir)` 隔离数据目录，`tearDown` 里删临时目录。新增测试沿用 `test/widget_test.dart` 的 `_TestApp` / `pumpApp` 模式。
- 改了用户可见行为就补测试；改了版本号确保 `app_info_test` 仍然通过。
- 涉及地图、定位、通知、签名的改动，必须在 arm64 真机上确认一次再收工。

## 常见坑

| 现象 | 原因 / 处理 |
| --- | --- |
| `No MaterialLocalizations found` | 混用了 `flutter_localizations`；改用 `material_ui` 的委托。 |
| 地图一片空白 / `1008` | 高德 Key 与包名/签名 SHA1 不匹配，或隐私合规调用顺序被改。 |
| 模拟器崩溃 `UnsatisfiedLinkError` | x86 设备没有高德 so，只能看 `UnsupportedAbiView` 占位。 |
| Gradle 报 keystore 为空 | 缺 `android/key.properties`。 |
| 切换地图样式无效 | AndroidView 的 key 没带 style / ring / primary。 |
| 改了中文文案但界面没变 | 忘了 `flutter gen-l10n`，或只改了 `app_en.arb` 没改模板 `app_zh.arb`。 |
| 版本测试失败 | 只改了 `pubspec.yaml` 或只改了 `AppInfo`。 |
| 地区提醒不弹 | Android 13+ 通知权限未授予；或首次运行只记基线；或该地区没有联系人。 |
| 数据「丢了」 | 文档目录不可用时会退回临时目录（`openFallback`），清理缓存后数据消失。 |

## 提交前检查清单

- [ ] `dart format lib test integration_test`
- [ ] `flutter analyze` 无新增问题
- [ ] `flutter test` 全绿
- [ ] 改过 ARB：已 `flutter gen-l10n`，中英文 key 对齐
- [ ] 改过版本：`pubspec.yaml` + `AppInfo` + README 同步
- [ ] 改过地图/通知/签名：arm64 真机验证
- [ ] 没有提交 `key.properties`、keystore、`build/`、`.dart_tool/`

## 工作区提示

本仓库只包含 `nullmap/` 目录。工作区上层（`G:\CodeProject\NullMap` 根）还有逆向分析产物（`_dex/`、`amap-inspect/`、`shot_*.png`、`badging*.txt` 等），**不属于本仓库**：不要引用、不要提交、不要据此推断源码行为。
