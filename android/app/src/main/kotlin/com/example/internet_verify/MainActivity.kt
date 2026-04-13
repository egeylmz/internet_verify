package com.example.internet_verify

import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.internet_verify"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllUsageData" -> {
                    val allData = mutableMapOf<String, Double>()
                    val periods = listOf("1h", "1d", "1w", "1m")
                    for (period in periods) {
                        val mobileBytes = getTotalDataBytes(period, ConnectivityManager.TYPE_MOBILE)
                        allData["${period}_mobile"] = mobileBytes / (1024.0 * 1024.0)
                        val wifiBytes = getTotalDataBytes(period, ConnectivityManager.TYPE_WIFI)
                        allData["${period}_wifi"] = wifiBytes / (1024.0 * 1024.0)
                    }
                    result.success(allData)
                }
                "getAppUsageList" -> {
                    val period = call.argument<String>("period") ?: "1d"
                    result.success(getAppUsageList(period))
                }
                "getHistoricalDailyUsage" -> {
                    val days = call.argument<Int>("days") ?: 90
                    result.success(getHistoricalDailyUsage(days))
                }

                "checkPermission" -> {
                    result.success(checkUsageStatsPermission())
                }
                "openSettings" -> {
                    openUsageStatsSettings()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getStartTime(period: String): Long {
        val now = System.currentTimeMillis()
        return when (period) {
            "1h" -> now - 3600000L
            "1d" -> now - 86400000L
            "1w" -> now - 604800000L
            "1m" -> now - 2592000000L
            else -> now - 86400000L
        }
    }

    private fun getTotalDataBytes(period: String, networkType: Int): Long {
        return try {
            val networkStatsManager = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
            val usage = networkStatsManager.querySummaryForDevice(networkType, null, getStartTime(period), System.currentTimeMillis())
            usage.rxBytes + usage.txBytes
        } catch (e: Exception) { 0L }
    }

    private fun getHistoricalDailyUsage(days: Int): List<Map<String, Any>> {
        val networkStatsManager = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val now = System.currentTimeMillis()
        val dayMs = 86400000L

        // Kümülatif sorgular: bitiş HEP 'now' — dashboard ile aynı yöntem.
        // cumMobile[i] = "son i gün" toplam mobil bayt (i=0 → 0 bayt)
        val cumMobile = LongArray(days + 1)
        val cumWifi   = LongArray(days + 1)

        for (i in 1..days) {
            val startTime = now - i * dayMs
            cumMobile[i] = try {
                val u = networkStatsManager.querySummaryForDevice(
                    ConnectivityManager.TYPE_MOBILE, null, startTime, now)
                u.rxBytes + u.txBytes
            } catch (e: Exception) { cumMobile[i - 1] }

            cumWifi[i] = try {
                val u = networkStatsManager.querySummaryForDevice(
                    ConnectivityManager.TYPE_WIFI, null, startTime, now)
                u.rxBytes + u.txBytes
            } catch (e: Exception) { cumWifi[i - 1] }
        }

        // Gün i kullanımı = cumulative[i+1] - cumulative[i]  (her zaman >= 0)
        val result = mutableListOf<Map<String, Any>>()
        for (i in 0 until days) {
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, -i)
            val dateStr = sdf.format(cal.time)
            val mobileMB = (cumMobile[i + 1] - cumMobile[i]).coerceAtLeast(0L) / 1048576.0
            val wifiMB   = (cumWifi[i + 1]   - cumWifi[i]).coerceAtLeast(0L)   / 1048576.0
            result.add(mapOf("date" to dateStr, "mobileMB" to mobileMB, "wifiMB" to wifiMB))
        }
        return result
    }

    // DİNAMİK EŞLEŞTİRME YAPAN YENİ FONKSİYON
    private fun getAppUsageList(period: String): List<Map<String, Any>> {
        val usageList = mutableListOf<Map<String, Any>>()
        val networkStatsManager = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val pm = packageManager

        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val appMap = mutableMapOf<Int, Triple<String, String, ByteArray?>>()

        for (appInfo in installedApps) {
            val label = pm.getApplicationLabel(appInfo).toString()
            val packageName = appInfo.packageName

            // İKON ÇEKME İŞLEMİ (Burayı eklemezsen Triple hatası devam eder)
            var iconBytes: ByteArray? = null
            try {
                val icon = pm.getApplicationIcon(appInfo)
                val bitmap = if (icon is BitmapDrawable) {
                    icon.bitmap
                } else {
                    val b = Bitmap.createBitmap(icon.intrinsicWidth, icon.intrinsicHeight, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(b)
                    icon.setBounds(0, 0, canvas.width, canvas.height)
                    icon.draw(canvas)
                    b
                }
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
                iconBytes = stream.toByteArray()
            } catch (e: Exception) { }

            // Hata veren satırı şu şekilde düzeltiyoruz:
            appMap[appInfo.uid] = Triple(label, packageName, iconBytes)
        }


        try {
            val stats = networkStatsManager.querySummary(ConnectivityManager.TYPE_MOBILE, null, getStartTime(period), System.currentTimeMillis())
            val bucket = NetworkStats.Bucket()
            val uidUsageMap = mutableMapOf<Int, Long>()

            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                uidUsageMap[bucket.uid] = (uidUsageMap[bucket.uid] ?: 0L) + (bucket.rxBytes + bucket.txBytes)
            }
            stats.close()

            for ((uid, bytes) in uidUsageMap) {
                if (bytes > 102400) { // 100KB altını gösterme
                    // 2. UID'yi bizim dinamik haritamızdan bul
                    val appData = appMap[uid]

                    val finalAppName: String = appData?.first ?: when(uid) {
                        1000 -> "Android Sistemi"
                        1013 -> "Medya Servisleri"
                        else -> "Bilinmeyen ($uid)"
                    }

                    val finalPackageName: String = appData?.second ?: "system_uid_$uid"

                    if (appData != null) {
                        usageList.add(mapOf(
                            "appName" to appData.first,
                            "packageName" to appData.second,
                            "usageMB" to bytes / 1048576.0,
                            "iconBytes" to (appData.third ?: ByteArray(0)) // Flutter'a ikonları gönderen kritik satır
                        ))
                    }
                }
            }
        } catch (e: Exception) { }

        return usageList.sortedByDescending { it["usageMB"] as Double }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }
        return mode == android.app.AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageStatsSettings() {
        val intent = android.content.Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
        startActivity(intent)
    }
}