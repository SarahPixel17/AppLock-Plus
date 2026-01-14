package com.example.applockplus.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * 📡 LocationNotificationReceiver
 *
 * Handles system broadcasts to ensure the LocationNotificationService
 * runs whenever device time, timezone, or GPS provider changes.
 */
class LocationNotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val action = intent.action ?: return
        Log.d("LocationReceiver", "📨 Received broadcast: $action")

        try {
            val serviceIntent = Intent(context, LocationNotificationService::class.java)

            when (action) {
                // 🔁 Device restarted
                Intent.ACTION_BOOT_COMPLETED,
                // 🕒 Time changed manually
                Intent.ACTION_TIME_CHANGED,
                // 🌍 Timezone changed
                Intent.ACTION_TIMEZONE_CHANGED,
                // 📡 GPS provider toggled
                "android.location.PROVIDERS_CHANGED" -> {

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Log.d("LocationReceiver", "🚀 Starting foreground LocationNotificationService")
                        context.startForegroundService(serviceIntent)
                    } else {
                        Log.d("LocationReceiver", "🚀 Starting background LocationNotificationService")
                        context.startService(serviceIntent)
                    }
                }
            }

        } catch (e: Exception) {
            Log.e("LocationReceiver", "❌ Failed to start LocationNotificationService: ${e.message}", e)
        }
    }
}
