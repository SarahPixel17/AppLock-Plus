package com.example.applockplus.services 

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.example.applockplus.UnlockActivity

class AppLockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppLockService"
        private val lockedApps = mutableSetOf<String>()
        private var timeLockChecker: (() -> Set<String>)? = null
        private var locationLockChecker: (() -> Set<String>)? = null

        @Volatile private var isUnlockUiActive = false
        private var unlockActivityReference: UnlockActivity? = null

        private val temporarilyUnlockedApps = mutableSetOf<String>()
        private var currentForegroundApp: String? = null

        private const val TEMP_UNLOCK_DURATION = 5000L
        private val appUnlockTime = mutableMapOf<String, Long>()

        fun updateLockedApps(apps: List<String>) {
            synchronized(lockedApps) {
                lockedApps.clear()
                lockedApps.addAll(apps.filter { it.isNotEmpty() })
            }
            Log.d(TAG, "Manual locked apps updated → $lockedApps")
        }

        fun setTimeLockChecker(checker: (() -> Set<String>)?) {
            timeLockChecker = checker
        }

        fun setLocationLockChecker(checker: (() -> Set<String>)?) {
            locationLockChecker = checker
        }

        fun markAppUnlocked(packageName: String) {
            synchronized(temporarilyUnlockedApps) {
                temporarilyUnlockedApps.add(packageName)
                appUnlockTime[packageName] = System.currentTimeMillis()
            }
            Log.d(TAG, "Temporarily unlocked: $packageName")
        }

        fun isAppTemporarilyUnlocked(packageName: String): Boolean {
            return synchronized(temporarilyUnlockedApps) {
                val unlockTime = appUnlockTime[packageName]
                val isWithinTimeWindow = unlockTime != null &&
                    (System.currentTimeMillis() - unlockTime) < TEMP_UNLOCK_DURATION

                temporarilyUnlockedApps.contains(packageName) && isWithinTimeWindow
            }
        }

        fun clearTemporarilyUnlockedAppOnBackground(packageName: String) {
            synchronized(temporarilyUnlockedApps) {
                if (packageName != currentForegroundApp) {
                    temporarilyUnlockedApps.remove(packageName)
                    appUnlockTime.remove(packageName)
                    Log.d(TAG, "Cleared temporary unlock (background) for: $packageName")
                }
            }
        }

        fun clearTemporarilyUnlockedApps() {
            synchronized(temporarilyUnlockedApps) {
                temporarilyUnlockedApps.clear()
                appUnlockTime.clear()
            }
            Log.d(TAG, "Cleared all temporarily unlocked apps")
        }

        fun clearTemporarilyUnlockedApp(packageName: String) {
            synchronized(temporarilyUnlockedApps) {
                temporarilyUnlockedApps.remove(packageName)
                appUnlockTime.remove(packageName)
            }
            Log.d(TAG, "Cleared temporary unlock for: $packageName")
        }

        fun setUnlockUiActive(active: Boolean) {
            isUnlockUiActive = active
            Log.d(TAG, "Unlock UI active state: $active")
        }

        fun setUnlockActivityReference(activity: UnlockActivity?) {
            unlockActivityReference = activity
            Log.d(TAG, "Unlock activity reference updated: ${activity != null}")
        }

        fun isServiceEnabled(context: Context): Boolean {
            return Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )?.contains(context.packageName) == true
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }

        serviceInfo = info
        Log.d(TAG, "Accessibility Service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName == null) return

        val pkg = event.packageName.toString()

        if (pkg.startsWith("com.android") ||
            pkg.contains("launcher") ||
            pkg.contains("systemui") ||
            pkg == "android" ||
            pkg.contains("settings") ||
            pkg.contains("packageinstaller") ||
            pkg.startsWith("com.example.applockplus") ||
            pkg.contains("google")
        ) {
            if (currentForegroundApp != pkg) {
                currentForegroundApp?.let { previousApp ->
                    clearTemporarilyUnlockedAppOnBackground(previousApp)
                }
                currentForegroundApp = pkg
            }
            return
        }

        if (currentForegroundApp != pkg) {
            currentForegroundApp?.let { previousApp ->
                if (previousApp != pkg) {
                    clearTemporarilyUnlockedAppOnBackground(previousApp)
                }
            }
            currentForegroundApp = pkg
        }

        if (isAppTemporarilyUnlocked(pkg)) {
            Log.d(TAG, "App $pkg temporarily unlocked")
            return
        }

        val unlockUIActive = isUnlockUiActive && unlockActivityReference != null
        if (unlockUIActive) {
            Log.d(TAG, "Unlock UI active, skipping $pkg")
            return
        }

        val lockedNow = getLockedApps()
        Log.d(TAG, "Checking app: $pkg. Locked apps = $lockedNow")

        if (pkg in lockedNow) {
            launchUnlockScreen(pkg)
        }
    }

    // ✅ UPDATED METHOD WITH DETAILED LOGGING
    private fun getLockedApps(): Set<String> {
        val manual = synchronized(lockedApps) { lockedApps.toSet() }
        val timeBased = timeLockChecker?.invoke() ?: emptySet()
        val locationBased = locationLockChecker?.invoke() ?: emptySet()

        Log.d(TAG, "Manual locked apps: $manual")
        Log.d(TAG, "Time-based locked apps: $timeBased")
        Log.d(TAG, "Location-based locked apps: $locationBased")

        val finalSet = manual + timeBased + locationBased
        Log.d(TAG, "Final locked apps → $finalSet")
        return finalSet
    }

    private fun launchUnlockScreen(pkg: String) {
        if (isUnlockUiActive && unlockActivityReference != null) {
            Log.d(TAG, "Unlock UI already active, skipping launch")
            return
        }

        isUnlockUiActive = true

        try {
            val appName = getAppName(pkg)
            val intent = Intent(this, UnlockActivity::class.java).apply {
                putExtra("locked_package", pkg)
                putExtra("locked_app_name", appName)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_NO_HISTORY
                )
            }

            startActivity(intent)
            Log.d(TAG, "UnlockActivity launched for $appName ($pkg)")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch UnlockActivity: $e")
            isUnlockUiActive = false
        }
    }

    private fun getAppName(packageName: String): String {
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        isUnlockUiActive = false
        unlockActivityReference = null
        clearTemporarilyUnlockedApps()
        Log.w(TAG, "Accessibility service destroyed")
    }
}
