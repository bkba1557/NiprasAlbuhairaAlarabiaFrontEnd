package com.albuhaira.nipras

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.albuhaira.nipras/device_performance"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isLowRamDevice" -> {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    result.success(activityManager?.isLowRamDevice ?: false)
                }

                "memoryClassMb" -> {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    result.success(activityManager?.memoryClass)
                }

                else -> result.notImplemented()
            }
        }
    }
}
