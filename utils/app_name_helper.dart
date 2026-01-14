// Import required packages for accessing installed apps and secure storage
import 'package:device_apps/device_apps.dart'; // For getting app information from the device
import '../services/secure_storage_service.dart'; // For saving and retrieving app name mappings

/// AppNameHelper class provides utilities for converting app package names to human-readable display names
/// This class handles multiple fallback strategies to ensure apps are displayed with user-friendly names
class AppNameHelper {
  /// Get the display name for an app identifier (either package name or already a display name)
  /// This method tries multiple strategies in order:
  /// 1. Returns the identifier as-is if it's already a display name
  /// 2. Looks up the app in installed apps using DeviceApps
  /// 3. Checks saved mappings in secure storage
  /// 4. Falls back to formatting the package name to look nicer
  static Future<String> getDisplayName(String identifier) async {
    // First, check if the identifier is already a display name (not a package name)
    // This avoids unnecessary lookups for names that are already readable
    if (!_isPackageName(identifier)) {
      return identifier; // Return the identifier as-is since it's already a display name
    }
    
    // Strategy 1: Try to get the app from installed apps on the device
    // This provides the most accurate and up-to-date app name
    try {
      // Use DeviceApps to get app information by package name (identifier)
      final Application? app = await DeviceApps.getApp(identifier);
      
      // If the app is found on the device, use its actual name
      if (app != null) {
        // Save the mapping to secure storage for future offline use
        await SecureStorageService.saveAppNameMapping(identifier, app.appName);
        return app.appName; // Return the actual app name from the device
      }
    } catch (e) {
      // Log any errors but don't fail - continue to other strategies
      print("Error getting app from device: $e");
    }
    
    // Strategy 2: Try to get from saved mappings in secure storage
    // This is useful when the app is not currently installed or device lookup failed
    final savedName = await SecureStorageService.getAppName(identifier);
    if (savedName != null) {
      return savedName; // Return the previously saved app name
    }
    
    // Strategy 3: Fallback - format the package name to look nicer
    // This provides a readable name even when no other information is available
    return _formatPackageName(identifier);
  }
  
  /// Determine if a given string is likely a package name (not a display name)
  /// Package names typically follow reverse domain notation (com.example.app)
  static bool _isPackageName(String name) {
    // Check multiple patterns that indicate a package name:
    // 1. Contains a dot (.)
    // 2. Starts with common domain prefixes (com., org., net.)
    // 3. Matches the pattern of lowercase letters, dot, lowercase letters
    return name.contains('.') && 
           (name.startsWith('com.') || 
            name.startsWith('org.') || 
            name.startsWith('net.') ||
            RegExp(r'^[a-z]+\.[a-z]').hasMatch(name)); // Regex for pattern like "example.app"
  }
  
  /// Format a package name to look more like a display name
  /// Extracts the last part of the package and capitalizes the first letter
  /// Example: "com.example.myapp" -> "Myapp"
  static String _formatPackageName(String packageName) {
    // Split the package name by dots to get individual components
    final parts = packageName.split('.');
    
    // Check if there are at least 2 parts (domain and app name)
    if (parts.length > 1) {
      // Get the last part which is typically the app name
      final lastPart = parts.last;
      
      // Ensure the last part is not empty
      if (lastPart.isNotEmpty) {
        // Capitalize the first letter and keep the rest as-is
        return lastPart[0].toUpperCase() + lastPart.substring(1);
      }
    }
    
    // If we can't extract a meaningful name, return the original package name
    return packageName;
  }
}