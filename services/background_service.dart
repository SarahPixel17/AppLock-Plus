// Import required Dart and Flutter packages
import 'dart:async'; // For Timer and asynchronous operations
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/services.dart'; // For MethodChannel and platform communication
import '../services/api_service.dart'; // Custom API service for backend communication
import '../services/secure_storage_service.dart'; // Secure storage service for sensitive data

/// Background service class for managing app lock enforcement in the background
/// This service periodically checks and enforces time-based, location-based, and manual locks
class BackgroundService {
  // Timer for periodic background checks
  static Timer? _timer;
  
  // Flag to track if the background service is currently running
  static bool _isRunning = false;
  
  // Flag to prevent concurrent execution of background checks
  static bool _isChecking = false;

  /// Starts the background service with periodic checks
  /// Initializes a timer that runs checks every 15 seconds
  static Future<void> start() async {
    // Prevent starting if already running
    if (_isRunning) return;
    _isRunning = true;

    debugPrint("AppLock+ Background Service Started");

    // Run initial check immediately on service start
    await _runChecks();

    // Set up periodic timer to run checks every 15 seconds
    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _runChecks();
    });
  }

  /// Stops the background service and cancels the periodic timer
  static void stop() {
    _timer?.cancel(); // Cancel the timer if it exists
    _isRunning = false; // Update running state
    debugPrint("AppLock+ Background Service Stopped");
  }

  /// Main method that orchestrates all background check operations
  /// Prevents concurrent execution using the _isChecking flag
  static Future<void> _runChecks() async {
    // Skip if a check is already in progress
    if (_isChecking) {
      debugPrint("Background check already in progress, skipping...");
      return;
    }

    // Set checking flag to prevent concurrent execution
    _isChecking = true;
    debugPrint("Background lock enforcement triggered...");

    try {
      // Execute all types of lock checks in sequence
      await _checkTimeBasedLocks();      // Check time-based restrictions
      await _checkLocationBasedLocks();  // Check location-based restrictions
      await _syncManualLocks();          // Sync manually locked apps
      debugPrint("Background check completed successfully");
    } catch (e) {
      // Log any errors during the background check process
      debugPrint("Background check failed: $e");
    } finally {
      // Always reset the checking flag to allow future checks
      _isChecking = false;
    }
  }

  /// Checks and enforces time-based locks for apps
  /// Retrieves time lock configurations from API and applies them based on current time
  static Future<void> _checkTimeBasedLocks() async {
    try {
      // Fetch time-based lock configurations for the user
      final timeLocks = await ApiService.getTimeLocks("user1");
      final now = DateTime.now(); // Get current time

      // Process each time lock configuration
      for (final lock in timeLocks) {
        // Extract app identifier (package name)
        final packageName = lock["app_name"]; // Use actual package name
        // Parse start and end times from the lock configuration
        final startTime = _parseTime(lock["start_time"]);
        final endTime = _parseTime(lock["end_time"]);
        
        // Check if current time falls within the restricted time range
        if (_isTimeWithinRange(now, startTime, endTime)) {
          debugPrint("Time lock active for $packageName - $startTime to $endTime");
          // Apply time lock via native platform
          await _syncTimeLockWithNative(packageName, true);
        } else {
          // Remove time lock via native platform
          await _syncTimeLockWithNative(packageName, false);
        }
      }
    } catch (e) {
      // Log errors specific to time lock checking
      debugPrint("Time lock check failed: $e");
    }
  }

  /// Synchronizes time lock status with the native platform
  /// Communicates with Android native code via MethodChannel
  static Future<void> _syncTimeLockWithNative(String packageName, bool shouldLock) async {
    try {
      // Initialize MethodChannel for native communication
      const channel = MethodChannel('applock/accessibility');
      
      if (shouldLock) {
        // Add app to time-locked list on native side
        await channel.invokeMethod('addTimeLockedApp', packageName);
        debugPrint("✓ Time lock synced for: $packageName");
      } else {
        // Remove app from time-locked list on native side
        await channel.invokeMethod('removeTimeLockedApp', packageName);
        debugPrint("✓ Time lock removed for: $packageName");
      }
    } catch (e) {
      // Log errors during native communication
      debugPrint("Failed to sync time lock with native: $e");
    }
  }

  /// Checks and enforces location-based locks for apps
  /// Retrieves location lock configurations from API
  static Future<void> _checkLocationBasedLocks() async {
    try {
      // Fetch location-based lock configurations for the user
      final locationLocks = await ApiService.getLocationLocks("user1");
      
      if (locationLocks.isNotEmpty) {
        debugPrint("Found ${locationLocks.length} location locks to check");
        
        // Process each location lock configuration
        for (final lock in locationLocks) {
          // Extract package name with fallback to app_name
          final packageName = lock["package_name"] ?? lock["app_name"]; // Prefer package_name
          // Note: Actual location checking is handled by AppMonitorService
          // This just syncs the potential lock configuration
          await _syncLocationLockWithNative(packageName, true);
        }
      }
    } catch (e) {
      // Log errors specific to location lock checking
      debugPrint("Location lock check failed: $e");
    }
  }

  /// Synchronizes location lock status with the native platform
  /// Communicates with Android native code via MethodChannel
  static Future<void> _syncLocationLockWithNative(String packageName, bool shouldLock) async {
    try {
      // Initialize MethodChannel for native communication
      const channel = MethodChannel('applock/accessibility');
      
      if (shouldLock) {
        // Add app to location-locked list on native side
        await channel.invokeMethod('addLocationLockedApp', packageName);
        debugPrint("✓ Location lock synced for: $packageName");
      } else {
        // Remove app from location-locked list on native side
        await channel.invokeMethod('removeLocationLockedApp', packageName);
        debugPrint("✓ Location lock removed for: $packageName");
      }
    } catch (e) {
      // Log errors during native communication
      debugPrint("Failed to sync location lock with native: $e");
    }
  }

  /// Synchronizes manually locked apps with the native platform
  /// Fetches locked apps from API and updates native accessibility service
  static Future<void> _syncManualLocks() async {
    try {
      // Initialize MethodChannel for native communication
      const channel = MethodChannel('applock/accessibility');
      
      // Fetch manually locked apps from the API
      final lockedApps = await ApiService.getLockedApps("user1");

      // Extract package names safely, handling potential null values
      final packageNames = <String>[];
      for (final app in lockedApps) {
        try {
          // Try to get package_name first, fall back to app_name if not available
          final packageName = app["package_name"]?.toString() ?? app["app_name"]?.toString() ?? '';
          if (packageName.isNotEmpty) {
            packageNames.add(packageName);
          }
        } catch (e) {
          // Log errors for individual app processing
          debugPrint("Error processing app: $e");
        }
      }

      // Don't lock AppLock+ itself to prevent self-lockout
      final filteredApps = packageNames.where((pkg) => !pkg.startsWith("com.example.applockplus")).toList();

      debugPrint("Syncing ${filteredApps.length} manual locked apps with native service");
      
      // Update the native accessibility service with filtered app list
      await channel.invokeMethod('updateLockedApps', filteredApps);
      debugPrint("✓ Successfully synced ${filteredApps.length} manual locked apps");

    } on MissingPluginException catch (e) {
      // Handle case where MethodChannel is not properly registered
      debugPrint("Method channel not available: ${e.message}");
    } on PlatformException catch (e) {
      // Handle platform-specific exceptions
      debugPrint("Platform exception during sync: ${e.message}");
    } catch (e) {
      // Handle all other exceptions
      debugPrint("Failed to sync manual locks with native service: $e");
    }
  }

  /// Parses time string into DateTime object
  /// Supports both ISO format (full DateTime) and HH:mm format
  static DateTime _parseTime(String timeStr) {
    try {
      // First try to parse as full ISO DateTime string
      return DateTime.parse(timeStr);
    } catch (_) {
      // If ISO format fails, try parsing as HH:mm format
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final now = DateTime.now();
        // Create DateTime using today's date with parsed hour and minute
        return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      }
      // Return current time as fallback
      return DateTime.now();
    }
  }

  /// Determines if the current time is within a specified time range
  /// Handles both normal ranges and ranges that span across midnight
  static bool _isTimeWithinRange(DateTime now, DateTime start, DateTime end) {
    // Check if the end time is before start time (range spans midnight)
    if (end.isBefore(start)) {
      // For midnight-spanning ranges, check if time is after start OR before end (next day)
      return now.isAfter(start) || now.isBefore(end.add(const Duration(days: 1)));
    } else {
      // For normal ranges, check if time is between start and end
      return now.isAfter(start) && now.isBefore(end);
    }
  }

  /// Getter to check if the background service is currently running
  static bool get isRunning => _isRunning;

  /// Manually triggers a background check, useful for testing or immediate sync
  static Future<void> forceCheck() async {
    debugPrint("Manual background check requested");
    await _runChecks();
  }
}