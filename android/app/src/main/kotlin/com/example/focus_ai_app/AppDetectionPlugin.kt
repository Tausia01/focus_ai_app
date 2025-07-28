package com.example.focus_ai_app

import android.app.ActivityManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.provider.Settings
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

class AppDetectionPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var isMonitoring = false
    private var blockedApps = mutableListOf<String>()
    private var monitoringJob: Job? = null
    private val lastDetectionTimes = mutableMapOf<String, Long>()
    private val debounceMillis = 2000L // 2 seconds
    private var overlayClosedReceiver: BroadcastReceiver? = null
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app_detection_channel")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        // Register receiver for overlay close
        overlayClosedReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.example.focus_ai_app.OVERLAY_CLOSED") {
                    channel.invokeMethod("onOverlayClosed", null)
                }
            }
        }
        val filter = IntentFilter("com.example.focus_ai_app.OVERLAY_CLOSED")
        context.registerReceiver(overlayClosedReceiver, filter)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (overlayClosedReceiver != null) {
            context.unregisterReceiver(overlayClosedReceiver)
            overlayClosedReceiver = null
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestUsageStatsPermission" -> {
                requestUsageStatsPermission(result)
            }
            "hasUsageStatsPermission" -> {
                result.success(hasUsageStatsPermission())
            }
            "startAppMonitoring" -> {
                val apps = call.argument<List<String>>("blockedApps") ?: emptyList()
                startAppMonitoring(apps, result)
            }
            "stopAppMonitoring" -> {
                stopAppMonitoring(result)
            }
            "getInstalledApps" -> {
                getInstalledApps(result)
            }
            "requestOverlayPermission" -> {
                requestOverlayPermission(result)
            }
            "hasOverlayPermission" -> {
                result.success(hasOverlayPermission())
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun requestUsageStatsPermission(result: Result) {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
        result.success(null)
    }
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        val mode = appOps.checkOpNoThrow(
            android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        println("hasUsageStatsPermission: mode=$mode, packageName=${context.packageName}")
        return mode == android.app.AppOpsManager.MODE_ALLOWED
    }

    private fun requestOverlayPermission(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            intent.data = android.net.Uri.parse("package:" + context.packageName)
            context.startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("OVERLAY_PERMISSION_ERROR", e.message, null)
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
    
    private fun startAppMonitoring(apps: List<String>, result: Result) {
        if (!hasUsageStatsPermission()) {
            result.error("PERMISSION_DENIED", "Usage stats permission not granted", null)
            return
        }
        
        blockedApps.clear()
        blockedApps.addAll(apps)
        isMonitoring = true
        
        monitoringJob = CoroutineScope(Dispatchers.IO).launch {
            monitorAppUsage()
        }
        
        result.success(null)
    }
    
    private fun stopAppMonitoring(result: Result) {
        isMonitoring = false
        monitoringJob?.cancel()
        result.success(null)
    }
    
    private suspend fun monitorAppUsage() {
        println("monitorAppUsage started") // Debug: plugin started
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        var lastEventTime = System.currentTimeMillis()
        
        while (isMonitoring) {
            try {
                val endTime = System.currentTimeMillis()
                val usageEvents = usageStatsManager.queryEvents(lastEventTime, endTime)
                
                val event = UsageEvents.Event()
                while (usageEvents.hasNextEvent()) {
                    usageEvents.getNextEvent(event)
                    
                    if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                        val packageName = event.packageName
                        println("Foreground app: $packageName") // Debug: every foreground app
                        if (blockedApps.contains(packageName)) {
                            val now = System.currentTimeMillis()
                            val lastTime = lastDetectionTimes[packageName] ?: 0L
                            if (now - lastTime > debounceMillis) {
                                lastDetectionTimes[packageName] = now
                                println("Blocked app detected: $packageName") // Debug: match found
                                withContext(Dispatchers.Main) {
                                    channel.invokeMethod("onAppDetected", packageName)
                                    // Start overlay service
                                    val overlayIntent = Intent(context, OverlayService::class.java)
                                    overlayIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    context.startService(overlayIntent)
                                }
                            } else {
                                println("Duplicate detection for $packageName suppressed")
                            }
                        }
                    }
                }
                
                lastEventTime = endTime
                delay(1000) // Check every second
                
            } catch (e: Exception) {
                println("Error monitoring app usage: ${e.message}") // Debug: error
                delay(5000) // Wait longer on error
            }
        }
    }
    
    private fun getInstalledApps(result: Result) {
        val packageManager = context.packageManager
        val installedApps = packageManager.getInstalledApplications(0)
            .filter { app ->
                packageManager.getLaunchIntentForPackage(app.packageName) != null
            }
            .map { app -> app.packageName }
        
        result.success(installedApps)
    }
}
