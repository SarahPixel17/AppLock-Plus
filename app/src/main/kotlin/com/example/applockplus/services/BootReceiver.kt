// android/app/src/main/kotlin/com/example/applockplus/services/BootReceiver.kt
package com.example.applockplus.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        val action = intent.action
        Log.d("BootReceiver", "Boot completed received: $action")
        
        // Start location service on boot
        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            try {
                val serviceIntent = Intent(context, LocationNotificationService::class.java)
                context.startService(serviceIntent)
                Log.d("BootReceiver", "Location service started on boot")
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to start location service on boot: ${e.message}")
            }
        }
    }
}