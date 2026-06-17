package com.example.distract

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.distract/channel"
    private val USAGE_CHANNEL = "com.example.distract/usage" // The new Stats channel
    private var methodChannel: MethodChannel? = null

    // Listens for the background service telling us the count changed
    private val countUpdateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val insta = intent.getIntExtra("insta", 0)
            val yt = intent.getIntExtra("yt", 0)
            val data = mapOf("insta" to insta, "yt" to yt)
            methodChannel?.invokeMethod("onScrollUpdated", data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ==========================================
        // 1. THE REELS TRACKER BRIDGE
        // ==========================================
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled(this))
                "isOverlayEnabled" -> result.success(Settings.canDrawOverlays(this))
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:$packageName"))
                    startActivity(intent)
                    result.success(true)
                }
                "getInitialCount" -> {
                    val prefs = getSharedPreferences("ReelPrefs", Context.MODE_PRIVATE)
                    val data = mapOf("insta" to prefs.getInt("insta_count", 0), "yt" to prefs.getInt("youtube_count", 0))
                    result.success(data)
                }
                else -> result.notImplemented()
            }
        }

        // ==========================================
        // 2. THE APP USAGE STATS BRIDGE
        // ==========================================
        val usageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
        val appUsageManager = AppUsageManager(this)

        usageChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsagePermission" -> result.success(appUsageManager.hasUsagePermission())
                "openUsageSettings" -> {
                    appUsageManager.openUsageSettings()
                    result.success(true)
                }
                "getDailyUsage" -> {
                    // Fetch data on background thread to prevent UI freezing
                    Thread {
                        val usageData = appUsageManager.getDailyUsage()
                        runOnUiThread { result.success(usageData) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // Register the broadcast receiver
        val filter = IntentFilter("com.example.distract.UPDATE_COUNT")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(countUpdateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(countUpdateReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(countUpdateReceiver)
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        var accessibilityEnabled = 0
        val service = context.packageName + "/" + ReelTrackingService::class.java.canonicalName
        try {
            accessibilityEnabled = Settings.Secure.getInt(
                context.applicationContext.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED
            )
        } catch (e: Settings.SettingNotFoundException) {
            // Ignore
        }
        if (accessibilityEnabled == 1) {
            val settingValue = Settings.Secure.getString(
                context.applicationContext.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            if (settingValue != null) {
                return settingValue.contains(service)
            }
        }
        return false
    }
}