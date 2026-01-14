// Import required Dart and Flutter packages for async operations, JSON handling, UI, HTTP requests, storage, and app management
import 'dart:async'; // For Timer and asynchronous operations
import 'dart:convert'; // For JSON encoding and decoding operations
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:http/http.dart' as http; // For making HTTP requests to external APIs
import 'package:shared_preferences/shared_preferences.dart'; // For simple local storage of non-sensitive data
import 'package:device_apps/device_apps.dart'; // Added for app info (converting package names to app names)

// Import application services
import '../services/api_service.dart'; // Service for API communication with backend
import './services/notification_service.dart'; // Service for displaying notifications
import '../services/secure_storage_service.dart'; // Service for secure, encrypted storage

/// TimeLocksController - Manages time-based app locking rules and schedules
/// This controller handles creation, updating, deletion, and monitoring of time-based restrictions
/// Periodically checks current time against configured schedules to enforce locks
class TimeLocksController extends ChangeNotifier {
  // Internal list to store time lock configurations
  List<Map<String, dynamic>> _timeLocks = [];
  
  // Hardcoded username - TODO: replace with actual logged-in user's username
  final String username = "user1";

  // Timer for periodic checking of time lock status (every minute)
  Timer? _autoCheckTimer;
  
  // Set to track which apps have already triggered notifications (prevests spam)
  final Set<String> _notifiedApps = {};
  
  // Cache for app names to improve performance by reducing repeated DeviceApps lookups
  final Map<String, String> _appNameCache = {};

  /// Getter for time locks (read-only access)
  List<Map<String, dynamic>> get timeLocks => _timeLocks;

  /// Add a new time lock rule for an app
  /// Saves to backend API and triggers notification if successful
  /// 
  /// @param appName - Android package name or app name to lock
  /// @param start - Start time in ISO format (e.g., "2023-01-01T09:00:00.000") or HH:mm
  /// @param end - End time in ISO format or HH:mm
  /// @return bool - True if save was successful, false otherwise
  Future<bool> addTimeLock(String appName, String start, String end) async {
    // Call API service to save time lock to backend
    final success = await ApiService.saveTimeLock(username, appName, start, end);

    if (success) {
      await loadTimeLocks(); // Refresh local cache from API
      final displayName = await _getDisplayName(appName); // Convert to readable name
      _notifyIfEnabled( // Send notification if notifications are enabled
        "Time Lock Added",
        "App $displayName will be locked daily from $start to $end",
      );
    }
    return success;
  }

  /// Update existing time lock
  /// Modifies an existing time lock configuration directly via HTTP
  /// 
  /// @param id - Unique ID of the time lock to update
  /// @param appName - Updated app name (package name)
  /// @param start - Updated start time in ISO format or HH:mm
  /// @param end - Updated end time in ISO format or HH:mm
  /// @return bool - True if update was successful, false otherwise
  Future<bool> updateTimeLock(int id, String appName, String start, String end) async {
    try {
      // Construct API URL for updating time lock
      final url = Uri.parse("${ApiService.baseUrl}/update_time_lock.php");
      
      // Send HTTP POST request with updated data
      final response = await http.post(url, body: {
        "id": id.toString(),
        "username": username,
        "app_name": appName,
        "start_time": start,
        "end_time": end,
      });
      
      // Check if request was successful
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data["success"] == true;

        if (success) {
          await loadTimeLocks(); // Refresh local cache
          final displayName = await _getDisplayName(appName); // Convert to readable name
          _notifyIfEnabled( // Send notification
            "Time Lock Updated",
            "Lock for $displayName has been updated.",
          );
        }
        return success;
      }
      return false; // HTTP request failed
    } catch (e) {
      print("updateTimeLock error: $e");
      return false; // Exception occurred
    }
  }

  /// Load all time locks from API or local cache
  /// UPDATED TO SORT BY LATEST FIRST (descending order by ID)
  /// Prioritizes API data, falls back to cached data if API fails or is unavailable
  Future<void> loadTimeLocks() async {
    try {
      // STEP 1: Try to load from API (primary data source)
      final locks = await ApiService.getTimeLocks(username);
      if (locks.isNotEmpty) {
        // Sort by ID in descending order (latest/largest ID first)
        locks.sort((a, b) {
          final idA = a["id"] as int;
          final idB = b["id"] as int;
          return idB.compareTo(idA); // Descending order (idB > idA returns positive)
        });
        _timeLocks = locks; // Update local state
        notifyListeners(); // Notify UI widgets to rebuild
        
        // Cache to SharedPreferences for offline access
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("time_locks", jsonEncode(_timeLocks));
      } else {
        // STEP 2: API returned empty or failed - try loading from local cache
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString("time_locks");
        if (saved != null && saved.isNotEmpty) {
          _timeLocks = List<Map<String, dynamic>>.from(jsonDecode(saved));
          
          // Sort saved locks as well (maintain consistent ordering)
          _timeLocks.sort((a, b) {
            final idA = a["id"] as int;
            final idB = b["id"] as int;
            return idB.compareTo(idA); // Descending order
          });
          notifyListeners(); // Notify UI widgets to rebuild
        }
      }
      _startAutoCheck(); // Start or restart periodic checking
    } catch (e) {
      print("X loadTimeLocks error: $e"); // Log error but don't crash
    }
  }

  // Delete a time lock by ID
  /// Removes from API and local cache, triggers notification on success
  /// 
  /// @param id - Unique ID of the time lock to delete
  /// @return bool - True if deletion was successful, false otherwise
  Future<bool> deleteTimeLock(int id) async {
    final success = await ApiService.deleteTimeLock(id, username);
    if (success) {
      // Remove from local list
      _timeLocks.removeWhere((lock) => lock["id"] == id);
      
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      prefs.setString("time_locks", jsonEncode(_timeLocks));
      
      // Send notification if enabled
      _notifyIfEnabled("Time Lock Removed", "A scheduled lock was deleted.");
    }
    return success;
  }

  /// Check if an app is currently locked based on time schedules
  /// Evaluates all time locks for the given app and current time
  /// 
  /// @param appName - Android package name or app name to check
  /// @return bool - True if app is currently locked, false otherwise
  bool isLockedNow(String appName) {
    final now = DateTime.now(); // Get current time
    
    // Check all time locks for this app
    for (final lock in _timeLocks) {
      if (lock["app_name"] == appName) {
        final start = _parseDateTime(lock["start_time"]); // Parse start time
        final end = _parseDateTime(lock["end_time"]); // Parse end time
        
        // Check if current time is within the locked time range
        if (_isNowWithinRange(now, start, end)) {
          // App is currently locked
          if (!_notifiedApps.contains(appName)) {
            // Send notification if not already sent for this lock session
            _getDisplayName(appName).then((displayName) {
              _notifyIfEnabled(
                "Time Lock Active",
                "App $displayName is currently locked until ${_formatTime(end)}",
              );
            });
            _notifiedApps.add(appName); // Mark as notified
          }
          return true; // App is locked
        } else {
          // App is not currently locked - remove from notification tracking
          _notifiedApps.remove(appName);
        }
      }
    }
    return false; // App is not locked by any time rule
  }

  /// Parse time string to DateTime object
  /// Supports both ISO format (full DateTime) and HH:mm format
  /// 
  /// @param timeStr - Time string in ISO format or HH:mm
  /// @return DateTime - Parsed DateTime object (using today's date for HH:mm)
  DateTime _parseDateTime(String timeStr) {
    try {
      return DateTime.parse(timeStr); // Try ISO format first
    } catch (_) {
      // If ISO format fails, parse as HH:mm format
      final now = DateTime.now(); // Use today's date
      final parts = timeStr.split(':');
      return DateTime(now.year, now.month, now.day, 
                      int.parse(parts[0]), // Hour
                      int.parse(parts[1])); // Minute
    }
  }

  /// Checks if current time is within a specified time range
  /// Handles both normal ranges and ranges that span across midnight
  /// 
  /// @param now - Current DateTime to check
  /// @param start - Start time of the range
  /// @param end - End time of the range
  /// @return bool - True if current time is within range, false otherwise
  bool _isNowWithinRange(DateTime now, DateTime start, DateTime end) {
    // Check if the end time is before start time (range spans midnight)
    if (end.isBefore(start)) {
      // For midnight-spanning ranges, check if time is after start OR before end (next day)
      return now.isAfter(start) || now.isBefore(end.add(const Duration(days: 1)));
    } else {
      // For normal ranges, check if time is between start and end
      return now.isAfter(start) && now.isBefore(end);
    }
  }

  /// Format DateTime to HH:mm string for display
  /// 
  /// @param time - DateTime object to format
  /// @return String - Formatted time as "HH:mm" (e.g., "09:30")
  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  /// Auto-check every minute for time lock status changes
  /// Starts a timer that triggers UI updates every minute
  void _startAutoCheck() {
    _autoCheckTimer?.cancel(); // Cancel existing timer if any
    _autoCheckTimer = Timer.periodic(const Duration(minutes: 1), (Timer timer) {
      notifyListeners(); // Trigger UI rebuild to reflect time changes
    });
  }

  /// Helper function to get display name for any package name
  /// Uses cache for performance, falls back to DeviceApps lookup or formatting
  /// 
  /// @param packageName - Android package name (e.g., "com.example.app")
  /// @return Future<String> - Human-readable app name
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

    // Try to get app info from device using DeviceApps
    try {
      final Application? app = await DeviceApps.getApp(packageName);
      if (app != null) {
        _appNameCache[packageName] = app.appName; // Cache the result
        return app.appName; // Return actual app name
      }
    } catch (e) {
      print("Error getting app info for $packageName: $e");
    }

    // Fallback: format package name to look nicer
    final formattedName = _formatPackageName(packageName);
    _appNameCache[packageName] = formattedName; // Cache formatted name
    return formattedName;
  }

  /// Format a package name to a more readable display name
  /// Example: "com.example.myapp" -> "Myapp"
  /// 
  /// @param packageName - Android package name
  /// @return String - Formatted display name
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

  /// Notification helper (UPDATED)
  /// Sends notification only if notifications are enabled in user settings
  /// 
  /// @param title - Notification title
  /// @param body - Notification body text
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

  /// Return currently locked apps based on time schedules
  /// Useful for native service integration and UI display
  /// 
  /// @return Set<String> - Set of package names currently locked by time rules
  Set<String> getCurrentlyTimeLockedApps() {
    final lockedApps = <String>{}; // Use Set for unique values
    for (final lock in _timeLocks) {
      if (isLockedNow(lock["app_name"])) {
        lockedApps.add(lock["app_name"]); // Add to set (duplicates automatically ignored)
      }
    }
    return lockedApps;
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel(); // Cancel timer to prevent memory leaks
    super.dispose();
  }
}