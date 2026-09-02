package com.almurakib.egyptappstocks

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val facebookChannel = "com.almurakib.egyptappstocks/facebook_sdk"

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

                if (FacebookSdk.isInitialized()) {
                    result.success(FacebookSdk.getApplicationId() == appId)
                    return@setMethodCallHandler
                }

                try {
                    FacebookSdk.setApplicationId(appId)
                    FacebookSdk.setClientToken(clientToken)
                    FacebookSdk.setAutoInitEnabled(true)
                    FacebookSdk.setAutoLogAppEventsEnabled(autoLogAppEvents)
                    @Suppress("DEPRECATION")
                    FacebookSdk.sdkInitialize(
                        applicationContext,
                        FacebookSdk.InitializeCallback {
                            if (autoLogAppEvents) {
                                AppEventsLogger.activateApp(application, appId)
                            }
                            result.success(true)
                        },
                    )
                } catch (error: Exception) {
                    result.error("facebook_sdk_init_failed", error.message, null)
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