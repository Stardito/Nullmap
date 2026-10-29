package io.stardito.nullmap

import android.Manifest
import android.app.Activity
import android.app.KeyguardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.provider.MediaStore
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
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    /** 地图通道：原生标记点击时反向调用 Dart 显示底部面板。 */
    private var amapChannel: MethodChannel? = null

    /** 隐私通道：屏幕锁验证与备份文件读写。 */
    private var securityChannel: MethodChannel? = null

    /** 等待系统验证页返回的调用方；同一时间只允许一个。 */
    private var pendingAuth: MethodChannel.Result? = null

    /** 等待文件选择器返回的调用方。 */
    private var pendingImport: MethodChannel.Result? = null

    /** 等待通讯录权限结果的调用方。 */
    private var pendingContacts: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 隐私声明必须早于任何高德 SDK 调用（包括只查地址时创建定位客户端）。
        runCatching {
            MapsInitializer.updatePrivacyShow(applicationContext, true, true)
            MapsInitializer.updatePrivacyAgree(applicationContext, true)
        }
        // 首次启动（或升级后还没被问过）主动申请一次定位权限；之后不再自动弹窗，
        // 用户点定位按钮时才会再次申请。
        requestLocationPermissionIfNeeded()
    }

    private fun requestLocationPermissionIfNeeded() {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val prefs = getSharedPreferences(AmapPlatformView.PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(AmapPlatformView.KEY_PERMISSION_ASKED, false)) {
            return
        }
        prefs.edit().putBoolean(AmapPlatformView.KEY_PERMISSION_ASKED, true).apply()
        Log.d(AmapPlatformView.TAG, "request location permission at launch")
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            AmapPlatformView.REQ_LOCATION,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("io.stardito.nullmap/amap", AmapViewFactory())
        configureSecurityChannel(flutterEngine)
        configureDeviceChannel(flutterEngine)

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

                // 详细地址 → 省/市/区 + 坐标，用于「只输详细地址，自动补全行政区」。
                "geocodeDetail" -> {
                    val address = call.argument<String>("address")?.trim().orEmpty()
                    val city = call.argument<String>("city")?.trim().orEmpty()
                    if (address.isEmpty() || !amapReady) {
                        result.success(null)
                    } else {
                        geocodeDetail(address, city, result::success)
                    }
                }

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
            return
        }
        if (requestCode == REQ_CONTACTS) {
            val callback = pendingContacts
            pendingContacts = null
            val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            if (granted) {
                callback?.success(readDeviceContacts())
            } else {
                callback?.error("permission", "通讯录权限被拒绝", null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQ_AUTH -> {
                // 系统验证页返回：RESULT_OK 才算通过，取消/失败都按未通过处理。
                val callback = pendingAuth
                pendingAuth = null
                callback?.success(resultCode == Activity.RESULT_OK)
                return
            }

            REQ_IMPORT -> {
                val callback = pendingImport
                pendingImport = null
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    callback?.success(null)
                    return
                }
                val text = runCatching {
                    contentResolver.openInputStream(data.data!!)?.use { stream ->
                        stream.bufferedReader(Charsets.UTF_8).readText()
                    }
                }.getOrNull()
                callback?.success(text)
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** 隐私通道：屏幕锁验证 + 备份文件导入导出。 */
    private fun configureSecurityChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL,
        )
        securityChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSecure" -> result.success(keyguard()?.isDeviceSecure == true)

                "authenticate" -> authenticate(
                    call.argument<String>("reason").orEmpty(),
                    result,
                )

                "exportBackup" -> {
                    val filename = call.argument<String>("filename")
                        ?: "nullmap-backup.json"
                    val content = call.argument<String>("content").orEmpty()
                    result.success(exportBackup(filename, content))
                }

                "importBackup" -> pickBackupFile(result)

                else -> result.notImplemented()
            }
        }
    }

    private fun keyguard(): KeyguardManager? =
        getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager

    /** 手机通讯录读取通道：先运行时申请 READ_CONTACTS，再把结果回给 Flutter。 */
    private fun configureDeviceChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_CHANNEL,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "readContacts" -> {
                    if (checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(readDeviceContacts())
                    } else {
                        pendingContacts = result
                        requestPermissions(
                            arrayOf(Manifest.permission.READ_CONTACTS),
                            REQ_CONTACTS,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /** 读出手机联系人：按 contactId 聚合姓名与号码（最多 5 个号码）。 */
    private fun readDeviceContacts(): List<Map<String, Any?>> {
        val grouped = LinkedHashMap<Long, MutableMap<String, Any?>>()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        runCatching {
            contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " COLLATE LOCALIZED ASC",
            )?.use { cursor ->
                val idIndex =
                    cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
                val nameIndex =
                    cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numberIndex =
                    cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idIndex)
                    val name = cursor.getString(nameIndex)?.trim().orEmpty()
                    val number = cursor.getString(numberIndex)?.trim().orEmpty()
                    if (number.isEmpty()) {
                        continue
                    }
                    val entry = grouped.getOrPut(id) {
                        mutableMapOf<String, Any?>(
                            "id" to id.toString(),
                            "name" to name,
                            "phones" to mutableListOf<String>(),
                        )
                    }
                    @Suppress("UNCHECKED_CAST")
                    val phones = entry["phones"] as MutableList<String>
                    if (!phones.contains(number) && phones.size < 5) {
                        phones.add(number)
                    }
                }
            }
        }.onFailure { error ->
            Log.w(AmapPlatformView.TAG, "read contacts failed", error)
        }
        return grouped.values
            .map { entry ->
                mapOf(
                    "id" to entry["id"],
                    "name" to entry["name"],
                    "phones" to entry["phones"],
                )
            }
            .filter { entry -> (entry["phones"] as? List<*>)?.isNotEmpty() == true }
            .sortedBy { entry -> "${entry["name"]}".lowercase() }
    }

    /**
     * 拉起系统「确认锁屏密码」页面完成验证。
     *
     * 用 [KeyguardManager.createConfirmDeviceCredentialIntent] 而不是自绘密码框：
     * 不接触任何凭据，也没有额外权限，用户已设置的 PIN / 图案 / 指纹都能用。
     */
    private fun authenticate(reason: String, result: MethodChannel.Result) {
        val manager = keyguard()
        if (manager == null || !manager.isDeviceSecure) {
            result.success(false)
            return
        }
        val intent = runCatching {
            manager.createConfirmDeviceCredentialIntent(
                "零点地图",
                reason.ifBlank { "验证以查看敏感信息" },
            )
        }.getOrNull()
        if (intent == null) {
            result.success(false)
            return
        }
        // 覆盖前一个等待中的请求，避免回调永远不返回。
        pendingAuth?.success(false)
        pendingAuth = result
        runCatching { startActivityForResult(intent, REQ_AUTH) }.onFailure {
            pendingAuth = null
            result.success(false)
        }
    }

    /** 导出到系统下载目录；Android 10 以下退回应用外部目录。 */
    private fun exportBackup(filename: String, content: String): String? = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values,
            ) ?: return@runCatching null
            resolver.openOutputStream(uri)?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
            } ?: return@runCatching null
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            "Downloads/$filename"
        } else {
            val dir = File(getExternalFilesDir(null) ?: filesDir, "backup")
            dir.mkdirs()
            val file = File(dir, filename)
            file.writeText(content, Charsets.UTF_8)
            file.absolutePath
        }
    }.getOrNull()

    /** 选择备份文件：交给系统文件选择器，应用只拿到一次性读权限。 */
    private fun pickBackupFile(result: MethodChannel.Result) {
        pendingImport?.success(null)
        pendingImport = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/plain", "application/octet-stream"),
            )
        }
        runCatching { startActivityForResult(intent, REQ_IMPORT) }.onFailure {
            pendingImport = null
            result.success(null)
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

    /** 地址 → 省市区 + 坐标：用于「只输详细地址，自动补省市区」。 */
    private fun geocodeDetail(
        keyword: String,
        city: String,
        callback: (Map<String, Any?>?) -> Unit,
    ) {
        try {
            val search = GeocodeSearch(applicationContext)
            search.setOnGeocodeSearchListener(
                object : GeocodeSearch.OnGeocodeSearchListener {
                    override fun onRegeocodeSearched(
                        regeocodeResult: RegeocodeResult?,
                        code: Int,
                    ) {
                        // 只做正向地理编码。
                    }

                    override fun onGeocodeSearched(geocodeResult: GeocodeResult?, code: Int) {
                        val address = if (code == AMapException.CODE_AMAP_SUCCESS) {
                            geocodeResult?.geocodeAddressList?.firstOrNull()
                        } else {
                            Log.w(AmapPlatformView.TAG, "geocodeDetail failed code=$code")
                            null
                        }
                        val point: LatLonPoint? = address?.latLonPoint
                        val payload: Map<String, Any?>? = if (address == null) {
                            null
                        } else {
                            mapOf(
                                "province" to address.province.orEmpty(),
                                "city" to address.city.orEmpty(),
                                "district" to address.district.orEmpty(),
                                "address" to (address.formatAddress ?: keyword),
                                "latitude" to (point?.latitude ?: 0.0),
                                "longitude" to (point?.longitude ?: 0.0),
                            )
                        }
                        runOnUiThread { callback(payload) }
                    }
                },
            )
            search.getFromLocationNameAsyn(
                GeocodeQuery(keyword, if (city.isEmpty()) "" else city),
            )
        } catch (error: Exception) {
            Log.w(AmapPlatformView.TAG, "geocodeDetail error", error)
            callback(null)
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
        const val SECURITY_CHANNEL = "io.stardito.nullmap/security"

        /** 设备数据通道：读取手机通讯录。 */
        const val DEVICE_CHANNEL = "io.stardito.nullmap/device"

        /** 系统屏幕锁验证页。 */
        const val REQ_AUTH = 4401

        /** 系统文件选择器（导入备份）。 */
        const val REQ_IMPORT = 4402

        /** 通讯录读取权限。 */
        const val REQ_CONTACTS = 4501

        /** 附近检索半径：50 公里。 */
        const val NEARBY_SEARCH_RADIUS_METERS = 50000
    }
}
