// Import required Flutter packages and application services
import 'package:flutter/material.dart'; // For Flutter UI components, ChangeNotifier, and debugPrint
import 'package:flutter/services.dart'; // For MethodChannel to communicate with native Android code
import 'package:shared_preferences/shared_preferences.dart'; // For simple local storage of non-sensitive data
import './services/api_service.dart'; // Service for API communication with backend
import './services/background_service.dart'; // Service for background tasks and periodic checks

/// LockedAppsController - Manages the list of manually locked applications
/// This controller handles adding, removing, and syncing locked apps with both backend and native services
/// Uses ChangeNotifier to update UI components when data changes
class LockedAppsController extends ChangeNotifier {
  // Internal list to store locked app configurations
  List<Map<String, dynamic>> _lockedApps = [];
  
  // Hardcoded username - TODO: replace with actual logged-in user's username
  final String username = "user1";

  // Fixed: Use static const for MethodChannel - ensures single instance for native communication
  // This channel communicates with the native Android accessibility service
  static const MethodChannel _channel = MethodChannel('applock/accessibility');

  /// Getter for locked apps (read-only access)
  List<Map<String, dynamic>> get lockedApps => _lockedApps;

  /// Load locked apps from API with fallback to local storage
  /// Tries to fetch from backend first, falls back to SharedPreferences if API fails
  Future<void> loadLockedApps() async {
    try {
      debugPrint("Loading locked apps...");
      final prefs = await SharedPreferences.getInstance();

      try {
        // STEP 1: Try to load from API (primary data source)
        final apiData = await ApiService.getLockedApps(username);
        if (apiData.isNotEmpty) {
          // Transform API data to consistent format with proper error handling
          _lockedApps = apiData.map((app) {
            if (app is Map<String, dynamic>) {
              return {
                "id": app["id"], // Unique ID from backend
                "app_name": app["app_name"] ?? "", // Human-readable app name
                "package_name": app["package_name"] ?? app["app_name"] ?? "" // Android package name
              };
            }
            return {"id": null, "app_name": "", "package_name": ""}; // Fallback for invalid data
          }).where((app) => app["app_name"] != null && app["app_name"].isNotEmpty).toList();

          await _saveToPrefs(prefs); // Cache API data locally for offline access
          debugPrint("Loaded ${_lockedApps.length} locked apps from API");

          // Sync the loaded apps with the native Android accessibility service
          await _syncWithNativeService();
        } else {
          debugPrint("API returned empty locked apps list");
          throw Exception("API returned empty"); // Trigger fallback to local storage
        }
      } catch (apiError) {
        // STEP 2: API load failed, fall back to local SharedPreferences
        debugPrint("API load failed, trying local storage: $apiError");
        final saved = prefs.getStringList('locked_apps') ?? [];
        if (saved.isNotEmpty) {
          // Reconstruct app list from cached package names
          _lockedApps = saved.map((name) => {
            "id": null, // No ID from backend (local only)
            "app_name": name, // Use package name as display name
            "package_name": name // Same as app_name for local data
          }).toList();
          debugPrint("Loaded ${_lockedApps.length} locked apps from SharedPreferences");
        } else {
          // No data in API or local storage - start with empty list
          debugPrint("No locked apps found - starting fresh");
          _lockedApps = [];
        }
      }
      notifyListeners(); // Notify UI widgets to rebuild with new data
    } catch (e) {
      // Handle any unexpected errors during loading
      debugPrint("loadLockedApps error: $e");
      _lockedApps = []; // Reset to empty list on error
      notifyListeners(); // Still notify listeners to update UI
    }
  }

  // FIXED: Proper type handling for addLockedApp
  /// Add an app to the locked list by package name
  /// Updates both API (if available) and local storage, then syncs with native service
  Future<bool> addLockedApp(String packageName) async {
    try {
      debugPrint("+ Adding locked app with package: $packageName");
      final prefs = await SharedPreferences.getInstance();

      // Check if app is already locked to avoid duplicates
      if (_lockedApps.any((app) => app["package_name"] == packageName)) {
        debugPrint("App $packageName already in locked list");
        return true; // Already locked is considered success
      }

      bool apiSuccess = false;
      try {
        // STEP 1: Try to add to backend API
        // Use the package name directly for API call (not display name)
        apiSuccess = await ApiService.addLockedApp(username, packageName);
        debugPrint(apiSuccess ? "API add successful" : "API add failed");
      } catch (apiError) {
        // API call failed, but continue with local addition for offline support
        debugPrint("API add failed, continuing locally: $apiError");
      }

      // FIXED: Proper map structure with consistent field names
      // STEP 2: Add to local list
      _lockedApps.add({
        "id": null, // Will be populated when syncing with API succeeds
        "app_name": packageName, // Use package name as display name for now (will be updated later)
        "package_name": packageName // Store the actual package name
      });
      
      // STEP 3: Persist to local storage
      await _saveToPrefs(prefs);
      notifyListeners(); // Notify UI to update

      // STEP 4: Sync with native Android accessibility service
      await _syncWithNativeService();

      debugPrint("✓ Added $packageName to locked apps. Total: ${_lockedApps.length}");
      return true; // Success
    } catch (e) {
      debugPrint("addLockedApp error: $e");
      return false; // Failure
    }
  }

  /// Remove an app from the locked list by package name
  /// Updates both local storage and syncs with native service
  Future<bool> removeLockedApp(String packageName) async {
    try {
      debugPrint("- Removing locked app: $packageName");
      final prefs = await SharedPreferences.getInstance();

      final initialLength = _lockedApps.length; // Track initial count for comparison

      // Remove app by package name (case-sensitive exact match)
      _lockedApps.removeWhere((app) => app["package_name"] == packageName);

      // Check if removal was successful (list length decreased)
      if (_lockedApps.length < initialLength) {
        // STEP 1: Update local storage
        await _saveToPrefs(prefs);
        notifyListeners(); // Notify UI to update

        // STEP 2: Sync with native Android accessibility service
        await _syncWithNativeService();

        debugPrint("✓ Removed locked app: $packageName. Remaining: ${_lockedApps.length}");
        return true; // Success
      } else {
        debugPrint("App $packageName not found in locked list");
        return false; // App wasn't in the list
      }
    } catch (e) {
      debugPrint("removeLockedApp error: $e");
      return false; // Failure
    }
  }

  /// Check if a specific app is locked by its package name
  /// Useful for quick checks without loading entire list
  bool isLocked(String packageName) {
    return _lockedApps.any((app) => app["package_name"] == packageName);
  }

  /// Getter for count of locked apps (convenience method)
  int get lockedAppsCount => _lockedApps.length;
  
  /// Check if there are any locked apps (convenience method)
  bool get hasLockedApps => _lockedApps.isNotEmpty;

  /// Refresh locked apps from data source
  /// Calls loadLockedApps to get fresh data
  Future<void> refresh() async {
    await loadLockedApps();
  }

  /// Save current locked apps list to SharedPreferences for offline access
  /// Only saves package names to minimize storage usage
  Future<void> _saveToPrefs(SharedPreferences prefs) async {
    try {
      // Extract just package names for storage (smaller footprint)
      final packageNames = _lockedApps.map((e) => e["package_name"] as String).toList();
      await prefs.setStringList('locked_apps', packageNames);
      debugPrint("✓ Saved ${packageNames.length} locked apps to SharedPreferences");
    } catch (e) {
      debugPrint("Error saving to SharedPreferences: $e");
    }
  }

  /// Sync locked apps with native Android accessibility service
  /// Sends list of package names to native code via MethodChannel
  Future<void> _syncWithNativeService() async {
    try {
      // Extract package names from locked apps
      final packageNames = _lockedApps.map((app) => app["package_name"] as String).toList();

      // Filter out AppLock+ itself to prevent self-lockout
      final filteredApps = packageNames.where((pkg) => !pkg.startsWith("com.example.applockplus")).toList();

      debugPrint("Syncing ${filteredApps.length} locked apps with native service: $filteredApps");

      // Call native method via MethodChannel to update accessibility service
      await _channel.invokeMethod('updateLockedApps', filteredApps);
      debugPrint("✓ Successfully synced ${filteredApps.length} locked apps with native service");
    } catch (e) {
      debugPrint("Error syncing with native service: $e");
    }
  }

  /// Get list of package names from locked apps
  /// Useful for native service integration and other components
  List<String> get lockedPackageNames {
    return _lockedApps.map((app) => app["package_name"] as String).toList();
  }

  @override
  void dispose() {
    debugPrint("LockedAppsController disposed");
    super.dispose(); // Call parent dispose method
  }
}