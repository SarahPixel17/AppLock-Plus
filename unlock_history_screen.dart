// Import required Flutter packages and application services
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:device_apps/device_apps.dart';           // ✅ Added: For accessing installed applications to resolve package names
import '../services/secure_storage_service.dart';        // ✅ Added: For secure storage of app name mappings
import '../services/api_service.dart'; // Service for API communication with backend

/// UnlockHistoryScreen - Screen that displays the history of unlock attempts
/// Shows a chronological list of all authentication attempts (successful and failed)
/// Resolves Android package names to human-readable app names for better user experience
class UnlockHistoryScreen extends StatefulWidget {
  const UnlockHistoryScreen({super.key});

  @override
  State<UnlockHistoryScreen> createState() => _UnlockHistoryScreenState();
}

/// State class for UnlockHistoryScreen
/// Manages loading, processing, and displaying unlock history logs
class _UnlockHistoryScreenState extends State<UnlockHistoryScreen> {
  // Future to handle asynchronous loading of unlock logs
  late Future<List<Map<String, dynamic>>> _logsFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the future to load unlock logs when screen is created
    _logsFuture = _loadUnlockLogs();
  }

  // =============================================================
  // ✅ UPDATED _loadUnlockLogs WITH PROPER APP NAME MAPPING
  // =============================================================
  /// Load unlock logs from API and process them to display human-readable app names
  /// Resolves Android package names to actual app names using DeviceApps or cached mappings
  /// 
  /// @return Future<List<Map<String, dynamic>>> - List of processed unlock log entries
  Future<List<Map<String, dynamic>>> _loadUnlockLogs() async {
    try {
      // STEP 1: Fetch raw unlock logs from API for the current user
      final logs = await ApiService.getUnlockLogs("user1");

      // STEP 2: Process each log entry to improve app name display
      for (var log in logs) {
        if (log['app_name'] != null) {
          String displayName = log['app_name']; // Current app name (may be package name)
          final packageName = log['package_name'] ?? log['app_name']; // Extract package name

          // Check if the app_name is actually a package name (contains dots)
          if (_isPackageName(displayName)) {
            try {
              // Try getting actual installed app info using DeviceApps
              final Application? app = await DeviceApps.getApp(packageName);
              if (app != null) {
                // Found app - use actual app name
                displayName = app.appName;
                log['app_name'] = displayName; // Update log with readable name

                // Save mapping for future use to avoid repeated DeviceApps calls
                await SecureStorageService.saveAppNameMapping(
                  packageName,
                  displayName,
                );
              } else {
                // App not found in DeviceApps - try fallback to stored mappings
                final savedName =
                    await SecureStorageService.getAppName(packageName);

                if (savedName != null) {
                  // Found saved mapping - use it
                  displayName = savedName;
                  log['app_name'] = displayName; // Update log with saved name
                }
                // If no saved mapping exists, log will keep package name
              }
            } catch (e) {
              // Handle any errors during app name resolution
              print("Error processing app name for $packageName: $e");
            }
          }
          // If not a package name, log already has readable name - no processing needed
        }
      }

      return logs; // Return processed logs
    } catch (e) {
      // Handle errors during API call or processing
      debugPrint("Error loading unlock logs: $e");
      return []; // Return empty list on error
    }
  }

  // =============================================================
  // ✅ HELPER METHOD TO DETECT PACKAGE NAMES
  // =============================================================
  /// Determines if a string is likely an Android package name
  /// Package names typically follow reverse domain notation (com.example.app)
  /// 
  /// @param name - String to check
  /// @return bool - True if string appears to be a package name, false otherwise
  bool _isPackageName(String name) {
    return name.contains('.') && // Must contain a dot
        (name.startsWith('com.') || // Common Android package prefixes
            name.startsWith('org.') ||
            name.startsWith('net.') ||
            RegExp(r'^[a-z]+\.[a-z]').hasMatch(name)); // Regex for pattern like "example.app"
  }

  @override
  Widget build(BuildContext context) {
    // Define color constants for consistent theme
    const brown = Color(0xFF553F2B); // Dark brown for text
    const gold = Color(0xFF936B46); // Gold/accent color
    const bg = Color(0xFFF9E9D2); // Light beige background

    // Main scaffold widget that provides the basic visual structure
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0, // Remove shadow for flat design
        // Back button for navigation
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: gold, size: 28), // Gold back arrow
          onPressed: () => Navigator.pop(context), // Navigate back when pressed
        ),
        // Screen title
        title: const Text(
          "Unlock History", // Title text
          style: TextStyle(
            fontSize: 24, // Larger font size for title
            fontWeight: FontWeight.bold, // Bold text
            color: brown, // Dark brown color
          ),
        ),
        // Action buttons in app bar
        actions: [
          // Refresh button to reload logs
          IconButton(
            icon: const Icon(Icons.refresh, color: gold), // Gold refresh icon
            tooltip: "Refresh", // Tooltip for accessibility
            onPressed: () {
              // Refresh logs by resetting the future
              setState(() => _logsFuture = _loadUnlockLogs());
            },
          )
        ],
      ),
      // Body uses FutureBuilder to handle asynchronous data loading
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _logsFuture, // The future that loads unlock logs
        builder: (context, snapshot) {
          // Loading state: show progress indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: gold));
          }

          // Error state: show error message
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "⚠️ Failed to load unlock logs.\n${snapshot.error}", // Error message with details
                style: const TextStyle(color: brown, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          // Empty state: no logs found
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No unlock attempts found.\n(Privacy mode: logs stored locally only)", // Explanation for empty state
                style: TextStyle(color: brown, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            );
          }

          // Data loaded successfully: display list of logs
          final logs = snapshot.data!; // Extract logs from snapshot
          return ListView.builder(
            padding: const EdgeInsets.all(16), // Padding around the list
            itemCount: logs.length, // Number of log entries
            itemBuilder: (context, i) {
              final log = logs[i]; // Current log entry
              return Card(
                color: const Color(0xFFFFF6EC), // Light cream card background
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Rounded corners
                ),
                margin: const EdgeInsets.symmetric(vertical: 6), // Vertical spacing between cards
                child: ListTile(
                  // Leading icon for visual identification
                  leading: const Icon(Icons.lock_open, color: gold, size: 28), // Gold unlock icon
                  // Primary text: app name (already processed to be human-readable)
                  title: Text(
                    log["app_name"] ?? "Unknown App", // Use app name or fallback
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, // Bold for emphasis
                      color: brown, // Dark brown text
                      fontSize: 18, // Medium font size
                    ),
                  ),
                  // Secondary text: unlock method and timestamp
                  subtitle: Text(
                    "Method: ${log["unlock_method"] ?? "N/A"}\n" // Authentication method used
                    "Time: ${log["timestamp"] ?? "Unknown"}", // When the attempt occurred
                    style: const TextStyle(
                      color: Color(0xFF936B46), // Gold text
                      fontSize: 14, // Smaller font size
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}