import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release 签名配置从 android/key.properties 读取，避免把口令写进版本库。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "io.stardito.nullmap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 要求开启 core library desugaring。
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "io.stardito.nullmap"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    androidComponents {
        // 只发布 arm64-v8a：剔掉高德自带的 v7a 库，避免同一个 APK 装两份地图引擎。
        // 只作用于 release，debug 仍保留 x86_64 供模拟器使用。
        onVariants(selector().withBuildType("release")) { variant ->
            variant.packaging.jniLibs.excludes.addAll(
                listOf("lib/armeabi-v7a/**", "lib/x86/**", "lib/x86_64/**"),
            )
            // 压缩 .so：APK 体积更小，代价是安装时解压（占用略大、首次启动稍慢）。
            variant.packaging.jniLibs.useLegacyPackaging.set(true)
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        debug {
            // 高德 key 绑定包名 + 签名 SHA1；debug 也用同一个签名，否则
            // 地图/POI 检索会返回 1008（签名校验失败）。
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            // 高德 SDK 依赖类名反射，保留规则见 proguard-rules.pro。
            proguardFiles("proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 高德 3D 地图 + 定位 + 搜索合并包（官方 Maven Central 发布）。
    implementation("com.amap.api:3dmap-location-search:11.3.100_loc11.3.101_sea9.8.1")
    // 通知插件用到的 java.time 在低版本 Android 上需要脱糖库。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
