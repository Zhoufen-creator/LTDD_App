package com.example.tran_nguyen_vi_khang_app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "vn.edu.parentalcontrol/monitoring"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageAccessPermission" -> {
                    result.success(hasUsageAccessPermission())
                }
                "openUsageAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "checkOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "openOverlaySettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("OVERLAY_ERROR", e.localizedMessage, null)
                    }
                }
                "queryUsageEvents" -> {
                    try {
                        val startTime = call.argument<Long>("startTime") ?: (System.currentTimeMillis() - 60000)
                        val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                        val events = queryUsageEvents(startTime, endTime)
                        result.success(events)
                    } catch (e: Exception) {
                        result.error("QUERY_ERROR", e.localizedMessage, null)
                    }
                }
                "getInstalledApps" -> {
                    try {
                        val apps = getInstalledLaunchableApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("APPS_ERROR", e.localizedMessage, null)
                    }
                }
                "goToHomeScreen" -> {
                    try {
                        val homeIntent = Intent(Intent.ACTION_MAIN)
                        homeIntent.addCategory(Intent.CATEGORY_HOME)
                        homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(homeIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOME_ERROR", e.localizedMessage, null)
                    }
                }
                "bringAppToFront" -> {
                    try {
                        val bringIntent = Intent(this, MainActivity::class.java)
                        bringIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        startActivity(bringIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BRING_FRONT_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageAccessPermission(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun queryUsageEvents(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val events = usageStatsManager.queryEvents(startTime, endTime)
        val eventList = mutableListOf<Map<String, Any>>()
        val event = UsageEvents.Event()
        val pm = packageManager

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val typeStr = when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED, 1 -> "ACTIVITY_RESUMED"
                UsageEvents.Event.ACTIVITY_PAUSED, 2 -> "ACTIVITY_PAUSED"
                15 -> "SCREEN_INTERACTIVE" // Screen on
                16 -> "SCREEN_NON_INTERACTIVE" // Screen off
                17 -> "KEYGUARD_SHOWN" // Locked
                18 -> "KEYGUARD_HIDDEN" // Unlocked
                else -> null
            }

            if (typeStr != null) {
                val pkg = event.packageName ?: ""
                var appLabel = pkg
                if (pkg.isNotEmpty()) {
                    try {
                        val appInfo = pm.getApplicationInfo(pkg, 0)
                        appLabel = pm.getApplicationLabel(appInfo).toString()
                    } catch (_: Exception) {
                    }
                }

                eventList.add(
                    mapOf(
                        "packageName" to pkg,
                        "className" to (event.className ?: ""),
                        "eventType" to typeStr,
                        "timestamp" to event.timeStamp,
                        "appName" to appLabel
                    )
                )
            }
        }

        return eventList
    }

    private fun getInstalledLaunchableApps(): List<Map<String, String>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val appList = mutableListOf<Map<String, String>>()

        for (ri in resolveInfos) {
            val pkg = ri.activityInfo.packageName
            if (pkg != packageName) {
                val label = ri.loadLabel(pm).toString()
                appList.add(
                    mapOf(
                        "packageName" to pkg,
                        "appName" to label
                    )
                )
            }
        }

        return appList.sortedBy { it["appName"]?.lowercase() ?: "" }
    }
}
