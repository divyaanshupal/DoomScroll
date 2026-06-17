package com.example.distract

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Process
import android.provider.Settings
import java.util.Calendar

class AppUsageManager(private val context: Context) {

    // 1. Check if the user has granted the special Usage Access permission
    fun hasUsagePermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // 2. Open the specific settings page for Usage Access
    fun openUsageSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    // 3. Fetch, calculate, and format today's screen time for all apps
    fun getDailyUsage(): List<Map<String, Any>> {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // Calculate the exact timestamp for 12:00 AM today
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        // Ask Android for the stats
        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        val pm = context.packageManager
        val usageMap = mutableMapOf<String, Int>()

        if (stats != null) {
            for (usage in stats) {
                // Only care about apps used for more than 1 minute (60,000 ms)
                if (usage.totalTimeInForeground > 60000) {
                    try {
                        val appInfo = pm.getApplicationInfo(usage.packageName, 0)
                        // Ignore hidden background system apps (only show apps the user actually opens)
                        if ((appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) == 0 || usage.packageName.contains("youtube") || usage.packageName.contains("instagram")) {
                            val appName = pm.getApplicationLabel(appInfo).toString()
                            val minutes = (usage.totalTimeInForeground / 1000 / 60).toInt()
                            
                            // Android sometimes returns multiple chunks for the same app, so we sum them up
                            usageMap[appName] = usageMap.getOrDefault(appName, 0) + minutes
                        }
                    } catch (e: PackageManager.NameNotFoundException) {
                        // App was uninstalled, ignore it
                    }
                }
            }
        }

        // Convert our map into a clean List sorted by most used app first
        return usageMap.map { mapOf("appName" to it.key, "minutes" to it.value) }
            .sortedByDescending { it["minutes"] as Int }
    }
}