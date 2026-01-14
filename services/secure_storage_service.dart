// Import required packages for secure storage and JSON encoding/decoding
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For secure, encrypted storage
import 'dart:convert'; // For JSON encoding and decoding operations

/// SecureStorageService - Handles all local-only sensitive data for AppLock+
/// 
/// This service provides encrypted storage for sensitive user data including:
/// - Authentication credentials (PIN, Pattern)
/// - App preferences and settings
/// - Time and location lock configurations
/// - App name mappings
/// - Audit logs and GPS data
/// 
/// Uses AES encryption internally with hardware-backed security on Android/iOS.
/// All data is stored locally on device and never transmitted to servers.
class SecureStorageService {
  // Create a single instance of FlutterSecureStorage for the entire app
  static final _storage = const FlutterSecureStorage();

  // =========================================================
  // 🔐 AUTHENTICATION SETTINGS — Local Only
  // =========================================================

  /// Save the currently selected authentication method (PIN or Pattern)
  /// This determines which authentication screen to show to the user
  static Future<void> saveAuthMethod(String method) async {
    await _storage.write(key: 'auth_method', value: method);
  }

  /// Retrieve the currently selected authentication method
  /// Returns 'pin' or 'pattern' based on user selection
  static Future<String?> getAuthMethod() async {
    return await _storage.read(key: 'auth_method');
  }

  /// Securely store user PIN with AES encryption
  /// PIN is stored as plain string but encrypted at rest by FlutterSecureStorage
  static Future<void> savePin(String pin) async {
    await _storage.write(key: 'user_pin', value: pin);
  }

  /// Retrieve the user's PIN from secure storage
  /// Returns null if no PIN has been set
  static Future<String?> getPin() async {
    return await _storage.read(key: 'user_pin');
  }

  /// Securely store user pattern with AES encryption
  /// Pattern is stored as a sequence of numbers (e.g., "1-2-3-4")
  static Future<void> savePattern(String pattern) async {
    await _storage.write(key: 'user_pattern', value: pattern);
  }

  /// Retrieve the user's pattern from secure storage
  /// Returns null if no pattern has been set
  static Future<String?> getPattern() async {
    return await _storage.read(key: 'user_pattern');
  }

  // =========================================================
  // ⚙️ APP PREFERENCES — Safe for Sync or Local Use
  // =========================================================

  /// Save notification preference (enabled/disabled)
  /// Stored as a string 'true' or 'false' for simplicity
  static Future<void> setNotificationsEnabled(bool value) async {
    await _storage.write(
      key: 'notifications_enabled',
      value: value.toString(),
    );
  }

  /// Check if notifications are enabled
  /// REQUIRED BY TIMELOCKS CONTROLLER
  /// Returns true if notifications are enabled, false otherwise
  static Future<bool> isNotificationsEnabled() async {
    final value = await _storage.read(key: 'notifications_enabled');
    return value == 'true'; // Compare string value to 'true'
  }

  // =========================================================
  // ⏰ TIME LOCKS — Local Cache for Offline Access
  // =========================================================

  /// Save time lock configurations as JSON string
  /// This acts as a local cache for offline access to time-based locks
  static Future<void> saveTimeLocks(String jsonData) async {
    await _storage.write(key: 'time_locks', value: jsonData);
  }

  /// Retrieve time lock configurations from local cache
  /// Returns JSON string or null if no time locks are configured
  static Future<String?> getTimeLocks() async {
    return await _storage.read(key: 'time_locks');
  }

  // =========================================================
  // 📍 LOCATION LOCKS — Store Only Safe GPS Coordinates
  // =========================================================

  /// Save location lock configurations as JSON string
  /// Stores GPS coordinates and associated app restrictions
  static Future<void> saveLocationLocks(String jsonData) async {
    await _storage.write(key: 'location_locks', value: jsonData);
  }

  /// Retrieve location lock configurations from local cache
  /// Returns JSON string or null if no location locks are configured
  static Future<String?> getLocationLocks() async {
    return await _storage.read(key: 'location_locks');
  }

  /// Add a new location lock dynamically to existing configurations
  /// Merges new lock with existing locks and saves updated list
  static Future<void> addLocationLock(Map<String, dynamic> newLock) async {
    // Get existing location locks if any
    final existingData = await getLocationLocks();
    List<dynamic> locks = [];

    // Parse existing locks or start with empty list
    if (existingData != null) {
      locks = jsonDecode(existingData);
    }

    // Add new lock to the list
    locks.add(newLock);
    
    // Save updated list back to secure storage
    await saveLocationLocks(jsonEncode(locks));
  }

  // =========================================================
  // 🆕 APP NAME MAPPING — Store readable names for package names
  // =========================================================

  /// Save mapping between Android package name and human-readable app name
  /// This improves user experience by showing app names instead of package names
  static Future<void> saveAppNameMapping(String packageName, String appName) async {
    // Get existing mappings if any
    final existingData = await _storage.read(key: 'app_name_mappings');
    Map<String, dynamic> mappings = {};

    // Parse existing mappings or start with empty map
    if (existingData != null) {
      mappings = Map<String, dynamic>.from(jsonDecode(existingData));
    }

    // Add or update mapping for this package name
    mappings[packageName] = appName;
    
    // Save updated mappings back to secure storage
    await _storage.write(key: 'app_name_mappings', value: jsonEncode(mappings));
  }

  /// Retrieve human-readable app name for a given package name
  /// Returns null if no mapping exists for the package
  static Future<String?> getAppName(String packageName) async {
    final existingData = await _storage.read(key: 'app_name_mappings');
    if (existingData == null) return null;

    // Parse mappings and return specific app name
    final mappings = Map<String, dynamic>.from(jsonDecode(existingData));
    return mappings[packageName] as String?;
  }

  /// Retrieve all app name mappings as a map
  /// Useful for displaying all known apps with their readable names
  static Future<Map<String, String>> getAllAppNameMappings() async {
    final existingData = await _storage.read(key: 'app_name_mappings');
    if (existingData == null) return {};

    // Parse mappings and convert to Map<String, String>
    final mappings = Map<String, dynamic>.from(jsonDecode(existingData));
    return mappings.map((key, value) => MapEntry(key, value.toString()));
  }

  // =========================================================
  // 🧾 UNLOCK LOGS — Local Audit Trail (for Privacy)
  // =========================================================

  /// Save an unlock event log for audit trail
  /// Records when and which apps were unlocked (for user review)
  static Future<void> saveUnlockLog(Map<String, dynamic> log) async {
    // Get existing logs if any
    final existing = await _storage.read(key: 'unlock_logs');
    List<dynamic> logs = existing != null ? jsonDecode(existing) : [];

    // Add new log entry
    logs.add(log);
    
    // Save updated logs back to secure storage
    await _storage.write(key: 'unlock_logs', value: jsonEncode(logs));
  }

  /// Retrieve all unlock logs for user review
  /// Returns list of log entries as maps
  static Future<List<Map<String, dynamic>>> getUnlockLogs() async {
    final existing = await _storage.read(key: 'unlock_logs');
    if (existing == null) return [];

    // Parse logs and convert to List<Map<String, dynamic>>
    final List<dynamic> logs = jsonDecode(existing);
    return logs.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Clear all unlock logs (privacy feature)
  /// Allows users to delete their audit trail
  static Future<void> clearUnlockLogs() async {
    await _storage.delete(key: 'unlock_logs');
  }

  // =========================================================
  // 🌍 GPS DATA — Local Cache
  // =========================================================

  /// Save the last known GPS location for faster location-based locking
  /// Caches latitude and longitude for offline reference
  static Future<void> saveLastKnownLocation(double lat, double lon) async {
    await _storage.write(
      key: 'last_location',
      value: jsonEncode({
        'latitude': lat,
        'longitude': lon,
      }),
    );
  }

  /// Retrieve the last known GPS location from cache
  /// Returns map with 'latitude' and 'longitude' keys, or null if not available
  static Future<Map<String, double>?> getLastKnownLocation() async {
    final value = await _storage.read(key: 'last_location');
    if (value == null) return null;

    // Parse location data and ensure proper numeric types
    final data = jsonDecode(value);
    return {
      'latitude': (data['latitude'] as num).toDouble(),
      'longitude': (data['longitude'] as num).toDouble(),
    };
  }

  // =========================================================
  // 🧹 RESET / WIPE ALL DATA
  // =========================================================

  /// Clear all data from secure storage
  /// Used for account logout, app reset, or privacy compliance
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}