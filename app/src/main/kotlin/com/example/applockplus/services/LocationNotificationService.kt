package com.example.applockplus.services

import android.app.*
import android.content.*
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.applockplus.R

/**
 * 📍 LocationNotificationService
 *
 * Runs as a foreground service that:
 * - Monitors GPS and time setting changes
 * - Shows persistent notification that AppLock+ monitoring is active
 * - Sends alerts when GPS or time changes
 */
class LocationNotificationService : Service() {

    private val CHANNEL_ID = "applockplus_location_channel"
    private val ALERT_CHANNEL_ID = "applockplus_alert_channel"
    private val NOTIFICATION_ID = 2025

    private var gpsReceiver: BroadcastReceiver? = null
    private var timeReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        Log.d("AppLock+", "📍 LocationNotificationService started")

        createNotificationChannels()
        registerReceivers()

        // 🛰️ Start persistent foreground notification
        val notification = buildForegroundNotification()
        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AppLock+", "LocationNotificationService running in background")
        return START_STICKY // Auto-restart if killed
    }

    /**
     * 🛰️ Persistent monitoring notification
     */
    private fun buildForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📍 AppLock+ Monitoring Active")
            .setContentText("Location and time-based app locks are being enforced.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    /**
     * 🔔 One-time alerts for GPS/time changes
     */
    private fun showAlertNotification(title: String, message: String) {
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 300, 250, 300))
            .setCategory(Notification.CATEGORY_ALARM)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(System.currentTimeMillis().toInt(), notification)
    }

    /**
     * 🛰️ Monitor GPS and time changes dynamically
     */
    private fun registerReceivers() {
        // 📡 GPS changes
        gpsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == LocationManager.PROVIDERS_CHANGED_ACTION) {
                    val lm = context?.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    val gpsEnabled = lm?.isProviderEnabled(LocationManager.GPS_PROVIDER) ?: false
                    val netEnabled = lm?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ?: false

                    if (!gpsEnabled && !netEnabled) {
                        showAlertNotification(
                            "⚠️ GPS Disabled",
                            "AppLock+ cannot enforce location locks. Please enable location services."
                        )
                    } else {
                        showAlertNotification(
                            "📡 GPS Enabled",
                            "Location services are active. AppLock+ monitoring resumed."
                        )
                    }
                }
            }
        }

        // ⏰ Time or timezone changes
        timeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_TIME_CHANGED,
                    Intent.ACTION_TIMEZONE_CHANGED -> {
                        showAlertNotification(
                            "⏰ Time Settings Changed",
                            "Device time or timezone modified. Time-based locks adjusted."
                        )
                    }
                }
            }
        }

        // Register dynamically
        registerReceiver(gpsReceiver, IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION))
        registerReceiver(timeReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        })
    }

    /**
     * 🧹 Cleanup
     */
    private fun unregisterReceivers() {
        try {
            gpsReceiver?.let { unregisterReceiver(it) }
            timeReceiver?.let { unregisterReceiver(it) }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * 📢 Notification channels
     */
    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mainChannel = NotificationChannel(
                CHANNEL_ID,
                "AppLock+ Location Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps AppLock+ running for GPS/time monitoring"
                setShowBadge(false)
            }

            val alertChannel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "AppLock+ Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts for GPS or time setting changes"
                enableVibration(true)
                enableLights(true)
            }

            manager?.createNotificationChannel(mainChannel)
            manager?.createNotificationChannel(alertChannel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("AppLock+", "🧹 LocationNotificationService destroyed")
        unregisterReceivers()
        stopForeground(true)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
