package com.example.applockplus

import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import com.example.applockplus.services.AppLockAccessibilityService

class MainActivity : FlutterActivity() {

    private val TAG = "MainActivity"
    private val CHANNEL = "applock/accessibility"
    private val UNLOCK_CHANNEL = "applock/unlock"
    private val LOCATION_CHANNEL = "applock/location_service"

    private val timeLockedApps = mutableSetOf<String>()
    private val locationLockedApps = mutableSetOf<String>()

    companion object {
        var currentLockedPackage: String? = null
        var currentLockedAppName: String? = null
    }

    override fun provideFlutterEngine(@NonNull context: android.content.Context): FlutterEngine? {
        val engine = FlutterEngineCache.getInstance().get(MyApplication.MAIN_ENGINE_ID)
        if (engine == null) {
            Log.w(TAG, "main_ENGINE_ID not found. Flutter will create a new engine.")
        } else {
            Log.d(TAG, "MainActivity using cached engine: ${MyApplication.MAIN_ENGINE_ID}")
        }
        return engine
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "Configuring Flutter engine with method channels")

        setupTimeLockChecker()
        setupLocationLockChecker()

        // ============================================================
        // =============== MAIN ACCESSIBILITY CHANNEL =================
        // ============================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "Method call received: ${call.method}, arguments: ${call.arguments}")

                when (call.method) {

                    "getInitialRoute" -> result.success(null)

                    "isAccessibilityServiceEnabled" -> {
                        val isEnabled = AppLockAccessibilityService.isServiceEnabled(this)
                        result.success(isEnabled)
                    }

                    "updateLockedApps" -> {
                        try {
                            val lockedApps = call.arguments as? List<String> ?: emptyList()
                            AppLockAccessibilityService.updateLockedApps(lockedApps)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPDATE_FAILED", "Failed to update locked apps", e.message)
                        }
                    }

                    // ---------------- TIME LOCK HANDLING ----------------
                    "addTimeLockedApp" -> {
                        val appName = call.arguments as? String ?: ""
                        synchronized(timeLockedApps) { timeLockedApps.add(appName) }
                        result.success(true)
                    }

                    "removeTimeLockedApp" -> {
                        val appName = call.arguments as? String ?: ""
                        synchronized(timeLockedApps) { timeLockedApps.remove(appName) }
                        result.success(true)
                    }

                    "getTimeLockedApps" -> result.success(timeLockedApps.toList())

                    // ---------------- LOCATION LOCK HANDLING ----------------
                    "addLocationLockedApp" -> {
                        val packageName = call.arguments as? String ?: ""
                        val actualPackageName = convertToPackageName(packageName)
                        synchronized(locationLockedApps) {
                            locationLockedApps.add(actualPackageName)
                        }
                        Log.d(
                            TAG,
                            "Added location locked app: $actualPackageName (from: $packageName)"
                        )
                        result.success(true)
                    }

                    "removeLocationLockedApp" -> {
                        val packageName = call.arguments as? String ?: ""
                        val actualPackageName = convertToPackageName(packageName)
                        synchronized(locationLockedApps) {
                            locationLockedApps.remove(actualPackageName)
                        }
                        Log.d(
                            TAG,
                            "Removed location locked app: $actualPackageName (from: $packageName)"
                        )
                        result.success(true)
                    }

                    "getLocationLockedApps" -> result.success(locationLockedApps.toList())

                    else -> result.notImplemented()
                }
            }

        // ============================================================
        // ====================== UNLOCK CHANNEL =======================
        // ============================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UNLOCK_CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "Unlock channel method: ${call.method}")

                when (call.method) {

                    "onUnlockSuccess" -> {
                        val packageName = call.arguments as? String
                        if (packageName != null) {
                            AppLockAccessibilityService.markAppUnlocked(packageName)
                        }
                        AppLockAccessibilityService.setUnlockUiActive(false)
                        AppLockAccessibilityService.setUnlockActivityReference(null)
                        result.success(true)
                    }

                    "onUnlockCancelled" -> {
                        AppLockAccessibilityService.setUnlockUiActive(false)
                        AppLockAccessibilityService.setUnlockActivityReference(null)
                        result.success(true)
                    }

                    "getLockedPackage" -> result.success(currentLockedPackage)

                    else -> result.notImplemented()
                }
            }

        // ============================================================
        // =============== LOCATION SERVICE CHANNEL ===================
        // ============================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {
                    "startLocationService" -> {
                        try {
                            val intent = android.content.Intent(
                                this,
                                com.example.applockplus.services.LocationNotificationService::class.java
                            )
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error(
                                "SERVICE_START_FAILED",
                                "Failed to start location service",
                                e.message
                            )
                        }
                    }

                    "stopLocationService" -> {
                        try {
                            val intent = android.content.Intent(
                                this,
                                com.example.applockplus.services.LocationNotificationService::class.java
                            )
                            stopService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error(
                                "SERVICE_STOP_FAILED",
                                "Failed to stop location service",
                                e.message
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ============================================================
    // ================= PACKAGE NAME CONVERTER ====================
    // ============================================================
    private fun convertToPackageName(appName: String): String {
        val packageMap = mapOf(
            "Instagram" to "com.instagram.android",
            "QMS" to "my.com.gms.qms.qmsapp",
            "QRPayBiz" to "com.example.qrpaybiz",
            "KTMB Mobile" to "com.ktmb.user.mobile",
            "Telegram" to "org.telegram.messenger",
            "My Calendar" to "com.google.android.calendar",
            "Messages" to "com.google.android.apps.messaging",
            "Chrome" to "com.android.chrome"
        )

        return packageMap[appName] ?: appName
    }

    private fun setupTimeLockChecker() {
        val checker: () -> Set<String> = {
            synchronized(timeLockedApps) { timeLockedApps.toSet() }
        }
        AppLockAccessibilityService.setTimeLockChecker(checker)
    }

    // ✅ FIX: Ensure ALL location-locked apps are returned correctly
    private fun setupLocationLockChecker() {
        val checker: () -> Set<String> = {
            synchronized(locationLockedApps) {
                // This returns ALL apps with location locks
                locationLockedApps.toSet()
            }
        }
        AppLockAccessibilityService.setLocationLockChecker(checker)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        Log.d(TAG, "MainActivity onUserLeaveHint - user left the app")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "MainActivity onPause - app going to background")
    }
}
