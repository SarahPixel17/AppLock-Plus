package com.example.applockplus

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.applockplus.services.AppLockAccessibilityService

class UnlockActivity : FlutterActivity() {
    private val TAG = "UnlockActivity"
    private val UNLOCK_CHANNEL = "applock/unlock"
    private var lockedPackage: String? = null
    private var lockedAppName: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lockedPackage = intent.getStringExtra("locked_package")
        lockedAppName = intent.getStringExtra("locked_app_name")

        Log.d(TAG, "UnlockActivity created for app: $lockedAppName (package: $lockedPackage)")

        // Set reference in accessibility service
        AppLockAccessibilityService.setUnlockActivityReference(this)
        AppLockAccessibilityService.setUnlockUiActive(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set the initial route to unlock
        flutterEngine.navigationChannel.setInitialRoute("unlock")

        // Set up method channel for unlock communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UNLOCK_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Unlock channel method: ${call.method}")
            when (call.method) {

                "getLockedPackage" -> {
                    Log.d(TAG, "Returning locked package: $lockedPackage and app name: $lockedAppName")
                    result.success(lockedAppName ?: lockedPackage)
                }

                "onUnlockSuccess" -> {
                    Log.d(TAG, "Unlock success for package: $lockedPackage")

                    // Mark app as temporarily unlocked
                    lockedPackage?.let { pkg ->
                        AppLockAccessibilityService.markAppUnlocked(pkg)
                    }

                    finishUnlock()
                    result.success(true)
                }

                "onUnlockCancelled" -> {
                    Log.d(TAG, "Unlock cancelled")

                    // Clear the temporary unlock when user cancels
                    lockedPackage?.let { pkg ->
                        AppLockAccessibilityService.clearTemporarilyUnlockedApp(pkg)
                    }

                    finishUnlock()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // Override to set initial route for Flutter
    override fun getInitialRoute(): String? {
        return "unlock"
    }

    private fun finishUnlock() {
        AppLockAccessibilityService.setUnlockUiActive(false)
        AppLockAccessibilityService.setUnlockActivityReference(null)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "UnlockActivity destroyed")

        AppLockAccessibilityService.setUnlockUiActive(false)
        AppLockAccessibilityService.setUnlockActivityReference(null)
    }

    override fun onBackPressed() {
        // Prevent back button from closing unlock screen
        Log.d(TAG, "Back button pressed in UnlockActivity - ignoring")
    }
}
