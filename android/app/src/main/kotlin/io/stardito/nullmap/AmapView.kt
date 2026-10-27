package io.stardito.nullmap

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.TextView
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapView
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.MarkerOptions
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 高德 3D 地图的 Flutter PlatformView 工厂。
 *
 * 只负责把原生 MapView 交给 Flutter 绘制；标记、底图类型等后续可以在此扩展。
 */
class AmapViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        // 高德 SDK 只提供 arm64-v8a / armeabi-v7a 的 so：x86/x86_64 设备会 UnsatisfiedLinkError。
        // 模拟器 abilist 里会同时列 arm64-v8a（翻译层），所以有 x86 就按不支持处理。
        val abis = Build.SUPPORTED_ABIS
        val supported = abis.none { it.startsWith("x86") } &&
            abis.any { it == "arm64-v8a" || it == "armeabi-v7a" }
        return if (supported) AmapPlatformView(context) else UnsupportedAbiView(context)
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

private class AmapPlatformView(private val context: Context) : PlatformView {
    private val mapView = MapView(context)
    private val lifecycleOwner = context as? LifecycleOwner

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onResume(owner: LifecycleOwner) = mapView.onResume()
        override fun onPause(owner: LifecycleOwner) = mapView.onPause()
        override fun onDestroy(owner: LifecycleOwner) = mapView.onDestroy()
    }

    init {
        // 合规要求：先声明隐私政策并取得同意，再创建地图，否则地图空白。
        MapsInitializer.updatePrivacyShow(context, true, true)
        MapsInitializer.updatePrivacyAgree(context, true)
        mapView.onCreate(Bundle())

        mapView.map.apply {
            uiSettings.isZoomControlsEnabled = false
            uiSettings.isScaleControlsEnabled = false
            uiSettings.isCompassEnabled = true
            mapType = AMap.MAP_TYPE_NORMAL
            moveCamera(CameraUpdateFactory.newLatLngZoom(BEIJING, 12f))
            addMarkers(this)
        }

        lifecycleOwner?.lifecycle?.addObserver(lifecycleObserver)
    }

    override fun getView() = mapView

    override fun dispose() {
        lifecycleOwner?.lifecycle?.removeObserver(lifecycleObserver)
        mapView.onDestroy()
    }

    private fun addMarkers(aMap: AMap) {
        val markers = listOf(
            Triple("节点 A", LatLng(39.920, 116.380), BitmapDescriptorFactory.HUE_GREEN),
            Triple("节点 B", LatLng(39.930, 116.420), BitmapDescriptorFactory.HUE_ORANGE),
            Triple("节点 C", LatLng(39.895, 116.405), BitmapDescriptorFactory.HUE_BLUE),
        )
        for ((title, position, hue) in markers) {
            aMap.addMarker(
                MarkerOptions()
                    .position(position)
                    .title(title)
                    .icon(BitmapDescriptorFactory.defaultMarker(hue)),
            )
        }
    }

    private companion object {
        val BEIJING = LatLng(39.909, 116.397)
    }
}
