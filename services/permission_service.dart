// Import required Flutter and plugin packages
import 'package:flutter/material.dart'; // For UI components, BuildContext, and debugPrint
import 'package:permission_handler/permission_handler.dart'; // For handling runtime permissions
import 'package:app_usage/app_usage.dart'; // For checking app usage access permission
import 'package:android_intent_plus/android_intent.dart'; // For launching Android system settings

/// PermissionService class handles all runtime permission checks and user guidance
/// This service manages location, notification, and usage access permissions for AppLock+
class PermissionService {
  /// Main method to check and request all necessary permissions in sequence
  /// This should be called during app initialization or when permissions are needed
  static Future<void> requestAllPermissions(BuildContext context) async {
    // Request location permission first (important for location-based locks)
    await _checkLocationPermission(context);
    // Request notification permission for app alerts
    await _checkNotificationPermission(context);
    // Request usage access permission for app monitoring
    await _checkUsageAccessPermission(context);
  }

  /// Checks and requests location permission if not already granted
  /// Location permission is required for location-based app locking features
  static Future<void> _checkLocationPermission(BuildContext context) async {
    // Check if location permission is currently denied
    if (await Permission.location.isDenied) {
      // Request location permission from the user
      final result = await Permission.location.request();
      
      // If permission is denied after request, show explanation dialog
      if (result.isDenied) {
        _showAlert(
          context,
          "Location Access Required", // Dialog title
          "Location permission is required for location-based app locks.", // Explanation
        );
      }
    }
  }

  /// Checks and requests notification permission if not already granted
  /// Notification permission is required for lock/unlock alerts
  static Future<void> _checkNotificationPermission(BuildContext context) async {
    // Check if notification permission is currently denied
    if (await Permission.notification.isDenied) {
      // Request notification permission from the user
      final result = await Permission.notification.request();
      
      // If permission is denied after request, show explanation dialog
      if (result.isDenied) {
        _showAlert(
          context,
          "Notification Permission Needed", // Dialog title
          "Notifications are required to alert you when apps are locked or unlocked.", // Explanation
        );
      }
    }
  }

  /// Checks and requests usage access permission (special system permission)
  /// Usage access is required to monitor which apps are being opened by the user
  static Future<void> _checkUsageAccessPermission(BuildContext context) async {
    // Check if usage access is currently granted using custom method
    bool granted = await _isUsageAccessGranted();

    // If not granted, show detailed explanation with option to open system settings
    if (!granted) {
      _showAlert(
        context,
        "Usage Access Needed", // Dialog title
        "AppLock+ needs usage access to monitor which apps are opened.\n\nTap 'Grant Access' to open system settings.", // Detailed explanation
        actionLabel: "Grant Access", // Custom button label
        onAction: () {
          // Create Android intent to open usage access settings
          const intent = AndroidIntent(
            action: 'android.settings.USAGE_ACCESS_SETTINGS', // Android system action
          );
          intent.launch(); // Launch the system settings screen
        },
      );
    }
  }

  /// Helper method to check if Usage Access permission is currently granted
  /// This method tests the permission by attempting to retrieve app usage data
  static Future<bool> _isUsageAccessGranted() async {
    try {
      // Create AppUsage instance to check permission
      final appUsage = AppUsage();
      
      // Try to get app usage data for the last minute
      // If this succeeds, usage access is granted
      final usage = await appUsage.getAppUsage(
        DateTime.now().subtract(const Duration(minutes: 1)), // Start time (1 minute ago)
        DateTime.now(), // End time (now)
      );
      
      // Return true if usage data was retrieved (non-empty list indicates permission)
      return usage.isNotEmpty;
    } catch (e) {
      // Log any errors during the check and assume permission is not granted
      debugPrint("⚠️ Usage Access check failed: $e");
      return false; // Default to false on error
    }
  }

  /// Helper method to show permission explanation dialogs to the user
  /// Uses a consistent style with the app's theme colors
  static void _showAlert(
    BuildContext context, // BuildContext for showing dialogs
    String title, // Dialog title text
    String msg, // Dialog message/explanation text
    {
      String? actionLabel, // Optional custom action button label
      VoidCallback? onAction, // Optional callback for action button
    }
  ) {
    // Display an AlertDialog with the provided content
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Set background color matching app theme
        backgroundColor: const Color(0xFFF9E9D2),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF553F2B), // Dark brown text color
          ),
        ),
        content: Text(
          msg,
          style: const TextStyle(color: Color(0xFF553F2B)), // Dark brown text color
        ),
        actions: [
          // Show custom action button if provided (e.g., "Grant Access")
          if (actionLabel != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                if (onAction != null) onAction(); // Execute the provided action
              },
              child: Text(
                actionLabel,
                style: const TextStyle(color: Color(0xFF936B46)), // Medium brown text color
              ),
            ),
          // Always show OK button to dismiss the dialog
          TextButton(
            onPressed: () => Navigator.pop(context), // Close the dialog
            child: const Text(
              "OK",
              style: TextStyle(color: Color(0xFF553F2B)), // Dark brown text color
            ),
          ),
        ],
      ),
    );
  }
}