package com.almurakib.egyptappstocks

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val facebookChannel = "com.almurakib.egyptappstocks/facebook_sdk"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, facebookChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "configure") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val appId = call.argument<String>("app_id")?.trim().orEmpty()
                val clientToken = call.argument<String>("client_token")?.trim().orEmpty()
                val autoLogAppEvents = call.argument<Boolean>("auto_log_app_events") ?: true

                if (!appId.matches(Regex("^[0-9]{5,32}$")) || clientToken.isBlank()) {
                    result.error("invalid_facebook_config", "Facebook App ID or Client Token is invalid.", null)
                    return@setMethodCallHandler
                }

                try {
                    val currentAppId = try { FacebookSdk.getApplicationId() } catch (_: Exception) { null }
                    val isAlreadyInitialized = FacebookSdk.isInitialized()

                    if (isAlreadyInitialized && currentAppId == appId) {
                        if (autoLogAppEvents) {
                            try {
                                AppEventsLogger.activateApp(application, appId)
                            } catch (e: Exception) {
                                Log.w("FacebookSdk", "activateApp warning: ${e.message}")
                            }
                        }
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    try {
                        FacebookSdk.setApplicationId(appId)
                    } catch (e: Exception) {
                        Log.w("FacebookSdk", "setApplicationId notice: ${e.message}")
                    }

                    try {
                        FacebookSdk.setClientToken(clientToken)
                    } catch (e: Exception) {
                        Log.w("FacebookSdk", "setClientToken notice: ${e.message}")
                    }

                    // Modern Facebook SDK initialization: must initialize before configuring auto-init
                    try {
                        FacebookSdk.sdkInitialize(applicationContext)
                        FacebookSdk.fullyInitialize()
                    } catch (e: Exception) {
                        Log.w("FacebookSdk", "initialize notice: ${e.message}")
                    }

                    try {
                        FacebookSdk.setAutoInitEnabled(true)
                        FacebookSdk.setAutoLogAppEventsEnabled(autoLogAppEvents)
                    } catch (e: Exception) {
                        Log.w("FacebookSdk", "setAutoInitEnabled notice: ${e.message}")
                    }

                    if (autoLogAppEvents) {
                        try {
                            AppEventsLogger.activateApp(application, appId)
                        } catch (e: Exception) {
                            Log.w("FacebookSdk", "activateApp notice: ${e.message}")
                        }
                    }

                    mainHandler.post {
                        result.success(true)
                    }
                } catch (error: Exception) {
                    Log.e("FacebookSdk", "Facebook SDK configuration error: ${error.message}", error)
                    if (FacebookSdk.isInitialized()) {
                        mainHandler.post {
                            result.success(true)
                        }
                    } else {
                        mainHandler.post {
                            result.error("facebook_sdk_init_failed", error.message ?: "Initialization error", null)
                        }
                    }
                }
            }
    }

    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val channel = NotificationChannel(
            "default_channel",
            "General Notifications",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "General app notifications"
            enableVibration(true)
        }

        manager.createNotificationChannel(channel)
    }
}
