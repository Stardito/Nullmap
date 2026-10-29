package io.stardito.nullmap

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.amap.api.location.AMapLocation
import com.amap.api.location.AMapLocationClient
import com.amap.api.location.AMapLocationClientOption
import com.amap.api.maps.MapsInitializer
import com.amap.api.services.core.AMapException
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.district.DistrictItem
import com.amap.api.services.district.DistrictSearch
import com.amap.api.services.district.DistrictSearchQuery
import com.amap.api.services.geocoder.GeocodeQuery
import com.amap.api.services.geocoder.GeocodeResult
import com.amap.api.services.geocoder.GeocodeSearch
import com.amap.api.services.geocoder.RegeocodeResult
import com.amap.api.services.help.Inputtips
import com.amap.api.services.help.InputtipsQuery
import com.amap.api.services.poisearch.PoiResult
import com.amap.api.services.poisearch.PoiSearch
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    /** 地图通道：原生标记点击时反向调用 Dart 显示底部面板。 */
    private var amapChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 隐私声明必须早于任何高德 SDK 调用（包括只查地址时创建定位客户端）。
        runCatching {
            MapsInitializer.updatePrivacyShow(applicationContext, true, true)
            MapsInitializer.updatePrivacyAgree(applicationContext, true)
        }
        // 首次启动就申请定位权限，而不是等地图第一次需要定位时才弹窗。
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            AmapPlatformView.lastPermissionRequestAt = System.currentTimeMillis()
            requestPermissions(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                AmapPlatformView.REQ_LOCATION,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            // 前台定位已授权后再要「始终允许」，系统会弹一次权限页。
            requestPermissions(
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                AmapPlatformView.REQ_BACKGROUND_LOCATION,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("io.stardito.nullmap/amap", AmapViewFactory())

        // 地图操作通道：定位回中、地点搜索、跳转到搜索结果、行政区划与地点候选。
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AMAP_CHANNEL,
        )
        amapChannel = channel
        AmapViewBridge.onMarkerTap = { ids ->
            runOnUiThread {
                amapChannel?.invokeMethod("markerTap", mapOf("ids" to ids))
            }
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "recenter" -> {
                    val view = AmapViewBridge.current
                    result.success(
                        when {
                            view != null -> view.recenterStatus()
                            // 视图还没建好：别谎报 ABI 不支持。
                            AmapViewBridge.supported -> "starting"
                            else -> "unsupported"
                        },
                    )
                }

                "moveTo" -> {
                    val lat = (call.argument<Number>("lat"))?.toDouble()
                    val lng = (call.argument<Number>("lng"))?.toDouble()
                    val title = call.argument<String>("title")
                    val moved = AmapViewBridge.current?.moveTo(lat, lng, title) ?: false
                    result.success(if (moved) "moved" else "unsupported")
                }

                "search" -> {
                    val keyword = call.argument<String>("keyword")?.trim().orEmpty()
                    if (keyword.isEmpty() || !amapReady) {
                        result.success(emptyList<Map<String, Any>>())
                    } else {
                        searchPois(keyword, result)
                    }
                }

                "districts" -> {
                    val keyword = call.argument<String>("keyword")?.trim().orEmpty()
                    val level = call.argument<String>("level")
                    if (keyword.isEmpty() || !amapReady) {
                        result.success(emptyList<Map<String, Any>>())
                    } else {
                        searchDistricts(keyword, level, result)
                    }
                }

                "districtCenter" -> {
                    val keyword = call.argument<String>("keyword")?.trim().orEmpty()
                    val level = call.argument<String>("level")
                    if (keyword.isEmpty() || !amapReady) {
                        result.success(null)
                    } else {
                        searchDistrictCenter(keyword, level, result)
                    }
                }

                "inputTips" -> {
                    val keyword = call.argument<String>("keyword")?.trim().orEmpty()
                    val city = call.argument<String>("city")?.trim().orEmpty()
                    if (keyword.isEmpty() || !amapReady) {
                        result.success(emptyList<Map<String, Any>>())
                    } else {
                        inputTips(keyword, city, result::success)
                    }
                }

                "currentAddress" -> requestCurrentAddress(result)

                "contacts" -> {
                    val raw = call.argument<List<Map<String, Any?>>>("pins").orEmpty()
                    val pins = raw.mapNotNull { item ->
                        val lat = (item["lat"] as? Number)?.toDouble()
                            ?: return@mapNotNull null
                        val lng = (item["lng"] as? Number)?.toDouble()
                            ?: return@mapNotNull null
                        ContactPin(
                            id = item["id"] as? String ?: "",
                            name = item["name"] as? String ?: "",
                            latitude = lat,
                            longitude = lng,
                            avatar = item["avatar"] as? ByteArray,
                            ringColor = (item["ring"] as? Number)?.toInt() ?: 0,
                        )
                    }
                    AmapViewBridge.lastPins = pins
                    AmapViewBridge.current?.setPins(pins)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == AmapPlatformView.REQ_LOCATION) {
            val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            AmapViewBridge.current?.onPermissionResult(granted)
        }
    }

    /**
     * 地点搜索：先按当前位置 50 公里内检索并按距离排序，再合并全国结果，
     * 都为空时依次用输入提示、地理编码兜底。
     *
     * 结果按 [{title, snippet, lat, lng, distance}] 返回，`distance` 为米（未知时缺省）。
     */
    private fun searchPois(keyword: String, result: MethodChannel.Result) {
        val replied = AtomicBoolean(false)
        fun finish(items: List<Map<String, Any>>) {
            if (replied.compareAndSet(false, true)) {
                runOnUiThread { result.success(items) }
            }
        }
        val origin = currentPoint()

        poiSearch(keyword, origin) { nearby ->
            poiSearch(keyword, null) { global ->
                val merged = sortByDistance(dedupe(nearby + global), origin)
                Log.d(
                    AmapPlatformView.TAG,
                    "search keyword=$keyword origin=$origin " +
                        "nearby=${nearby.size} global=${global.size} merged=${merged.size}",
                )
                if (merged.isNotEmpty()) {
                    finish(merged)
                } else {
                    inputTips(keyword, "") { tips ->
                        if (tips.isNotEmpty()) {
                            finish(sortByDistance(tips, origin))
                        } else {
                            geocode(keyword) { geocoded ->
                                finish(sortByDistance(geocoded, origin))
                            }
                        }
                    }
                }
            }
        }
    }

    /** 全国范围 POI 关键字搜索；[bound] 非空时限定半径并按距离排序。 */
    private fun poiSearch(
        keyword: String,
        bound: LatLonPoint?,
        callback: (List<Map<String, Any>>) -> Unit,
    ) {
        var replied = false
        try {
            val query = PoiSearch.Query(keyword, "", "")
            query.setPageSize(if (bound == null) 15 else 25)
            query.setPageNum(1)
            query.setCityLimit(false)
            val search = PoiSearch(applicationContext, query)
            if (bound != null) {
                search.setBound(PoiSearch.SearchBound(bound, NEARBY_SEARCH_RADIUS_METERS, true))
            }
            search.setOnPoiSearchListener(
                object : PoiSearch.OnPoiSearchListener {
                    override fun onPoiSearched(poiResult: PoiResult?, code: Int) {
                        if (replied) {
                            return
                        }
                        replied = true
                        val items = if (code == AMapException.CODE_AMAP_SUCCESS) {
                            poiResult?.pois?.mapNotNull { poi ->
                                val point: LatLonPoint = poi.latLonPoint ?: return@mapNotNull null
                                poisResultToMap(
                                    title = poi.title ?: "",
                                    snippet = poi.snippet ?: "",
                                    point = point,
                                )
                            } ?: emptyList()
                        } else {
                            Log.w(AmapPlatformView.TAG, "poi search failed code=$code bound=$bound")
                            emptyList()
                        }
                        runOnUiThread { callback(items) }
                    }

                    override fun onPoiItemSearched(
                        poiItem: com.amap.api.services.core.PoiItem?,
                        code: Int,
                    ) {
                        // 关键字搜索不走单点回调，忽略。
                    }
                },
            )
            search.searchPOIAsyn()
        } catch (error: Exception) {
            Log.w(AmapPlatformView.TAG, "poi search error", error)
            if (!replied) {
                replied = true
                callback(emptyList())
            }
        }
    }

    /** 输入提示：适合“山东省淄博市临淄区万丽花园”这类混合长文本。 */
    private fun inputTips(
        keyword: String,
        city: String,
        callback: (List<Map<String, Any>>) -> Unit,
    ) {
        try {
            val origin = currentPoint()
            val query = InputtipsQuery(keyword, city)
            query.setCityLimit(city.isNotEmpty())
            if (origin != null) {
                query.setLocation(origin)
            }
            val tips = Inputtips(applicationContext, query)
            tips.setInputtipsListener { list, code ->
                val items = if (code == AMapException.CODE_AMAP_SUCCESS) {
                    list?.mapNotNull { tip ->
                        val point: LatLonPoint = tip?.point ?: return@mapNotNull null
                        val snippet = tip.address ?: tip.district ?: ""
                        poisResultToMap(
                            title = tip.name ?: "",
                            snippet = snippet,
                            point = point,
                        )
                    } ?: emptyList()
                } else {
                    Log.w(AmapPlatformView.TAG, "input tips failed code=$code")
                    emptyList()
                }
                runOnUiThread { callback(items) }
            }
            tips.requestInputtipsAsyn()
        } catch (error: Exception) {
            Log.w(AmapPlatformView.TAG, "input tips error", error)
            callback(emptyList())
        }
    }

    /** 地理编码兜底：整串地址解析出经纬度。 */
    private fun geocode(
        keyword: String,
        callback: (List<Map<String, Any>>) -> Unit,
    ) {
        try {
            val search = GeocodeSearch(applicationContext)
            search.setOnGeocodeSearchListener(
                object : GeocodeSearch.OnGeocodeSearchListener {
                    override fun onRegeocodeSearched(
                        regeocodeResult: RegeocodeResult?,
                        code: Int,
                    ) {
                        // 只做正向地理编码，逆编码回调忽略。
                    }

                    override fun onGeocodeSearched(geocodeResult: GeocodeResult?, code: Int) {
                        val items = if (code == AMapException.CODE_AMAP_SUCCESS) {
                            geocodeResult?.geocodeAddressList?.mapNotNull { address ->
                                val point: LatLonPoint =
                                    address.latLonPoint ?: return@mapNotNull null
                                poisResultToMap(
                                    title = address.formatAddress ?: keyword,
                                    snippet = listOfNotNull(
                                        address.city,
                                        address.district,
                                    ).joinToString(""),
                                    point = point,
                                )
                            } ?: emptyList()
                        } else {
                            Log.w(AmapPlatformView.TAG, "geocode failed code=$code")
                            emptyList()
                        }
                        runOnUiThread { callback(items) }
                    }
                },
            )
            search.getFromLocationNameAsyn(GeocodeQuery(keyword, ""))
        } catch (error: Exception) {
            Log.w(AmapPlatformView.TAG, "geocode error", error)
            callback(emptyList())
        }
    }

    /**
     * 行政区划候选：`keyword` 为“中国”时返回省，为省名时返回市，为市名时返回区县。
     *
     * 结果按 [{name, adcode, level, lat, lng}] 返回。
     */
    private fun searchDistricts(
        keyword: String,
        level: String?,
        result: MethodChannel.Result,
    ) {
        try {
            val query = DistrictSearchQuery(keyword, level ?: "", 1)
            query.setShowBoundary(false)
            query.setSubDistrict(1)
            query.setPageSize(40)
            val search = DistrictSearch(applicationContext)
            search.setQuery(query)
            search.setOnDistrictSearchListener { districtResult ->
                val matched: List<DistrictItem> = districtResult?.district ?: emptyList()
                val children = matched.flatMap { it.subDistrict ?: emptyList() }
                val source = if (children.isNotEmpty()) children else matched
                val items = source.map { item ->
                    mapOf(
                        "name" to (item.name ?: ""),
                        "adcode" to (item.adcode ?: ""),
                        "level" to (item.level ?: ""),
                        "lat" to (item.center?.latitude ?: 0.0),
                        "lng" to (item.center?.longitude ?: 0.0),
                    )
                }
                runOnUiThread { result.success(items) }
            }
            search.searchDistrictAsyn()
        } catch (error: Exception) {
            Log.w(AmapPlatformView.TAG, "district search error", error)
            result.success(emptyList<Map<String, Any>>())
        }
    }

    /**
     * 行政区自身中心点：只精确到省/市/区的联系人用它打点。
     *
     * 与 [searchDistricts] 的区别是不下钻子区域，返回匹配到的行政区本身；
     * 查不到时返回 null，由 Dart 端决定是否显示「无坐标」。
     */
    private fun searchDistrictCenter(
        keyword: String,
        level: String?,
        result: MethodChannel.Result,
    ) {
        val replied = AtomicBoolean(false)
        fun finish(payload: Map<String, Any>?) {
            if (replied.compareAndSet(false, true)) {
                runOnUiThread { result.success(payload) }
            }
        }
        try {
            val query = DistrictSearchQuery(keyword, level ?: "", 1)
            query.setShowBoundary(false)
            query.setSubDistrict(0)
            query.setPageSize(5)
            val search = DistrictSearch(applicationContext)
            search.setQuery(query)
            search.setOnDistrictSearchListener { districtResult ->
                val center = districtResult?.district?.firstOrNull()?.center
                if (center == null) {
                    finish(null)
                } else {
                    finish(
                        mapOf<String, Any>(
                            "lat" to center.latitude,
                            "lng" to center.longitude,
                        ),
                    )
                }
            }
            search.searchDistrictAsyn()
        } catch (error: Exception) {
            Log.w(AmapPlatformView.TAG, "district center error", error)
            finish(null)
        }
    }

    /**
     * 取一次当前定位的省/市/区，供「所在城市变了」提醒使用。
     *
     * 地图里已经拿到过定位时直接用缓存，否则临时建一个一次性定位客户端，
     * 8 秒拿不到结果就返回 null（Dart 端当作未知处理，不会误报）。
     */
    private fun requestCurrentAddress(result: MethodChannel.Result) {
        val cached = AmapViewBridge.current?.currentLocation()
        if (cached != null && !cached.province.isNullOrEmpty()) {
            result.success(
                mapOf(
                    "province" to cached.province,
                    "city" to cached.city,
                    "district" to cached.district,
                ),
            )
            return
        }
        val replied = AtomicBoolean(false)
        var client: AMapLocationClient? = null
        fun finish(payload: Map<String, Any?>?) {
            if (!replied.compareAndSet(false, true)) {
                return
            }
            runCatching { client?.stopLocation() }
            runCatching { client?.onDestroy() }
            runOnUiThread { result.success(payload) }
        }

        runCatching {
            val created = AMapLocationClient(applicationContext)
            client = created
            val option = AMapLocationClientOption()
                .setLocationMode(AMapLocationClientOption.AMapLocationMode.Hight_Accuracy)
                .setOnceLocation(true)
                .setOnceLocationLatest(true)
                .setNeedAddress(true)
            created.setLocationOption(option)
            created.setLocationListener { location: AMapLocation? ->
                if (location == null || location.errorCode != 0) {
                    finish(null)
                } else {
                    finish(
                        mapOf(
                            "province" to location.province,
                            "city" to location.city,
                            "district" to location.district,
                        ),
                    )
                }
            }
            created.startLocation()
            Handler(Looper.getMainLooper()).postDelayed({ finish(null) }, 8000L)
        }.onFailure { finish(null) }
    }

    private fun currentPoint(): LatLonPoint? {
        val point = AmapViewBridge.current?.currentLatLng() ?: return null
        return LatLonPoint(point.latitude, point.longitude)
    }

    /** 地图可用且已创建时，才执行任何需要高德 so 的检索。 */
    private val amapReady: Boolean
        get() = AmapViewBridge.supported && AmapViewBridge.current != null

    private fun poisResultToMap(
        title: String,
        snippet: String,
        point: LatLonPoint,
    ): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "title" to title,
            "snippet" to snippet,
            "lat" to point.latitude,
            "lng" to point.longitude,
        )
        distanceMeters(point)?.let { map["distance"] = it }
        return map
    }

    private fun distanceMeters(point: LatLonPoint): Int? {
        val origin = currentPoint() ?: return null
        val out = FloatArray(1)
        Location.distanceBetween(
            origin.latitude,
            origin.longitude,
            point.latitude,
            point.longitude,
            out,
        )
        return out[0].toInt()
    }

    /** 保留先出现的结果（近处优先），再整体按距离升序。 */
    private fun dedupe(items: List<Map<String, Any>>): List<Map<String, Any>> {
        val seen = HashSet<String>()
        return items.filter { item ->
            val key = "${item["title"]}|${(item["lat"] as Double).round()}|${(item["lng"] as Double).round()}"
            seen.add(key)
        }
    }

    private fun sortByDistance(
        items: List<Map<String, Any>>,
        origin: LatLonPoint?,
    ): List<Map<String, Any>> {
        if (origin == null) {
            return items
        }
        // 已知距离的排前面并升序；没有距离信息的保持原顺序。
        return items.sortedBy { item ->
            (item["distance"] as? Int) ?: Int.MAX_VALUE
        }
    }

    private fun Double.round(): Long = Math.round(this * 100000.0)

    private companion object {
        const val AMAP_CHANNEL = "io.stardito.nullmap/amap"

        /** 附近检索半径：50 公里。 */
        const val NEARBY_SEARCH_RADIUS_METERS = 50000
    }
}
