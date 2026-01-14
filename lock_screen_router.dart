// Import required Flutter packages and application screens
import 'package:flutter/material.dart'; // For Flutter UI components, BuildContext, and navigation
import '../services/secure_storage_service.dart'; // Service for secure storage of authentication preferences
import 'passcode_screen.dart'; // Screen for PIN code authentication
import 'pattern_screen.dart'; // Screen for pattern authentication

/// 🧭 LockScreenRouter
/// A helper class that decides whether to show the PIN or Pattern screen.
/// Acts as a router/facade that abstracts authentication method selection logic.
/// Returns `true` if authentication succeeds, `false` otherwise.
class LockScreenRouter {
  /// Opens the correct authentication screen based on user's stored preference.
  /// 
  /// This method:
  /// 1. Retrieves the user's last selected authentication method from secure storage
  /// 2. Determines whether to show PIN or Pattern screen
  /// 3. Navigates to the appropriate screen and waits for authentication result
  /// 
  /// @param context - BuildContext required for navigation operations
  /// @param appName - Optional name of the app being unlocked (for display purposes only)
  /// @return Future<bool> - Returns `true` if authentication was successful, `false` otherwise
  static Future<bool> openAuthScreen(
    BuildContext context, {
    String? appName, // Optional parameter to show which app is being unlocked
  }) async {
    // 🔍 STEP 1: Get last selected authentication method from secure storage
    // This reads the user's preference saved during setup or previous authentication
    final method = await SecureStorageService.getAuthMethod();

    Widget screen; // Variable to hold the screen widget to be displayed

    // 🔍 STEP 2: Determine which authentication screen to show based on stored method
    if (method == "pattern") {
      // User previously selected pattern authentication
      screen = PatternScreen(
        isSetupMode: false, // False indicates this is for authentication, not setup
        appName: appName, // Pass app name for display in the pattern screen
      );
    } else {
      // Default to PIN authentication if:
      // - No method is stored (first time use)
      // - User previously selected PIN
      // - Any other value is stored (fallback)
      screen = PasscodeScreen(
        isSetupMode: false, // False indicates this is for authentication, not setup
        appName: appName, // Pass app name for display in the PIN screen
        key: UniqueKey(), // Unique key ensures widget state is fresh for each authentication attempt
      );
    }

    // ✅ STEP 3: Navigate to chosen authentication screen and wait for result
    // Uses MaterialPageRoute for standard page transition
    // The result is a boolean indicating authentication success/failure
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen), // Create route to the determined screen
    );

    // STEP 4: Return the authentication result
    // Returns true if authentication succeeded, false otherwise
    return result == true;
  }
}