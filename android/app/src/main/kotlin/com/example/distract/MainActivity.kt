package com.example.distract

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.distract/channel"
    private var methodChannel: MethodChannel? = null

    private val countUpdateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val count = intent.getIntExtra("count", 0)
            methodChannel?.invokeMethod("onScrollUpdated", count)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // 1. Check Permissions
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this))
                }
                "isOverlayEnabled" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                
                // 2. Open Settings Screens
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(true)
                }
                
                // 3. Data Fetching
                "getInitialCount" -> {
                    val prefs = getSharedPreferences("ReelPrefs", Context.MODE_PRIVATE)
                    result.success(prefs.getInt("daily_count", 0))
                }
                else -> result.notImplemented()
            }
        }

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