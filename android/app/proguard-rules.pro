# 高德地图 SDK：native 层按类名反射查找 Java 类，R8 改名或裁剪会导致
# JNI DETECTED ERROR（java_class == null），必须整体保留。
-keep class com.amap.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.loc.** { *; }

-dontwarn com.amap.**
-dontwarn com.autonavi.**
-dontwarn com.loc.**
