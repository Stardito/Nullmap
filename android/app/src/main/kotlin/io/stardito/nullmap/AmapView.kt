package io.stardito.nullmap

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.TextView
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.amap.api.location.AMapLocation
import com.amap.api.location.AMapLocationClient
import com.amap.api.location.AMapLocationClientOption
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.LocationSource
import com.amap.api.maps.MapView
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.Projection
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.CameraPosition
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.hypot

/** 当前存活的 [AmapPlatformView]，供 MainActivity 的方法通道与权限回调使用。 */
internal object AmapViewBridge {
    @Volatile
    var current: AmapPlatformView? = null

    /** 地图是否真的可用（只有 arm64/armv7 设备才加载得到高德 so）。 */
    @Volatile
    var supported: Boolean = false

    /** 最近一次同步的联系人标记；切换地图样式重建视图后用它恢复。 */
    @Volatile
    var lastPins: List<ContactPin> = emptyList()

    /** 标记被点击时回调（联系人 id 列表），由 MainActivity 转给 Flutter 弹底部面板。 */
    @Volatile
    var onMarkerTap: ((List<String>) -> Unit)? = null
}

/**
 * 高德 3D 地图的 Flutter PlatformView 工厂。
 *
 * creationParams:
 * - `style`: 0 标准 / 1 卫星 / 2 地形，对应 [MapStyle]
 */
class AmapViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val style = (params?.get("style") as? Number)?.toInt() ?: 0
        // 头像描边用中性色；当前位置标记用主题主色。
        val ring = (params?.get("ring") as? Number)?.toInt()
            ?: (params?.get("surface") as? Number)?.toInt()
            ?: 0xFFFFFFFF.toInt()
        val primary = (params?.get("primary") as? Number)?.toInt() ?: 0xFF3D5AFE.toInt()

        // 高德 SDK 只提供 arm64-v8a / armeabi-v7a 的 so：x86/x86_64 设备会 UnsatisfiedLinkError。
        // 模拟器 abilist 里会同时列 arm64-v8a（翻译层），所以有 x86 就按不支持处理。
        val abis = Build.SUPPORTED_ABIS
        val supported = abis.none { it.startsWith("x86") } &&
            abis.any { it == "arm64-v8a" || it == "armeabi-v7a" }
        AmapViewBridge.supported = supported
        Log.d(TAG, "create style=$style supported=$supported abis=${abis.joinToString()}")
        return if (supported) {
            AmapPlatformView(context, style, ring, primary)
        } else {
            UnsupportedAbiView(context)
        }
    }

    private companion object {
        const val TAG = "NullMapAmap"
    }
}

private class UnsupportedAbiView(context: Context) : PlatformView {
    private val text = TextView(context).apply {
        text = "高德地图 SDK 不支持当前设备 ABI（${Build.SUPPORTED_ABIS.joinToString()}）\n请使用 arm64-v8a 真机运行"
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        setPadding(48, 48, 48, 48)
    }

    override fun getView(): View = text

    override fun dispose() {}
}

/**
 * 高德地图视图：底图 + 设备定位。
 *
 * 首次获得定位后自动把镜头移到设备所在位置；右下角定位按钮通过
 * `io.stardito.nullmap/amap` 通道的 `recenter` 方法回到当前位置。
 */
internal class AmapPlatformView(
    private val context: Context,
    private val style: Int,
    private val ringColor: Int,
    private val primaryColor: Int,
) : PlatformView, LocationSource {
    private val mapView = MapView(context)
    private val lifecycleOwner = context as? LifecycleOwner

    private var locationClient: AMapLocationClient? = null
    private var locationListener: LocationSource.OnLocationChangedListener? = null
    private var lastLocation: AMapLocation? = null

    /** 系统定位兜底（高德定位服务被 VPN 或网络策略挡住时使用），已是 GCJ-02 坐标。 */
    private var fallbackPoint: LatLng? = null
    private var deviceMarker: Marker? = null
    private var centeredOnUser = false
    private var searchMarker: Marker? = null
    private var permissionRequested = false

    /** 联系人点位与当前渲染出来的标记。 */
    private var contactPins: List<ContactPin> = emptyList()
    private val contactMarkers = mutableListOf<Marker>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val renderPinsRunnable = Runnable { renderPins() }

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onResume(owner: LifecycleOwner) = mapView.onResume()
        override fun onPause(owner: LifecycleOwner) = mapView.onPause()
        override fun onDestroy(owner: LifecycleOwner) = mapView.onDestroy()
    }

    init {
        // 合规要求：先声明隐私政策并取得同意，再创建地图，否则地图空白。
        MapsInitializer.updatePrivacyShow(context, true, true)
        MapsInitializer.updatePrivacyAgree(context, true)
        // AMap 没有 MAP_TYPE_TERRAIN：地形通过 3D 地形开关叠加在标准底图上。
        MapsInitializer.setTerrainEnable(style == STYLE_TERRAIN)
        mapView.onCreate(Bundle())

        mapView.map.apply {
            uiSettings.isZoomControlsEnabled = false
            uiSettings.isScaleControlsEnabled = false
            uiSettings.isCompassEnabled = true
            mapType = if (style == STYLE_SATELLITE) {
                AMap.MAP_TYPE_SATELLITE
            } else {
                AMap.MAP_TYPE_NORMAL
            }
            // 不用高德自带蓝点：位置由我们自己画 Material 风格标记，镜头也完全自己控制。
            setMyLocationEnabled(false)
            setOnMarkerClickListener { marker ->
                val ids = marker.getObject() as? List<*>
                if (ids.isNullOrEmpty()) {
                    false
                } else {
                    AmapViewBridge.onMarkerTap?.invoke(ids.map { "$it" })
                    true
                }
            }
            setOnCameraChangeListener(
                object : AMap.OnCameraChangeListener {
                    override fun onCameraChange(position: CameraPosition?) {
                        // 拖动/缩放过程中不重绘，等停下来再聚合。
                    }

                    override fun onCameraChangeFinish(position: CameraPosition?) {
                        schedulePinRender()
                    }
                },
            )
            moveCamera(CameraUpdateFactory.newLatLngZoom(BEIJING, 12f))
        }

        AmapViewBridge.current = this
        lifecycleOwner?.lifecycle?.addObserver(lifecycleObserver)
        ensureLocation()
        if (AmapViewBridge.lastPins.isNotEmpty()) {
            setPins(AmapViewBridge.lastPins)
        }
    }

    override fun getView() = mapView

    /** 更新联系人标记（Dart 侧联系人数据变化时调用）。 */
    fun setPins(pins: List<ContactPin>) {
        contactPins = pins
        renderPins()
    }

    private fun schedulePinRender() {
        mainHandler.removeCallbacks(renderPinsRunnable)
        mainHandler.postDelayed(renderPinsRunnable, 120L)
    }

    /** 按当前缩放与位置重绘联系人标记；重叠的自动叠放成组。 */
    private fun renderPins() {
        clearContactMarkers()
        if (contactPins.isEmpty()) {
            return
        }
        val map = mapView.map
        val groups = clusterPins(map.projection)
        for (group in groups) {
            val bitmap = if (group.size == 1) {
                ContactMarkerRenderer.single(context, group.first(), ringColor)
            } else {
                ContactMarkerRenderer.cluster(context, group, ringColor)
            }
            // 叠放组抬高一层：角标突出在位图右上方，很容易被旁边的单体标记
            // 压住，看起来像被裁掉了一角。
            val marker = map.addMarker(
                MarkerOptions()
                    .position(groupCenter(group))
                    .icon(BitmapDescriptorFactory.fromBitmap(bitmap))
                    .anchor(0.5f, 0.5f)
                    .zIndex(if (group.size > 1) 8f else 2f)
                    .title(""),
            )
            if (marker != null) {
                // 用 Material 底部面板代替高德自带信息窗。
                marker.setInfoWindowEnable(false)
                marker.setObject(group.map { it.id })
                contactMarkers.add(marker)
            }
        }
        Log.d(TAG, "render pins=${contactPins.size} groups=${groups.size}")
    }

    private fun clearContactMarkers() {
        contactMarkers.forEach { it.remove() }
        contactMarkers.clear()
    }

    /** 按屏幕距离聚合：同一屏幕上 74dp 内的联系人共用一个叠放标记。 */
    private fun clusterPins(projection: Projection): List<List<ContactPin>> {
        val threshold = 74f * context.resources.displayMetrics.density
        val groups = mutableListOf<MutableList<ContactPin>>()
        val screens = mutableListOf<android.graphics.Point>()
        for (pin in contactPins) {
            val point = projection.toScreenLocation(LatLng(pin.latitude, pin.longitude))
            var hit = -1
            for (index in screens.indices) {
                val dx = (screens[index].x - point.x).toFloat()
                val dy = (screens[index].y - point.y).toFloat()
                if (hypot(dx, dy) <= threshold) {
                    hit = index
                    break
                }
            }
            if (hit >= 0) {
                groups[hit].add(pin)
                screens[hit] = point
            } else {
                groups.add(mutableListOf(pin))
                screens.add(point)
            }
        }
        return groups
    }

    private fun groupCenter(group: List<ContactPin>): LatLng {
        var lat = 0.0
        var lng = 0.0
        for (pin in group) {
            lat += pin.latitude
            lng += pin.longitude
        }
        return LatLng(lat / group.size, lng / group.size)
    }

    override fun dispose() {
        mainHandler.removeCallbacks(renderPinsRunnable)
        clearContactMarkers()
        // 切换地图样式会重建 PlatformView：新视图可能先创建、旧视图后销毁，
        // 只有当前视图仍是自己时才清空，否则定位按钮会误判为「不支持」。
        if (AmapViewBridge.current === this) {
            AmapViewBridge.current = null
        }
        locationClient?.stopLocation()
        locationClient?.onDestroy()
        locationClient = null
        locationListener = null
        lifecycleOwner?.lifecycle?.removeObserver(lifecycleObserver)
        mapView.onDestroy()
    }

    // region LocationSource

    override fun activate(listener: LocationSource.OnLocationChangedListener?) {
        locationListener = listener
        ensureLocation()
    }

    override fun deactivate() {
        locationListener = null
    }

    // endregion

    /** 当前设备定位（未定位成功时为 null），供搜索按距离优先排序。 */
    fun currentLocation(): AMapLocation? = lastLocation

    /** 当前设备坐标：优先高德定位，其次系统最近一次定位（已转 GCJ-02）。 */
    fun currentLatLng(): LatLng? =
        lastLocation?.let { LatLng(it.latitude, it.longitude) } ?: fallbackPoint

    /** 搜索结果跳转：清除上一个搜索标记，移动镜头并标出目标点。 */
    fun moveTo(lat: Double?, lng: Double?, title: String?): Boolean {
        if (lat == null || lng == null) {
            return false
        }
        val target = LatLng(lat, lng)
        searchMarker?.remove()
        val icon = BitmapDescriptorFactory.fromBitmap(
            ContactMarkerRenderer.pin(context, primaryColor),
        )
        searchMarker = mapView.map.addMarker(
            MarkerOptions()
                .position(target)
                .anchor(0.5f, 1f)
                .icon(icon)
                .zIndex(25f)
                .title(""),
        )?.also { it.setInfoWindowEnable(false) }
        centeredOnUser = true
        mapView.map.animateCamera(CameraUpdateFactory.newLatLngZoom(target, 16f))
        return true
    }

    /** 定位按钮：优先复用最近一次定位，否则重新发起定位。 */
    fun recenterStatus(): String {
        val location = lastLocation
        if (location != null) {
            centerOn(location)
            return "moved"
        }
        val fallback = fallbackPoint
        if (fallback != null) {
            centerOn(fallback)
            return "moved"
        }
        if (!hasLocationPermission()) {
            // 用户主动点了定位，这里可以再申请一次权限。
            requestPermission(manual = true)
            return "permission"
        }
        startLocation()
        return "locating"
    }

    /** MainActivity 收到定位权限结果后转发到这里。 */
    fun onPermissionResult(granted: Boolean) {
        permissionRequested = false
        if (granted) {
            startLocation()
        } else {
            Log.w(TAG, "location permission denied")
        }
    }

    private fun ensureLocation() {
        if (hasLocationPermission()) {
            startLocation()
            seedSystemLocation()
        } else {
            // 没有权限就主动申请（MainActivity 启动时也会申请，这里依靠去抖避免重复弹窗）。
            requestPermission()
        }
    }

    /**
     * 用系统最近一次定位兜底。
     *
     * 高德定位依赖自家服务端，部分网络环境（VPN/代理/受限 WiFi）会返回 errorCode=8；
     * 系统 GPS 缓存不依赖网络，可以先让地图和搜索拥有当前位置。
     */
    private fun seedSystemLocation() {
        if (fallbackPoint != null) {
            return
        }
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
        val candidates = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        ).mapNotNull { provider ->
            runCatching { manager.getLastKnownLocation(provider) }.getOrNull()
        }
        val newest: Location = candidates.maxByOrNull { it.time } ?: return
        if (System.currentTimeMillis() - newest.time > SYSTEM_LOCATION_MAX_AGE_MS) {
            Log.d(TAG, "system location too old: ${newest.time}")
            return
        }
        val point = wgs84ToGcj02(newest.latitude, newest.longitude)
        fallbackPoint = point
        Log.d(TAG, "system location ${newest.latitude},${newest.longitude} -> gcj02 $point")
        showDeviceMarker(point)
    }

    /** 当前位置标记：Material 风格圆点（主色光晕 + 白环 + 实心圆），替换高德自带蓝点。 */
    private fun showDeviceMarker(point: LatLng) {
        deviceMarker?.remove()
        // 兜底：确认高德自带蓝点始终关闭，位置只用下面这个 Material 圆点表示。
        mapView.map.setMyLocationEnabled(false)
        val icon = BitmapDescriptorFactory.fromBitmap(
            ContactMarkerRenderer.location(context, primaryColor),
        )
        deviceMarker = mapView.map.addMarker(
            MarkerOptions()
                .position(point)
                .anchor(0.5f, 0.5f)
                .icon(icon)
                // 层级压到联系人标记（单体 2、叠放组 8）之下：
                // 自己和联系人重合时，头像应该盖住当前位置的白点。
                .zIndex(1f)
                .title(""),
        )?.also { it.setInfoWindowEnable(false) }
        if (!centeredOnUser) {
            centeredOnUser = true
            centerOn(point)
        }
    }

    private fun hasLocationPermission(): Boolean =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestPermission(manual: Boolean = false) {
        val activity = context as? Activity ?: return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // 自动申请只做一次：用户拒绝过后，后续启动不再自动弹窗（点定位按钮仍可主动申请）。
        if (!manual && prefs.getBoolean(KEY_PERMISSION_ASKED, false)) {
            return
        }
        val elapsed = System.currentTimeMillis() - lastPermissionRequestAt
        if (permissionRequested || elapsed < PERMISSION_REQUEST_DEBOUNCE_MS) {
            return
        }
        permissionRequested = true
        lastPermissionRequestAt = System.currentTimeMillis()
        prefs.edit().putBoolean(KEY_PERMISSION_ASKED, true).apply()
        Log.d(TAG, "request location permission manual=$manual")
        activity.requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            REQ_LOCATION,
        )
    }

    private fun startLocation() {
        if (!hasLocationPermission()) {
            return
        }
        val client = locationClient ?: createLocationClient()
        client.startLocation()
    }

    private fun createLocationClient(): AMapLocationClient {
        val client = AMapLocationClient(context.applicationContext)
        // 需要地址信息：搜索时可用当前城市做候选限制。
        val option = AMapLocationClientOption()
            .setLocationMode(AMapLocationClientOption.AMapLocationMode.Hight_Accuracy)
            .setOnceLocation(false)
            .setNeedAddress(true)
            .setInterval(2000L)
        client.setLocationOption(option)
        client.setLocationListener { location ->
            if (location == null || location.errorCode != 0) {
                Log.w(TAG, "location error code=${location?.errorCode}")
                return@setLocationListener
            }
            lastLocation = location
            locationListener?.onLocationChanged(location)
            showDeviceMarker(LatLng(location.latitude, location.longitude))
            if (!centeredOnUser) {
                centeredOnUser = true
                centerOn(location)
            }
        }
        locationClient = client
        return client
    }

    private fun centerOn(location: AMapLocation) {
        centerOn(LatLng(location.latitude, location.longitude))
    }

    private fun centerOn(target: LatLng) {
        mapView.map.animateCamera(CameraUpdateFactory.newLatLngZoom(target, 16f))
    }

    /** WGS-84 转 GCJ-02（国内地图坐标系），算法为业界通用近似实现。 */
    private fun wgs84ToGcj02(latitude: Double, longitude: Double): LatLng {
        val a = 6378245.0
        val ee = 0.00669342162296594323
        fun transformLat(x: Double, y: Double): Double {
            var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x))
            ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0
            ret += (20.0 * Math.sin(y * Math.PI) + 40.0 * Math.sin(y / 3.0 * Math.PI)) * 2.0 / 3.0
            ret += (160.0 * Math.sin(y / 12.0 * Math.PI) + 320 * Math.sin(y * Math.PI / 30.0)) * 2.0 / 3.0
            return ret
        }
        fun transformLng(x: Double, y: Double): Double {
            var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x))
            ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0
            ret += (20.0 * Math.sin(x * Math.PI) + 40.0 * Math.sin(x / 3.0 * Math.PI)) * 2.0 / 3.0
            ret += (150.0 * Math.sin(x / 12.0 * Math.PI) + 300.0 * Math.sin(x / 30.0 * Math.PI)) * 2.0 / 3.0
            return ret
        }
        val dLat = transformLat(longitude - 105.0, latitude - 35.0)
        val dLng = transformLng(longitude - 105.0, latitude - 35.0)
        val radLat = latitude / 180.0 * Math.PI
        var magic = Math.sin(radLat)
        magic = 1 - ee * magic * magic
        val sqrtMagic = Math.sqrt(magic)
        val mgLat = latitude + (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Math.PI)
        val mgLng = longitude + (dLng * 180.0) / (a / sqrtMagic * Math.cos(radLat) * Math.PI)
        return LatLng(mgLat, mgLng)
    }

    companion object {
        const val TAG = "NullMapAmap"

        /** 与 MainActivity 的权限回调 requestCode 一致。 */
        const val REQ_LOCATION = 4301

        /** 记录「已自动申请过一次定位权限」，避免每次启动都弹窗。 */
        const val PREFS_NAME = "nullmap_permissions"
        const val KEY_PERMISSION_ASKED = "location_permission_asked"

        /** 后台定位权限：用于"所在城市变了"提醒。 */

        /** 启动时 MainActivity 已申请过权限，短时间内不再重复弹窗。 */
        const val PERMISSION_REQUEST_DEBOUNCE_MS = 5000L

        /** 系统定位缓存超过该时长就认为已过期。 */
        const val SYSTEM_LOCATION_MAX_AGE_MS = 30 * 60 * 1000L

        @Volatile
        var lastPermissionRequestAt = 0L

        val BEIJING = LatLng(39.909, 116.397)

        /** 与 Dart 端 MapStyle.index 一致。 */
        const val STYLE_SATELLITE = 1
        const val STYLE_TERRAIN = 2
    }
}
