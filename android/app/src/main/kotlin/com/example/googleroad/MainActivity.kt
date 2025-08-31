package com.example.googleroad

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.Manifest
import android.graphics.Color
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// The main activity that initializes the plugin
class MainActivity: FlutterActivity() {
    private val CHANNEL_ID = "route_progress_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register our plugin directly with the Flutter engine
        flutterEngine.plugins.add(NotificationPlugin(this))
        
        // Request notification permission and create channel
        createNotificationChannel()
        requestNotificationPermission()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != 
                PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Route Progress"
            val descriptionText = "Shows progress along your current route"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableLights(true)
                lightColor = Color.BLUE
            }
            
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}

// Create a standalone plugin that implements FlutterPlugin
class NotificationPlugin(private val context: Context) : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val NOTIFICATION_ID = 100
    private val CHANNEL_ID = "route_progress_channel"
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d("NotificationPlugin", "Plugin attached to engine")
        channel = MethodChannel(binding.binaryMessenger, "com.example.googleroad/notifications")
        channel.setMethodCallHandler(this)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d("NotificationPlugin", "Plugin detached from engine")
        channel.setMethodCallHandler(null)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            Log.d("NotificationPlugin", "Method called: ${call.method}")
            
            when (call.method) {
                "initializeNotifications" -> {
                    result.success(true)
                }
                "showRouteProgressNotification" -> {
                    val stationName = call.argument<String>("stationName") ?: "Unknown"
                    val progress = call.argument<Int>("progress") ?: 0
                    val aqi = call.argument<Int>("aqi") ?: 0
                    val aqiLevel = call.argument<String>("aqiLevel") ?: "Unknown"
                    
                    // Get the new zone message parameter
                    val zoneMessage = call.argument<String>("zoneMessage")
                    
                    showNotification(stationName, progress, aqi, aqiLevel, zoneMessage)
                    result.success(true)
                }
                "hideRouteProgressNotification" -> {
                    hideNotification()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e("NotificationPlugin", "Error handling method call: ${e.message}", e)
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun showNotification(
        stationName: String, 
        progress: Int, 
        aqi: Int, 
        aqiLevel: String, 
        zoneMessage: String?
    ) {
        try {
            // Prepare notification text with zone message if available
            val bigText = if (zoneMessage != null) {
                "You are near $stationName ($progress%)\nAQI: $aqi - $aqiLevel\n$zoneMessage"
            } else {
                "You are near $stationName ($progress%)\nAQI: $aqi - $aqiLevel"
            }
            
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Route Progress")
                .setContentText("Near $stationName ($progress%)")
                .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true)
                .setOnlyAlertOnce(true)

            with(NotificationManagerCompat.from(context)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    if (ContextCompat.checkSelfPermission(context, 
                        Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                        notify(NOTIFICATION_ID, builder.build())
                        Log.d("NotificationPlugin", "Notification sent successfully")
                    } else {
                        Log.e("NotificationPlugin", "POST_NOTIFICATIONS permission denied")
                    }
                } else {
                    notify(NOTIFICATION_ID, builder.build())
                    Log.d("NotificationPlugin", "Notification sent (pre-Tiramisu)")
                }
            }
        } catch (e: Exception) {
            Log.e("NotificationPlugin", "Error sending notification: ${e.message}", e)
        }
    }
    
    private fun hideNotification() {
        try {
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            Log.e("NotificationPlugin", "Error cancelling notification: ${e.message}", e)
        }
    }
}
