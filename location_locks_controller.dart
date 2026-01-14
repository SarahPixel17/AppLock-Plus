// Import required packages for JSON handling, distance calculation, UI, storage, geolocation, and app management
import 'dart:convert'; // For JSON encoding/decoding operations
import 'dart:math' show cos, sqrt, asin; // For mathematical calculations in distance computation
import 'package:flutter/material.dart'; // For Flutter UI components and debugPrint
import 'package:shared_preferences/shared_preferences.dart'; // For simple local storage of non-sensitive data
import 'package:geolocator/geolocator.dart'; // For accessing device GPS/location services
import 'package:device_apps/device_apps.dart'; // For accessing installed applications on device
import './services/api_service.dart'; // Custom service for API communication with backend
import './services/notification_service.dart'; // Custom service for displaying notifications
import './services/secure_storage_service.dart'; // Custom service for secure, encrypted storage

/// LocationLocksController - Manages location-based app locking rules
/// Handles creation, updating, deletion, and monitoring of location-based restrictions
/// Integrates with API, notifications, and native Android services
class LocationLocksController extends ChangeNotifier {
  // Internal list to store location lock configurations
  List<Map<String, dynamic>> _locationLocks = [];
  
  // Hardcoded username - TODO: replace with actual logged-in user's username
  final String username = "user1";
  
  // Cache for app names to improve performance by reducing repeated lookups
  final Map<String, String> _appNameCache = {};

  /// Getter for location locks (read-only access)
  List<Map<String, dynamic>> get locationLocks => _locationLocks;

  // NEW: Method to get location-locked package names for native service
  /// Extracts package names from all location locks for native Android service integration
  /// Returns a Set to ensure uniqueness (no duplicate package names)
  Set<String> getLocationLockedPackageNames() {
    final packageNames = <String>{}; // Use Set for unique values
    for (final lock in _locationLocks) {
      // Try package_name first, fallback to app_name
      final packageName = lock["package_name"] ?? lock["app_name"];
      if (packageName != null && packageName.isNotEmpty) {
        packageNames.add(packageName); // Add to set (duplicates automatically ignored)
      }
    }
    return packageNames; // Return unique package names
  }

  /// Check if GPS/location services are enabled on the device
  /// Shows a dialog prompting user to enable GPS if disabled
  Future<bool> _checkGpsStatus(BuildContext context) async {
    // Check if location services are enabled on the device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    // If GPS is disabled and context is still valid, show dialog
    if (!serviceEnabled && context.mounted) {
      await showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          backgroundColor: const Color(0xFFF9E9D2), // Light beige background
          title: const Text(
            "Location Services Disabled",
            style: TextStyle(color: Color(0xFF553F2B)), // Dark brown text
          ),
          content: const Text(
            "Please enable GPS to use the location-based lock feature.",
            style: TextStyle(color: Color(0xFF553F2B)), // Dark brown text
          ),
          actions: <Widget>[
            // Cancel button to dismiss dialog
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            // Settings button to open location settings
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await Geolocator.openLocationSettings(); // Open device location settings
              },
              child: const Text(
                "Open Settings",
                style: TextStyle(color: Color(0xFF936B46)), // Gold/accent color
              ),
            ),
          ],
        ),
      );
      return false; // GPS is not enabled
    }
    return true; // GPS is enabled or dialog wasn't shown
  }

  /// Add a new location-based rule (with package name enforcement)
  /// Validates GPS status, sends data to API, and triggers notifications
  Future<bool> addLocationLock(
    BuildContext context,
    String appName, // Human-readable app name
    String packageName, // Android package name (e.g., com.example.app)
    String locationName, // Name of the location (user-defined or reverse-geocoded)
    double lat, // Latitude coordinate
    double lon, // Longitude coordinate
  ) async {
    // Check GPS status before proceeding
    final gpsOk = await _checkGpsStatus(context);
    if (!gpsOk) return false; // Stop if GPS is disabled

    // Clean up location name, use default if empty
    final trimmedName = locationName.trim();
    final name = trimmedName.isEmpty ? "Unnamed Location" : trimmedName;

    // Use the actual package name (important for native service integration)
    final finalPackageName = packageName;

    // Call API service to save location lock to backend
    final success = await ApiService.saveLocationLock(
      username,
      appName,
      finalPackageName, // Always store actual package name
      name,
      lat,
      lon,
    );

    // Handle successful save
    if (success) {
      await loadLocationLocks(); // Refresh local cache from API
      final displayName = await _getDisplayName(appName); // Get user-friendly app name
      _notifyIfEnabled( // Send notification if notifications are enabled
        "Location Rule Added",
        "$displayName will be locked at $name",
      );
    } else {
      // Log failure (debug only, not shown to user)
      debugPrint("X Failed to save location lock for $appName");
    }

    return success; // Return success/failure status
  }

  /// Update existing location lock
  /// Modifies an existing location lock configuration
  Future<bool> updateLocationLock(
    int id, // Unique ID of the location lock to update
    String appName, // Human-readable app name
    String packageName, // Android package name
    String locationName, // Updated location name
    double lat, // Updated latitude
    double lon, // Updated longitude
  ) async {
    // Clean up location name, use default if empty
    final trimmedName = locationName.trim();
    final name = trimmedName.isEmpty ? "Unnamed Location" : trimmedName;

    // Call API service to update location lock
    final success = await ApiService.updateLocationLock(
      id,
      username,
      appName,
      packageName,
      name,
      lat,
      lon,
    );

    // Handle successful update
    if (success) {
      // Find the index of the lock to update
      final index = _locationLocks.indexWhere((lock) => lock["id"] == id);
      if (index != -1) {
        // Update local cache with new values
        _locationLocks[index] = {
          "id": id,
          "app_name": appName,
          "package_name": packageName,
          "location_name": name,
          "latitude": lat,
          "longitude": lon,
        };
        await _cacheLocationLocks(); // Persist to local storage
        notifyListeners(); // Notify UI widgets to rebuild

        // Send notification if enabled
        final displayName = await _getDisplayName(appName);
        _notifyIfEnabled(
          "Location Rule Updated",
          "Settings for $displayName at $name have been updated.",
        );
      }
    }
    return success; // Return success/failure status
  }

  /// Load all location locks from API or local cache
  /// Prioritizes API data, falls back to cached data if API fails or is unavailable
  Future<void> loadLocationLocks() async {
    // Try to load from API first
    final locks = await ApiService.getLocationLocks(username);

    if (locks.isNotEmpty) {
      // API returned data - use it and cache locally
      _locationLocks = locks;
      await _cacheLocationLocks();
    } else {
      // API returned empty or failed - try loading from local cache
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString("location_locks");
      if (saved != null && saved.isNotEmpty) {
        // Parse cached JSON data
        _locationLocks = List<Map<String, dynamic>>.from(jsonDecode(saved) as List);
      } else {
        // No cached data - use empty list
        _locationLocks = [];
      }
    }
    notifyListeners(); // Notify UI widgets to rebuild with new data
  }

  /// Delete a location lock by ID
  /// Removes from API and local cache
  Future<bool> deleteLocationLock(int id) async {
    // Call API service to delete from backend
    final success = await ApiService.deleteLocationLock(id);
    
    // Handle successful deletion
    if (success) {
      // Remove from local list
      _locationLocks.removeWhere((lock) => lock["id"] == id);
      await _cacheLocationLocks(); // Update local cache
      notifyListeners(); // Notify UI widgets to rebuild
      
      // Send notification if enabled
      _notifyIfEnabled(
        "Location Rule Removed",
        "A saved location lock was deleted.",
      );
    }
    return success; // Return success/failure status
  }

  /// Cache location locks to SharedPreferences for offline access
  /// Stores as JSON string for persistence
  Future<void> _cacheLocationLocks() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("location_locks", jsonEncode(_locationLocks));
  }

  /// Helper: Get display name for a package name
  /// Uses cache for performance, falls back to device lookup or formatting
  Future<String> _getDisplayName(String packageName) async {
    // Check cache first for performance
    if (_appNameCache.containsKey(packageName)) {
      return _appNameCache[packageName]!;
    }

    // If not a package name (no dots), return as-is
    if (!packageName.contains('.')) {
      _appNameCache[packageName] = packageName;
      return packageName;
    }

    // Try to get app info from device
    try {
      final Application? app = await DeviceApps.getApp(packageName);
      if (app != null) {
        _appNameCache[packageName] = app.appName; // Cache the result
        return app.appName; // Return actual app name
      }
    } catch (e) {
      // Log error but continue with fallback
      print("Error getting app info for $packageName: $e");
    }

    // Fallback: format package name to look nicer
    final formattedName = _formatPackageName(packageName);
    _appNameCache[packageName] = formattedName; // Cache formatted name
    return formattedName;
  }

  /// Format a package name to a more readable display name
  /// Example: "com.example.myapp" -> "Myapp"
  String _formatPackageName(String packageName) {
    final parts = packageName.split('.');
    if (parts.length > 1) {
      final lastPart = parts.last;
      if (lastPart.isNotEmpty) {
        // Capitalize first letter, keep rest as-is
        return lastPart[0].toUpperCase() + lastPart.substring(1);
      }
    }
    return packageName; // Return original if formatting fails
  }

  /// Updated Notification helper
  /// Sends notification only if notifications are enabled in user settings
  Future<void> _notifyIfEnabled(String title, String body) async {
    try {
      // Check user preference for notifications
      final enabled = await SecureStorageService.isNotificationsEnabled();
      if (enabled) {
        // Send notification through NotificationService
        await NotificationService.showNotification(title: title, body: body);
      }
    } catch (e) {
      // Log error but don't crash - notifications are non-critical
      debugPrint("Error in _notifyIfEnabled: $e");
    }
  }
}