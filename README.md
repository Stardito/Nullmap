# NullMap · 零点地图

> 一个用来记录朋友所在位置的地图 App。

用一张地图记住朋友们都在哪里：给每个人记下昵称、QQ / 微信 / 电话和所在地，地图上就会显示他的头像标记；等你换了城市，它还会提醒你这个新地方附近有几位朋友。

- 技术栈：Flutter + Material 3 + 高德地图 Android SDK
- 当前版本：1.1.3 (21)
- 开发者：[Stardito](https://github.com/Stardito)
- 仓库：[Stardito/Nullmap](https://github.com/Stardito/Nullmap)

> 平台现状：**Android 为完整功能平台**；iOS 目前只跑通 Flutter 外壳，地图页显示占位网格。

---

## 目录

- [功能一览](#功能一览)
- [快速开始](#快速开始)
- [高德 Key 与签名](#高德-key-与签名)
- [目录结构](#目录结构)
- [架构说明](#架构说明)
- [数据与隐私](#数据与隐私)
- [测试](#测试)
- [已知限制](#已知限制)
- [许可证](#许可证)

---

## 功能一览

### 地图

- 高德 3D 底图，支持 **标准 / 卫星 / 地形** 三种样式（在「外观与显示」中切换）
- 右下角定位按钮：回到设备当前位置，权限缺失、定位失败、ABI 不支持都有对应提示
- 地点搜索：原生侧先搜当前位置 50 km 内并按距离排序，再合并全国结果；仍为空时依次用「输入提示 → 地理编码」兜底
- 搜索结果带「距您 xx」距离标签，点一下镜头飞到该地点并打点
- 有坐标的联系人在图上显示为**圆形头像标记**（描边色取自头像的 Monet 主色）
- 坐标优先取选中的详细地点；**只精确到省 / 市 / 区**时用行政区中心点打点，旧数据首次进地图会自动补全
- 点击标记弹出 Material 3 底部面板：单个联系人直接显示概览，多人重叠时先出列表
- 地图内可直接按姓名 / 昵称 / QQ / 微信 / 电话 / 所在地搜索联系人并跳转

### 联系人

- 字段：姓名、昵称、QQ、微信、手机号、国家、省、市、区县、详细地址、头像
- 新增只要求至少填一项联系方式，展示时按「昵称 → 姓名 → QQ → 微信 → 手机号」取显示名
- 所在地：国家从常用国家/地区中选，省 / 市 / 区县走**高德行政区划候选**，详细地址带**高德输入提示**，选中候选时顺带记录经纬度
- 头像优先级：**本地图片 > QQ 头像（自动拉取 640px 高清）> 名字首字**
- 详情页背景是按头像取色生成的竖向渐变；支持打开 QQ 名片、拨号、编辑、删除
- 列表支持关键字搜索 + 国家 / 省 / 市 / 区县逐级筛选

### 地区提醒

- 回到前台时检测当前定位的**省 / 市 / 区**是否变化（粒度可配）
- 变化且该地区有联系人时，发一条本地通知，例如「3 contacts in 淄博市」
- 点通知会清空页面栈回到根页面，跳到联系人页并自动套用该地区筛选
- 首次运行只记录基线、不发通知，避免刚装好就弹窗

### 设置与外观

| 分组 | 选项 |
| --- | --- |
| 通用 | 显示语言（跟随系统 / 简体中文 / English）、地区提醒开关、提醒粒度（省 / 市 / 区） |
| 外观与显示 | 明暗模式（跟随系统 / 浅色 / 深色）、主题色（跟随壁纸取色 + 蓝 / 绿 / 橙 / 紫 / 青 / 红）、地图样式（标准 / 卫星 / 地形） |
| 关于 | 程序名、版本、开发者、开源仓库、开源许可 |

- Android 12+ 默认使用**壁纸动态取色**（`dynamic_color`），系统不支持时回退到品牌蓝 `#3D5AFE`
- 全应用锁定**竖屏**，旋转设备时界面不翻转
- 中英文文案由 ARB 生成，`AppInfo` 是版本 / 作者 / 仓库地址的唯一来源（有测试校验与 `pubspec.yaml` 一致）

---

## 快速开始

### 环境要求

| 项目 | 要求 |
| --- | --- |
| Flutter | 提供 Dart `^3.13.7`，且包含 `material_ui` 所需的 Material 3 支持 |
| JDK | 17（Android 构建，Kotlin `jvmTarget = 17`） |
| Android SDK | 由 Flutter 默认 `compileSdk` / `minSdk` / `targetSdk` 决定 |
| 设备 | **arm64-v8a 真机**（高德 SDK 只提供 arm64-v8a / armeabi-v7a 的 so） |

### 拉取依赖并运行

```bash
cd nullmap
flutter pub get
flutter run
```

`pubspec.yaml` 已开启 `generate: true`，多语言代码会在构建时自动生成；也可以手动执行：

```bash
flutter gen-l10n      # 配置见 l10n.yaml，模板为 lib/l10n/app_zh.arb
```

### 构建发布包

```bash
flutter build apk --release        # 产物只含 arm64-v8a
flutter build appbundle --release
```

Release 变体会主动剔除 `armeabi-v7a` / `x86` / `x86_64` 的 so 并启用 `useLegacyPackaging`，以缩小包体；Debug 变体保留其他 ABI 供模拟器调试（但高德地图本身不支持 x86，界面会显示不支持提示）。

### 其他常用命令

```bash
flutter analyze
flutter test
```

---

## 高德 Key 与签名

高德 Key 绑定 **应用包名 + 签名 SHA1**，签名对不上时地图和检索会返回错误码 `1008`。

1. 包名固定为 `io.stardito.nullmap`（见 `android/app/build.gradle.kts`）。
2. `android/app/src/main/AndroidManifest.xml` 里的 `com.amap.api.v2.apikey` 决定使用哪个 Key。
3. 仓库中的 Debug 与 Release **共用同一个 release 签名**（`signingConfigs.release`），因此本地调试也能正常出图。
4. 签名信息从 `android/key.properties` 读取，该文件已被 `.gitignore` 忽略，需要自己新建：

```properties
storeFile=../nullmap.release.keystore
storePassword=******
keyAlias=******
keyPassword=******
```

> 复制本项目自建时：把 `AndroidManifest.xml` 里的 Key 换成你自己在高德开放平台申请的 Key，并把你的签名 SHA1 填进高德控制台；同时把 `key.properties` 指向你自己的 keystore。
>
> 高德的隐私合规声明（`MapsInitializer.updatePrivacyShow/updatePrivacyAgree`）已在 `MainActivity.onCreate` 中先于任何 SDK 调用完成，请勿删除或后移。

### Android 权限

`ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`ACCESS_BACKGROUND_LOCATION`、`POST_NOTIFICATIONS`、`INTERNET`、`ACCESS_NETWORK_STATE`、`ACCESS_WIFI_STATE`、`ACCESS_LOCATION_EXTRA_COMMANDS`，以及 API 28 及以下的读写外部存储权限。

首次启动就会申请定位权限；前台定位授权后还会再申请一次「始终允许」，用于后台地区变化检测。通知权限在启动时申请（Android 13+ 不授权会被系统静默丢弃）。

---

## 目录结构

```
nullmap/
├─ lib/
│  ├─ main.dart                  # 启动、主题/语言装配、通知点击导航
│  ├─ core/
│  │  ├─ app_info.dart           # 程序名、版本、开发者、仓库地址（唯一来源）
│  │  ├─ app_settings.dart       # 语言 / 地图样式 / 主题 / 地区提醒（SharedPreferences）
│  │  ├─ l10n_labels.dart        # 枚举值到本地化文案的映射
│  │  └─ localizations.dart      # 本地化委托与支持语言
│  ├─ data/
│  │  ├─ contact.dart            # 联系人模型、JSON（含旧版 location 迁移）
│  │  └─ contact_store.dart      # JSON 持久化 + 头像文件 + 串行落盘队列
│  ├─ screens/
│  │  ├─ home_screen.dart        # 底部导航宿主（地图 / 联系人 / 设置）
│  │  ├─ map_page.dart           # PlatformView、标记同步、地点/联系人搜索
│  │  ├─ contacts_page.dart      # 列表、搜索、地区筛选、详情页
│  │  ├─ contact_edit_page.dart  # 新增/编辑、行政区划与地址候选、头像选择
│  │  └─ settings_*.dart         # 通用 / 外观与显示 / 关于
│  ├─ services/
│  │  ├─ amap_service.dart       # `io.stardito.nullmap/amap` 通道的 Dart 封装
│  │  ├─ avatar_bytes.dart       # 本地/QQ 头像字节缓存（地图标记与取色共用）
│  │  ├─ external_apps.dart      # 打开 QQ 名片、拨号
│  │  ├─ monet.dart              # 图片主色提取（Material You 算法）
│  │  └─ region_alerts.dart      # 地区变化检测与本地通知
│  ├─ theme/app_theme.dart       # Material 3 主题、种子色
│  ├─ widgets/                   # 头像、地图底部面板
│  └─ l10n/                      # ARB 源文件与生成代码
├─ android/app/src/main/kotlin/io/stardito/nullmap/
│  ├─ MainActivity.kt            # 通道注册、POI/行政区划/输入提示/地理编码、定位
│  ├─ AmapView.kt                # 高德 MapView 的 PlatformView、定位、头像标记
│  └─ ContactMarkerRenderer.kt   # 圆形头像 marker 位图绘制
├─ ios/                          # Flutter 外壳（暂无地图 SDK）
├─ test/                         # 单元与 Widget 测试
└─ integration_test/             # 真机冒烟测试
```

---

## 架构说明

**启动链路**：`main()` 锁定竖屏 → 打开 `ContactStore`（失败则退回临时目录）→ `runApp` → `NullMapApp` 加载 `AppSettings`、初始化通知、申请权限、检查地区。`ContactStore` 与 `AppSettings` 都通过 `InheritedNotifier`（`ContactScope` / `AppSettingsScope`）下发到子树，改动即时通知界面。

**地图链路**：Dart 通过 `AndroidView` 创建 `PlatformView`（类型 `io.stardito.nullmap/amap`），创建参数携带地图样式与取色结果；地图相关操作走 `MethodChannel`，联系方式是「原生画标记、Dart 管数据」：

- Dart → 原生：`recenter`、`moveTo`、`search`、`inputTips`、`districts`、`currentAddress`、`contacts`（同步标记）
- 原生 → Dart：`markerTap`（被点中的联系人 id 列表）

标记同步会先算签名，只有数据变化时才重新推送；原生侧缓存最后一批标记，切换地图样式重建视图后自动恢复。地图打点的坐标按「详细地址 → 省/市/区中心」回退，行政区中心由原生按名称查询并缓存，补全结果会写回 `contacts.json`。

**存储**：联系人写入应用文档目录的 `contacts.json`，头像存在 `avatars/<contactId>.<ext>`。写入是串行的 Promise 队列（界面先更新、文件后台排队），读取失败或数据损坏一律按空列表处理，不阻塞启动；删除联系人时一并删掉头像文件。旧版本只有 `location` 字段的数据会在读取时迁移到 `address`。

**地区提醒**：`WidgetsBindingObserver` 在 `resumed` 时触发检测，原生取一次省/市/区（8 秒超时视为未知，避免误报），与上次记录比较后决定是否发通知，payload 携带省市用于点击后筛选。

---

## 数据与隐私

- 联系人数据**只存在本机**，没有账号体系、没有自建服务器、没有云同步；卸载应用即丢失，请自行备份。
- 会联网的场景只有两类：高德 SDK 的地图瓦片 / 搜索 / 定位，以及按 QQ 号拉取头像（`q.qlogo.cn`）。
- 删除联系人会同时删除本地头像文件；地点选择只记录文本与坐标，不记录轨迹。
- 定位权限用于「当前位置」「附近搜索」与地区提醒；「始终允许」只在用户主动授权后生效。

---

## 测试

```bash
flutter test
```

覆盖内容：

- `test/app_info_test.dart`：校验 `AppInfo` 的版本号与 `pubspec.yaml` 一致，以及「关于」信息完整
- `test/contact_test.dart`：校验「详细地址坐标优先、行政区中心兜底」的取坐标规则与 JSON 向后兼容
- `test/widget_test.dart`：在内存版 SharedPreferences 与临时目录下验证导航、联系人增删改、地图标记同步、底部面板与主题行为

真机冒烟测试（需要联网、定位权限，且已卸载旧签名版本）：

```bash
flutter test integration_test/map_search_test.dart -d <设备序列号>
```

它会在真实地图上搜索「万丽花园」，断言结果包含目标地点且至少两条带「距您」距离标签，用于验证「原生检索 → 距离排序 → Dart 列表」整条链路。

---

## 已知限制

- **仅支持 arm64-v8a 真机**：高德 SDK 不提供 x86 / x86_64 的 so，模拟器会显示「不支持当前设备 ABI」占位页。
- **iOS 暂无地图**：iOS 侧只有 Flutter 外壳，地图页显示经纬网格占位画布；地区提醒与通知也仅 Android 生效。
- **地区提醒不是后台常驻**：只在应用回到前台时检查，不会在后台持续轮询。
- 发布包按单一 ABI 打包，armeabi-v7a 设备安装的是 debug 构建或需要自行放开 Gradle 中的 ABI 排除规则。
- 数据无导入 / 导出与备份功能，换机需要手动迁移 `contacts.json` 与 `avatars/`。

---

## 许可证

仓库目前**尚未包含** `LICENSE` 文件。在补充许可证之前，默认保留所有权利；如需引用或二次分发，请先联系作者。
