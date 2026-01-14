// Import required Flutter packages and application components
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:provider/provider.dart'; // For state management using Provider pattern
import 'package:device_apps/device_apps.dart'; // For accessing installed applications on device
import './time_locks_controller.dart'; // Controller for managing time-based lock rules
import 'time_lock_config_screen.dart'; // Screen for configuring time locks

/// TimeLocksListScreen - Screen that displays all saved time-based locks
/// Shows a list of configured time locks with options to edit each one
class TimeLocksListScreen extends StatefulWidget {
  const TimeLocksListScreen({super.key}); // Constructor with optional key parameter

  @override
  State<TimeLocksListScreen> createState() => _TimeLocksListScreenState();
}

/// State class for TimeLocksListScreen
/// Manages the list view and app name resolution for displaying time locks
class _TimeLocksListScreenState extends State<TimeLocksListScreen> {
  // Cache for mapping package names to human-readable app names
  // Improves performance by avoiding repeated DeviceApps lookups
  final Map<String, String> _appNameCache = {};

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to load time locks after the first frame is built
    // This ensures the UI is ready before fetching data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Access the TimeLocksController via Provider and load time locks
      context.read<TimeLocksController>().loadTimeLocks();
    });
  }

  // Helper function to get display name for any package name
  /// Resolves Android package names to human-readable app names
  /// Uses cache for performance, DeviceApps for installed apps, and formatting as fallback
  /// 
  /// @param packageName - Android package name (e.g., "com.example.app")
  /// @return Future<String> - Human-readable app name
  Future<String> _getDisplayName(String packageName) async {
    // If it's already in cache, return cached value for performance
    if (_appNameCache.containsKey(packageName)) {
      return _appNameCache[packageName]!;
    }

    // If it's not a package name (doesn't contain dots), return as is
    // This handles cases where app_name is already a readable name
    if (!packageName.contains('.')) {
      _appNameCache[packageName] = packageName; // Cache the value
      return packageName;
    }

    // Try to get app info from installed apps using DeviceApps
    try {
      final Application? app = await DeviceApps.getApp(packageName);
      if (app != null) {
        _appNameCache[packageName] = app.appName; // Cache the readable name
        return app.appName; // Return actual app name
      }
    } catch (e) {
      print("Error getting app info for $packageName: $e"); // Log error but continue
    }

    // Fallback: format package name to look nicer
    // Example: "com.example.myapp" -> "Myapp"
    final formattedName = _formatPackageName(packageName);
    _appNameCache[packageName] = formattedName; // Cache formatted name
    return formattedName;
  }

  /// Format a package name to a more readable display name
  /// Extracts the last part of the package and capitalizes the first letter
  /// 
  /// @param packageName - Android package name
  /// @return String - Formatted display name
  String _formatPackageName(String packageName) {
    final parts = packageName.split('.'); // Split by dots
    if (parts.length > 1) {
      final lastPart = parts.last; // Get the last part (usually the app name)
      if (lastPart.isNotEmpty) {
        // Capitalize the first letter and keep the rest as-is
        return lastPart[0].toUpperCase() + lastPart.substring(1);
      }
    }
    return packageName; // Return original if formatting fails
  }

  @override
  Widget build(BuildContext context) {
    // Get the TimeLocksController instance using Provider's watch method
    // This ensures the widget rebuilds when the controller notifies listeners
    final controller = context.watch<TimeLocksController>();
    
    // Get the current list of time locks from the controller
    // The controller now returns time locks sorted by latest first
    final locks = controller.timeLocks;

    // Main scaffold widget that provides the basic visual structure
    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2), // Light beige background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9E9D2), // Match background color
        elevation: 0, // Remove shadow for flat design
        // Back button for navigation
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF936B46), size: 28), // Gold back arrow
          onPressed: () => Navigator.pop(context), // Navigate back when pressed
        ),
        // Screen title
        title: const Text(
          "Saved Time Locks", // Title text
          style: TextStyle(
            fontSize: 24, // Larger font size for title
            fontWeight: FontWeight.bold, // Bold text
            color: Color(0xFF553F2B), // Dark brown color
          ),
        ),
      ),
      // Conditional body: show empty state or list of locks
      body: locks.isEmpty
          ? const Center(
              // Show empty state message when no time locks exist
              child: Text(
                "No time locks saved", // Empty state message
                style: TextStyle(fontSize: 18, color: Color(0xFF553F2B)), // Styled text
              ),
            )
          : ListView.builder(
              // List view for displaying time locks
              itemCount: locks.length, // Number of items in the list
              itemBuilder: (context, index) {
                final lock = locks[index]; // Get the lock at current index
                final packageName = lock["app_name"] ?? "Unknown App"; // Extract package name with fallback
                
                // FutureBuilder for asynchronously resolving package name to display name
                return FutureBuilder<String>(
                  future: _getDisplayName(packageName), // Resolve to human-readable name
                  builder: (context, snapshot) {
                    // Use resolved name or fallback to package name
                    final displayName = snapshot.data ?? packageName;
                    
                    // Card widget for each time lock
                    return Card(
                      color: const Color(0xFFFFF6EC), // Light cream card background
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Rounded corners
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Card margins
                      child: ListTile(
                        // Primary text: app name (resolved to human-readable)
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            color: Color(0xFF553F2B), // Dark brown text
                            fontSize: 18, // Medium font size
                            fontWeight: FontWeight.w600, // Semi-bold weight
                          ),
                        ),
                        // Secondary text: time range for the lock
                        subtitle: Text(
                          "From ${lock["start_time"]} to ${lock["end_time"]}", // Display start and end times
                          style: const TextStyle(
                            color: Color(0xFF936B46), // Gold text
                            fontSize: 16, // Smaller font size
                          ),
                        ),
                        // Trailing edit button for modifying the lock
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF936B46)), // Gold edit icon
                          onPressed: () async {
                            // Navigate to edit screen with existing lock data
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (BuildContext context) => TimeLockConfigScreen(
                                  existingLock: lock, // Pass existing lock for editing
                                ),
                              ),
                            );
                            // Reload locks after returning from edit screen
                            controller.loadTimeLocks();
                          },
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