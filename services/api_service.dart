// ======================================================================
// API SERVICE - AppLock+ Backend Communication Layer
// ======================================================================
// Purpose: Handles all HTTP requests between the Flutter app and PHP backend
// Responsible for: User authentication, app locking, time/location rules, sync
// ======================================================================

// Import core Dart libraries for JSON parsing and async operations
import 'dart:convert';
// HTTP client for making network requests (GET, POST, PUT, DELETE)
import 'package:http/http.dart' as http;
// Geolocation package for calculating distances between coordinates
import 'package:geolocator/geolocator.dart';
// Local secure storage service for sensitive data (PIN, pattern, etc.)
import './secure_storage_service.dart';

class ApiService {
  // ====================================================================
  // BASE URL CONFIGURATION
  // ====================================================================
  // This is my laptop's IP address on the hotspot network
  // Must match the IP where your Apache/PHP server is running
  // Format: http://[MY_LAPTOP_IP]/[PROJECT_FOLDER]
  // Example: "http://192.168.43.50/applock_api"
  // ====================================================================
  static const String baseUrl = "http://10.30.193.50/applock_api";

  // ====================================================================
  // SECTION 1: PRIVACY-COMPLIANT MODE (Sensitive info stays local)
  // ====================================================================
  // These methods handle authentication data but DON'T send it to server
  // All sensitive data (PIN, pattern) is stored locally only for privacy
  // ====================================================================

  /// Saves user PIN locally (not sent to server for privacy)
  /// @param username: User identifier (currently hardcoded as "user1")
  /// @param pin: 4-digit PIN code
  /// @return: Always returns true (since storage is local)
  static Future<bool> savePin(String username, String pin) async {
    print("🔒 [Privacy] PIN not sent to server - stored locally only");
    return true; // Local storage handled by SecureStorageService
  }

  /// Retrieves user PIN from local storage (not from server)
  /// @param username: User identifier
  /// @return: PIN string or null if not found
  static Future<String?> getPin(String username) async {
    print("🔒 [Privacy] getPin is local-only");
    return null; // Actually fetched from SecureStorageService.getPin()
  }

  /// Saves unlock pattern locally (not sent to server)
  /// @param username: User identifier
  /// @param pattern: Pattern string (e.g., "0,3,6,7,8")
  /// @return: Always returns true
  static Future<bool> savePattern(String username, String pattern) async {
    print("🔒 [Privacy] Pattern not sent to server - stored locally only");
    return true;
  }

  /// Sets authentication method (PIN or pattern) locally
  /// @param username: User identifier
  /// @param method: Either "pin" or "pattern"
  /// @return: Always returns true
  static Future<bool> setAuthMethod(String username, String method) async {
    print("🔒 [Privacy] Auth method stored locally only");
    return true;
  }

  /// Gets current authentication method from local storage
  /// @param username: User identifier
  /// @return: "pin", "pattern", or null if not set
  static Future<String?> getAuthMethod(String username) async {
    print("🔒 [Privacy] Auth method fetched locally only");
    return null;
  }

  // ====================================================================
  // SECTION 2: LOCKED APPS MANAGEMENT (Non-sensitive sync)
  // ====================================================================
  // These methods handle manually locked apps - safe to sync with server
  // because app names aren't sensitive (public package names)
  // ====================================================================

  /// Adds a new app to the locked apps list
  /// Sends request to: /add_locked_app.php
  /// @param username: User identifier
  /// @param appName: Name or package name of app to lock (e.g., "com.instagram.android")
  /// @return: true if successful, false if failed
  static Future<bool> addLockedApp(String username, String appName) async {
    try {
      // Construct the full URL for the PHP endpoint
      final url = Uri.parse("$baseUrl/add_locked_app.php");

      // Prepare POST request body (must match PHP expected parameters)
      final Map<String, String> body = {
        "username": username,      // Required by PHP to identify user
        "app_name": appName,       // Display name of the app
        "package_name": appName,   // Actual package name (same as app_name here)
      };

      // Send POST request to PHP backend
      final response = await http.post(url, body: body);

      // Check if server responded successfully (HTTP 200 OK)
      if (response.statusCode == 200) {
        // Parse the JSON response from PHP
        final data = jsonDecode(response.body);
        // PHP returns {"success": true/false}
        return data["success"] == true;
      }
    } catch (e) {
      // Network errors, server down, or invalid response
      print("✗ addLockedApp error: $e");
    }
    return false; // Default to false if anything fails
  }

  /// Fetches all manually locked apps for a user
  /// Sends request to: /get_locked_apps.php?username=user1
  /// @param username: User identifier
  /// @return: List of locked apps as Maps, or empty list if failed
  static Future<List<Map<String, dynamic>>> getLockedApps(String username) async {
    try {
      // GET request with username as query parameter
      final url = Uri.parse("$baseUrl/get_locked_apps.php?username=$username");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // PHP returns {"success": true, "locked_apps": [...]}
        if (data["success"] == true && data["locked_apps"] is List) {
          // Convert JSON array to List<Map> for Dart
          return List<Map<String, dynamic>>.from(data["locked_apps"]);
        }
      }
    } catch (e) {
      print("✗ getLockedApps error: $e");
    }
    return []; // Return empty list on failure
  }

  /// Removes an app from the locked apps list
  /// Sends request to: /delete_locked_app.php
  /// @param id: Database ID of the locked app record
  /// @return: true if deleted successfully, false if failed
  static Future<bool> deleteLockedApp(int id) async {
    try {
      final url = Uri.parse("$baseUrl/delete_locked_app.php");
      // POST with the record ID to delete
      final response = await http.post(url, body: {"id": id.toString()});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("✗ deleteLockedApp error: $e");
    }
    return false;
  }

  // ====================================================================
  // SECTION 3: TIME LOCK MANAGEMENT
  // ====================================================================
  // Handles time-based locking rules (e.g., "lock Facebook 9AM-5PM")
  // ====================================================================

  /// Creates a new time-based lock rule
  /// Sends request to: /save_time_lock.php
  /// @param username: User identifier
  /// @param appName: App to apply time lock to
  /// @param start: Start time string (e.g., "09:00" or ISO format)
  /// @param end: End time string (e.g., "17:00" or ISO format)
  /// @return: true if saved successfully
  static Future<bool> saveTimeLock(
      String username, String appName, String start, String end) async {
    try {
      // Convert times to ISO format if they're not already
      final startFormatted = DateTime.tryParse(start)?.toIso8601String() ?? start;
      final endFormatted = DateTime.tryParse(end)?.toIso8601String() ?? end;
      
      print("🕐 Saving time lock for $appName → $startFormatted → $endFormatted");
      
      final url = Uri.parse("$baseUrl/save_time_lock.php");
      final response = await http.post(url, body: {
        "username": username,
        "app_name": appName,
        "start_time": startFormatted,
        "end_time": endFormatted,
      });

      // Debug output to see PHP response
      print("save_time_lock.php->${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("saveTimeLock error: $e");
    }
    return false;
  }

  /// Updates an existing time lock rule
  /// Sends request to: /update_time_lock.php
  /// @param id: Database ID of the time lock record
  /// @param username: User identifier
  /// @param appName: App name
  /// @param start: New start time
  /// @param end: New end time
  /// @return: true if updated successfully
  static Future<bool> updateTimeLock(
      int id, String username, String appName, String start, String end) async {
    try {
      final startFormatted = DateTime.tryParse(start)?.toIso8601String() ?? start;
      final endFormatted = DateTime.tryParse(end)?.toIso8601String() ?? end;
      
      final url = Uri.parse("$baseUrl/update_time_lock.php");
      final response = await http.post(url, body: {
        "id": id.toString(),
        "username": username,
        "app_name": appName,
        "start_time": startFormatted,
        "end_time": endFormatted,
      });
      
      print("update_time_lock.php->${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("updateTimeLock error: $e");
    }
    return false;
  }

  /// Fetches all time lock rules for a user
  /// Sends request to: /get_time_locks.php?username=user1
  /// @param username: User identifier
  /// @return: List of time lock rules, filtering out invalid "0000-00-00" entries
  static Future<List<Map<String, dynamic>>> getTimeLocks(String username) async {
    try {
      final url = Uri.parse("$baseUrl/get_time_locks.php?username=$username");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["time_locks"] is List) {
          // Filter out invalid/default database entries
          final validLocks = (data["time_locks"] as List).where((lock) {
            return lock["start_time"] != "0000-00-00 00:00:00" &&
                lock["end_time"] != "0000-00-00 00:00:00";
          }).toList();
          
          return List<Map<String, dynamic>>.from(validLocks);
        }
      }
    } catch (e) {
      print("getTimeLocks error: $e");
    }
    return [];
  }

  /// Deletes a time lock rule
  /// Sends request to: /delete_time_lock.php
  /// @param id: Database ID of time lock record
  /// @param username: User identifier (for validation)
  /// @return: true if deleted successfully
  static Future<bool> deleteTimeLock(int id, String username) async {
    try {
      final url = Uri.parse("$baseUrl/delete_time_lock.php");
      final response = await http.post(url, body: {
        "id": id.toString(),
        "username": username,
      });
      
      print("delete_time_lock.php → ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("✗ deleteTimeLock error: $e");
    }
    return false;
  }

  // ====================================================================
  // SECTION 4: LOCATION LOCK MANAGEMENT
  // ====================================================================
  // Handles location-based locking rules (e.g., "lock Instagram at school")
  // Uses latitude/longitude coordinates and 100m radius
  // ====================================================================

  /// Creates a new location-based lock rule
  /// Sends request to: /save_location_lock.php
  /// @param username: User identifier
  /// @param appName: Display name of app
  /// @param packageName: Actual package name (e.g., com.instagram.android)
  /// @param locationName: Human-readable name (e.g., "Home", "Office")
  /// @param latitude: GPS latitude coordinate
  /// @param longitude: GPS longitude coordinate
  /// @return: true if saved successfully
  static Future<bool> saveLocationLock(
      String username,
      String appName,
      String packageName,
      String locationName,
      double latitude,
      double longitude,
      ) async {
    try {
      // Debug output to see what's being sent
      print("📍 Attempting to save location lock:");
      print(" - Username: $username");
      print(" - App: $appName");
      print(" - Package: $packageName");
      print(" - Location: $locationName");
      print(" - Lat/Lng: $latitude, $longitude");

      final url = Uri.parse("$baseUrl/save_location_lock.php");
      final response = await http.post(
        url,
        body: {
          "username": username,
          "app_name": appName,
          "package_name": packageName,
          "location_name": locationName,
          "latitude": latitude.toString(),
          "longitude": longitude.toString(),
        },
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      // Debug the response
      print("Save Location Lock Response:");
      print(" - Status: ${response.statusCode}");
      print(" - Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("✗ saveLocationLock error: $e");
    }
    return false;
  }

  /// Updates an existing location lock rule
  /// Sends request to: /update_location_lock.php
  /// @param id: Database ID of location lock record
  /// @param username: User identifier
  /// @param appName: Display name of app
  /// @param packageName: Actual package name
  /// @param locationName: Human-readable location name
  /// @param latitude: New latitude coordinate
  /// @param longitude: New longitude coordinate
  /// @return: true if updated successfully
  static Future<bool> updateLocationLock(
      int id,
      String username,
      String appName,
      String packageName,
      String locationName,
      double latitude,
      double longitude,
      ) async {
    try {
      final url = Uri.parse("$baseUrl/update_location_lock.php");
      final response = await http.post(url, body: {
        "id": id.toString(),
        "username": username,
        "app_name": appName,
        "package_name": packageName,
        "location_name": locationName,
        "latitude": latitude.toString(),
        "longitude": longitude.toString(),
      });
      
      print("update_location_lock.php->${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("✗ updateLocationLock error: $e");
    }
    return false;
  }

  /// Fetches all location lock rules for a user
  /// Sends request to: /get_location_locks.php?username=user1
  /// IMPORTANT: This must include package_name field for proper app identification
  /// @param username: User identifier
  /// @return: List of location lock rules
  static Future<List<Map<String, dynamic>>> getLocationLocks(
      String username) async {
    try {
      final url = Uri.parse("$baseUrl/get_location_locks.php?username=$username");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["location_locks"] is List) {
          final locks = List<Map<String, dynamic>>.from(data["location_locks"]);
          
          // Debug: Print retrieved location locks
          print("✓ Retrieved ${locks.length} location locks");
          for (var lock in locks) {
            print(" - App: ${lock['app_name']}, Package: ${lock['package_name'] ?? 'missing'}, Location: ${lock['location_name']}");
          }
          
          return locks;
        }
      }
    } catch (e) {
      print("✗ getLocationLocks error: $e");
    }
    return [];
  }

  /// Deletes a location lock rule
  /// Sends request to: /delete_location_lock.php
  /// @param id: Database ID of location lock record
  /// @return: true if deleted successfully
  static Future<bool> deleteLocationLock(int id) async {
    try {
      final url = Uri.parse("$baseUrl/delete_location_lock.php");
      final response = await http.post(url, body: {"id": id.toString()});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("✗ deleteLocationLock error: $e");
    }
    return false;
  }

  // ====================================================================
  // SECTION 5: USER SETTINGS
  // ====================================================================
  // General user configuration and preferences
  // ====================================================================

  /// Fetches user settings from server
  /// Sends request to: /get_user_settings.php?username=user1
  /// @param username: User identifier
  /// @return: Map of user settings or null if failed
  static Future<Map<String, dynamic>?> getUserSettings(String username) async {
    try {
      final url = Uri.parse("$baseUrl/get_user_settings.php?username=$username");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data;
      }
    } catch (e) {
      print("✗ getUserSettings error: $e");
    }
    return null;
  }

  // ====================================================================
  // SECTION 6: UNLOCK ATTEMPT LOGS (local-only)
  // ====================================================================
  // These logs are stored locally only for privacy reasons
  // Never sent to server - avoids tracking user behavior
  // ====================================================================

  /// Gets the most recent unlock attempt from local storage
  /// @param username: User identifier (unused in local storage)
  /// @return: Last unlock log entry or null if none exist
  static Future<Map<String, dynamic>?> getLastUnlockAttempt(String username) async {
    try {
      print("🔒 [Privacy] Fetching last unlock attempt from local storage");
      // Get all logs from secure local storage
      final logs = await SecureStorageService.getUnlockLogs();
      if (logs.isNotEmpty) {
        return logs.last; // Most recent log is last in list
      }
      return null;
    } catch (e) {
      print("✗ getLastUnlockAttempt error: $e");
      return null;
    }
  }

  /// Gets all unlock attempt logs from local storage
  /// @param username: User identifier (unused)
  /// @return: List of all unlock logs, empty list if none
  static Future<List<Map<String, dynamic>>> getUnlockLogs(String username) async {
    try {
      print("🔒 [Privacy] getUnlockLogs called - fetching from local storage");
      return await SecureStorageService.getUnlockLogs();
    } catch (e) {
      print("getUnlockLogs error: $e");
      return [];
    }
  }

  // ====================================================================
  // SECTION 7: LOCK STATUS CHECK
  // ====================================================================
  // Determines if an app should be locked RIGHT NOW based on:
  // 1. Time locks (is current time within locked period?)
  // 2. Location locks (are we within 100m of locked location?)
  // ====================================================================

  /// Checks if an app should be locked at this moment
  /// Combines time-based AND location-based lock checks
  /// @param username: User identifier
  /// @param appName: App to check
  /// @return: true if app should be locked right now
  static Future<bool> isAppCurrentlyLocked(String username, String appName) async {
    try {
      // Get all active lock rules
      final timeLocks = await getTimeLocks(username);
      final locationLocks = await getLocationLocks(username);
      final now = DateTime.now();

      bool timeLocked = false;
      bool locationLocked = false;

      // ===== CHECK TIME LOCKS =====
      for (final lock in timeLocks) {
        if (lock["app_name"] == appName) {
          try {
            // Parse start and end times from database
            final start = DateTime.parse(lock["start_time"]);
            final end = DateTime.parse(lock["end_time"]);
            
            // Check if current time is within locked period
            if (now.isAfter(start) && now.isBefore(end)) {
              timeLocked = true;
              break; // No need to check other time locks for this app
            }
          } catch (_) {
            // Skip if date parsing fails (corrupted data)
          }
        }
      }

      // ===== CHECK LOCATION LOCKS =====
      Position? current;
      try {
        // Get current GPS location (requires location permission)
        current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {
        // Location unavailable (GPS off, permission denied, etc.)
      }

      if (current != null) {
        for (final lock in locationLocks) {
          // Check by both app_name and package_name to ensure all apps are covered
          if ((lock["app_name"] == appName) || (lock["package_name"] == appName)) {
            // Parse coordinates from database
            final lat = double.tryParse(lock["latitude"].toString()) ?? 0.0;
            final lon = double.tryParse(lock["longitude"].toString()) ?? 0.0;
            
            // Calculate distance between current location and lock location
            final distance = Geolocator.distanceBetween(
              current.latitude,
              current.longitude,
              lat,
              lon,
            );
            
            // Lock if within 100 meters (0.1km) of locked location
            if (distance <= 100) {
              locationLocked = true;
              break; // No need to check other location locks
            }
          }
        }
      }

      // App is locked if EITHER time OR location condition is met
      return timeLocked || locationLocked;
    } catch (e) {
      print("✗ isAppCurrentlyLocked error: $e");
      return false; // Default to not locked on error
    }
  }

  /// Removes a manually locked app (not time/location based)
  /// @param username: User identifier
  /// @param appName: App to remove from manual locks
  /// @return: true if removed successfully
  static Future<bool> removeAppLock(String username, String appName) async {
    try {
      // Get all manually locked apps
      final lockedApps = await getLockedApps(username);
      
      // Find the app by name and get its database ID
      for (final app in lockedApps) {
        if (app["app_name"] == appName && app["id"] != null) {
          // Delete using the database ID
          return await deleteLockedApp(app["id"]);
        }
      }
    } catch (e) {
      print("removeAppLock error: $e");
    }
    return false;
  }
}