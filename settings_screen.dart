// Import required Flutter packages and third-party libraries for file operations, sharing, and platform-specific features
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'dart:io'; // For file operations (reading/writing files)
import 'dart:convert'; // For JSON encoding and decoding
import 'package:path_provider/path_provider.dart'; // For accessing device directories
import 'package:share_plus/share_plus.dart'; // For sharing files with other apps
import 'package:file_picker/file_picker.dart'; // For picking files from device storage
import 'package:device_apps/device_apps.dart'; // NEW IMPORT: For accessing installed app information
import 'package:shared_preferences/shared_preferences.dart'; // ADDED IMPORT: For simple local storage

// Import internal application screens and components
import 'profile/profile_avatar_screen.dart'; // Screen for customizing avatar profile
import 'permissions/permissions_setup_screen.dart'; // Screen for managing app permissions
import 'services/api_service.dart'; // Service for API communication with backend
import 'services/secure_storage_service.dart'; // Secure Local Storage service for encrypted data
import 'pattern_screen.dart'; // Screen for pattern authentication
import 'passcode_screen.dart'; // Screen for PIN authentication

// Import time lock management screens with aliases to avoid naming conflicts
import 'time_lock_config_screen.dart' as time_config;
import 'time_locks_list_screen.dart' as time_list;

// Import location lock management screens with aliases to avoid naming conflicts
import 'location_lock_config_screen.dart' as location_config;
import 'location_locks_list_screen.dart' as location_list;

/// SettingsScreen - Main settings screen for AppLock+ application
/// Provides access to all application settings, preferences, and management functions
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State class for SettingsScreen
/// Manages settings state, user preferences, and data import/export functionality
class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false; // Tracks notification preference state
  Map<String, dynamic>? _lastUnlock; // Stores last unlock attempt data
  bool _loadingUnlock = true; // Flag for loading state of unlock data
  final String username = "user1"; // Username constant - TODO: make dynamic with login system

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Load user preferences when screen initializes
    _loadLastUnlockAttempt(); // Load last unlock attempt data
  }

  /// Load local preferences from secure storage
  Future<void> _loadPreferences() async {
    final enabled = await SecureStorageService.isNotificationsEnabled(); // Get notification preference
    setState(() => _notificationsEnabled = enabled); // Update state with loaded preference
  }

  // ★★★★ UPDATED UNLOCK LOG LOADING (WITH PACKAGE → APP NAME FIX)
  /// Loads the last unlock attempt from API with package name to app name conversion
  /// Resolves Android package names to human-readable app names using DeviceApps
  Future<void> _loadLastUnlockAttempt() async {
    setState(() => _loadingUnlock = true); // Set loading state
    try {
      // Fetch last unlock attempt from API
      Map<String, dynamic>? log =
          await ApiService.getLastUnlockAttempt(username);

      // If log exists and has app_name, try to resolve package name to readable name
      if (log != null && log['app_name'] != null) {
        String displayName = log['app_name']; // Initial display name
        String packageName = log['package_name'] ?? log['app_name']; // Get package name

        // Check if the app_name is actually a package name (contains dots)
        if (_isPackageName(displayName)) {
          try {
            // 1️⃣ Try to get app info from installed apps using DeviceApps
            final Application? app = await DeviceApps.getApp(packageName);

            if (app != null) {
              // Found app - use actual app name
              displayName = app.appName;
              log['app_name'] = displayName; // Update log with readable name

              // Save mapping for future use to avoid repeated lookups
              await SecureStorageService.saveAppNameMapping(
                  packageName, displayName);
            } else {
              // 2️⃣ If app not found in DeviceApps, try previously saved mapping
              final saved =
                  await SecureStorageService.getAppName(packageName);

              if (saved != null) {
                displayName = saved;
                log['app_name'] = saved; // Update log with saved name
              }
            }
          } catch (e) {
            print("Error resolving app name: $e");
          }
        }
      }

      // Update state with loaded (and potentially resolved) log
      setState(() {
        _lastUnlock = log;
        _loadingUnlock = false;
      });

      print("✔ Last unlock attempt loaded: "
          "${log != null ? 'Found ${log['app_name']}' : 'None'}");
    } catch (e) {
      print("✗ Error loading last unlock attempt: $e");
      setState(() {
        _lastUnlock = null; // Clear on error
        _loadingUnlock = false; // Reset loading state
      });
    }
  }

  // ✖ Helper to detect package names (Android package naming convention)
  bool _isPackageName(String name) {
    return name.contains('.') && // Must contain a dot
        (name.startsWith('com.') || // Common Android package prefixes
            name.startsWith('org.') ||
            name.startsWith('net.') ||
            RegExp(r'^[a-z]+\.[a-z]').hasMatch(name)); // Regex for pattern like "example.app"
  }

  /// Update notification preference in secure storage
  Future<void> _updateNotifications(bool enabled) async {
    await SecureStorageService.setNotificationsEnabled(enabled); // Save preference
    setState(() => _notificationsEnabled = enabled); // Update local state

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? "Notifications enabled" : "Disabled")));
  }

  /// Export application settings to a JSON file and share it
  Future<void> _exportSettings() async {
    try {
      // Gather all settings data from various sources
      final notificationsEnabled =
          await SecureStorageService.isNotificationsEnabled();

      final timeLocks = await ApiService.getTimeLocks(username);
      final locationLocks = await ApiService.getLocationLocks(username);

      // Structure data for export
      final exportData = {
        "notifications_enabled": notificationsEnabled,
        "time_locks": timeLocks,
        "location_locks": locationLocks,
      };

      // Convert to pretty-printed JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // Get temporary directory and create file
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/applock_settings.json");
      await file.writeAsString(jsonString);

      // Share the file using device's sharing capabilities
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "📌 AppLock+ Exported Settings",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✗ Failed to export settings: $e")));
    }
  }

  // Import settings from a JSON file
  Future<void> _importSettings() async {
    try {
      // Open file picker to select JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return; // User cancelled
      
      // Read and parse selected file
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content);

      // Import notification preference
      final notificationsEnabled = data["notifications_enabled"] ?? false;
      await SecureStorageService.setNotificationsEnabled(notificationsEnabled);

      // Sync time locks from imported data
      if (data["time_locks"] is List) {
        for (final lock in data["time_locks"]) {
          await ApiService.saveTimeLock(
            username,
            lock["app_name"],
            lock["start_time"],
            lock["end_time"],
          );
        }
      }

      // Sync location locks from imported data (with type safety)
      if (data["location_locks"] is List) {
        for (final lock in data["location_locks"]) {
          // Safely parse latitude with fallbacks
          final latitude = lock["latitude"] is double
              ? lock["latitude"]
              : double.tryParse(lock["latitude"].toString()) ?? 0.0;

          // Safely parse longitude with fallbacks
          final longitude = lock["longitude"] is double
              ? lock["longitude"]
              : double.tryParse(lock["longitude"].toString()) ?? 0.0;

          await ApiService.saveLocationLock(
            username,
            lock["app_name"] ?? "Unknown App", // App name with fallback
            lock["package_name"] ?? lock["app_name"] ?? "unknown.package", // Package name with fallbacks
            lock["location_name"] ?? "Unknown Location", // Location name with fallback
            latitude,
            longitude,
          );
        }
      }

      // Update local state with imported notification preference
      setState(() => _notificationsEnabled = notificationsEnabled);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Settings imported successfully")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to import: $e")));
    }
  }

  /// Reset settings - UPDATED FUNCTION
  /// Shows confirmation dialog before resetting all settings
  Future<void> _confirmAndReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF9E9D2), // Light beige background
        title: const Text("Reset All Settings",
            style: TextStyle(color: Color(0xFF553F2B))), // Dark brown text
        content: const Text(
          "This will delete ALL your data including:\n\n• All locked apps\n• All time-based locks\n• All location-based locks\n• Your PIN/Pattern\n• App preferences\n• Unlock history\n\nThis action cannot be undone!",
          style: TextStyle(color: Color(0xFF553F2B)),
        ),
        actions: [
          // Cancel button
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF936B46))), // Gold text
            onPressed: () => Navigator.pop(context, false),
          ),
          // Reset confirmation button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF936B46), // Gold background
                foregroundColor: Colors.white), // White text
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset Everything"),
          ),
        ],
      ),
    );

    // If user confirmed, proceed with reset
    if (confirm == true) {
      await _resetToDefault();
    }
  }

  /// ★★★★ COMPLETELY UPDATED RESET FUNCTION - RESETS EVERYTHING
  /// Comprehensive reset that clears all data from API, secure storage, and local cache
  Future<void> _resetToDefault() async {
    try {
      // Show loading indicator during reset process
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing during reset
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFFF9E9D2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF936B46)), // Gold spinner
              SizedBox(height: 16),
              Text("Resetting everything...",
                  style: TextStyle(color: Color(0xFF553F2B))),
            ],
          ),
        ),
      );

      // 1. Clear all secure storage first (PIN, pattern, preferences, etc.)
      await SecureStorageService.clearAll();
      print("✔ Secure storage cleared");

      // 2. Delete all time locks from backend
      try {
        final timeLocks = await ApiService.getTimeLocks(username);
        print("Found ${timeLocks.length} time locks to delete");
        
        for (final lock in timeLocks) {
          if (lock["id"] != null) {
            await ApiService.deleteTimeLock(lock["id"], username);
            print("✔ Deleted time lock: ${lock["app_name"]}");
          }
        }
      } catch (e) {
        print("✗ Error deleting time locks: $e");
      }

      // 3. Delete all location locks from backend
      try {
        final locationLocks = await ApiService.getLocationLocks(username);
        print("Found ${locationLocks.length} location locks to delete");
        
        for (final lock in locationLocks) {
          if (lock["id"] != null) {
            await ApiService.deleteLocationLock(lock["id"]);
            print("✔ Deleted location lock: ${lock["app_name"]}");
          }
        }
      } catch (e) {
        print("✗ Error deleting location locks: $e");
      }

      // 4. Delete all manually locked apps from backend
      try {
        final lockedApps = await ApiService.getLockedApps(username);
        print("Found ${lockedApps.length} locked apps to delete");
        
        for (final app in lockedApps) {
          if (app["id"] != null) {
            await ApiService.deleteLockedApp(app["id"]);
            print("✔ Deleted locked app: ${app["app_name"]}");
          }
        }
      } catch (e) {
        print("✗ Error deleting locked apps: $e");
      }

      // 5. Clear SharedPreferences for cached data (non-sensitive storage)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('locked_apps');
        await prefs.remove('time_locks');
        await prefs.remove('location_locks');
        await prefs.remove('first_launch_done'); // Reset first launch flag
        print("✔ SharedPreferences cleared");
      } catch (e) {
        print("✗ Error clearing SharedPreferences: $e");
      }

      // 6. Reset local state variables
      setState(() {
        _notificationsEnabled = false;
        _lastUnlock = null;
      });

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Everything has been reset to default!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Reload the screen to reflect changes
      _loadPreferences();
      _loadLastUnlockAttempt();

    } catch (e) {
      // Close loading dialog on error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Reset failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
      print("✗ Reset failed completely: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define consistent text style for list items
    const itemTextStyle = TextStyle(
        fontSize: 20, color: Color(0xFF553F2B), fontWeight: FontWeight.w500);

    // Main scaffold for settings screen
    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2), // Light beige background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9E9D2), // Match background
        elevation: 0, // Remove shadow for flat design
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF936B46)), // Gold back arrow
          onPressed: () => Navigator.pop(context), // Navigate back
        ),
        title: const Text("Settings",
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF553F2B))), // Dark brown bold title
        actions: [
          // Refresh button for last unlock attempt
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF936B46)), // Gold refresh icon
            onPressed: _loadLastUnlockAttempt,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ❶ Last Unlock Attempt Card
          Card(
            color: const Color(0xFFFFF3E6), // Light orange/tan background
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loadingUnlock
                  ? const Center(child: CircularProgressIndicator()) // Loading state
                  : _lastUnlock != null
                      ? Column( // Display last unlock attempt details
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Last Unlock Attempt",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF553F2B))),
                            const SizedBox(height: 8),
                            Text("📱 App: ${_lastUnlock!['app_name'] ?? ' - '}",
                                style: itemTextStyle),
                            Text(
                                "🔓 Method: ${_lastUnlock!['unlock_method'] ?? '-'}",
                                style: itemTextStyle),
                            Text("⏰ Time: ${_lastUnlock!['timestamp'] ?? ' - '}",
                                style: itemTextStyle),
                          ],
                        )
                      : const Text("No unlock attempts recorded.", // Empty state
                          style: itemTextStyle),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF936B46)), // Gold divider

          // App Permissions Card
          Card(
            color: const Color(0xFFFFF3E6),
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("App Permissions",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF553F2B))),
                  const SizedBox(height: 10),
                  const Text(
                    "Manage Accessibility, Location, and Notification permissions.",
                    style: TextStyle(fontSize: 16, color: Color(0xFF553F2B)),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.manage_accounts, color: Colors.white),
                      label: const Text("Manage App Permissions",
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF936B46)), // Gold button
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PermissionsSetupScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF936B46)),

          // Authentication Card (dynamic based on current method)
          FutureBuilder<String?>(
            future: SecureStorageService.getAuthMethod(), // Get current auth method
            builder: (context, snapshot) {
              final currentMethod =
                  snapshot.data == "pattern" ? "Pattern" : "PIN"; // Format for display

              return Card(
                color: const Color(0xFFFFF3E6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Unlock Authentication",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF553F2B))),
                      const SizedBox(height: 10),
                      Text("Current method: $currentMethod",
                          style: itemTextStyle),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // PIN Setup Button
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.pin, color: Colors.white),
                              label: const Text("Set PIN",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF936B46),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PasscodeScreen(
                                      isSetupMode: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Pattern Setup Button
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.gesture, color: Colors.white),
                              label: const Text("Set Pattern",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF936B46),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PatternScreen(
                                      isSetupMode: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF936B46)),

          // Notifications Toggle
          SwitchListTile(
            title: const Text("Enable Notifications", style: itemTextStyle),
            value: _notificationsEnabled,
            onChanged: _updateNotifications,
            activeColor: const Color(0xFF936B46), // Gold when enabled
          ),
          const Divider(color: Color(0xFF936B46)),

          // Export Settings
          ListTile(
            leading: const Icon(Icons.download, color: Color(0xFF564535)), // Dark brown icon
            title: const Text("Export Settings", style: itemTextStyle),
            onTap: _exportSettings,
          ),
          const Divider(color: Color(0xFF936B46)),

          // Import Settings
          ListTile(
            leading: const Icon(Icons.upload, color: Color(0xFF564535)),
            title: const Text("Import Settings", style: itemTextStyle),
            onTap: _importSettings,
          ),
          const Divider(color: Color(0xFF936B46)),

          // ★ UPDATED RESET BUTTON - CONSISTENT COLORS
          ListTile(
            leading: const Icon(Icons.restore, color: Color(0xFF564535)),
            title: const Text("Reset to Default", 
                style: TextStyle(
                  fontSize: 20, 
                  color: Color(0xFF553F2B),
                  fontWeight: FontWeight.w500
                )),
            subtitle: const Text("Delete ALL data and settings",
                style: TextStyle(color: Color(0xFF936B46))), // Gold subtitle
            onTap: _confirmAndReset,
          ),
          const Divider(color: Color(0xFF936B46)),

          // Profile Avatar
          ListTile(
            leading: const Icon(Icons.pets, color: Color(0xFF564535)),
            title: const Text("Profile Avatar", style: itemTextStyle),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileAvatarScreen(),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF936B46)),

          // Time Lock Configuration
          ListTile(
            leading: const Icon(Icons.timer, color: Color(0xFF564535)),
            title: const Text("Configure Time-Based Lock", style: itemTextStyle),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const time_config.TimeLockConfigScreen(),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF936B46)),
          
          // Edit Saved Time Locks
          ListTile(
            leading: const Icon(Icons.list_alt, color: Color(0xFF564535)),
            title: const Text("Edit Saved Time Locks", style: itemTextStyle),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const time_list.TimeLocksListScreen(),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF936B46)),
          
          // Location Lock Configuration
          ListTile(
            leading: const Icon(Icons.location_on, color: Color(0xFF564535)),
            title: const Text("Configure Location-Based Lock", style: itemTextStyle),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const location_config.LocationLockConfigScreen(),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF936B46)),
          
          // Edit Saved Location Locks
          ListTile(
            leading: const Icon(Icons.map, color: Color(0xFF564535)),
            title: const Text("Edit Saved Location Locks", style: itemTextStyle),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const location_list.LocationLocksListScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}