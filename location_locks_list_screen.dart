// Import required Flutter packages and application components
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:provider/provider.dart'; // For state management using Provider pattern
import '../location_locks_controller.dart'; // Controller for managing location locks
import 'location_lock_config_screen.dart'; // Screen for configuring location locks

/// LocationLocksListScreen - Screen that displays all saved location-based locks
/// Shows a list of configured location locks with options to edit or delete each one
class LocationLocksListScreen extends StatefulWidget {
  const LocationLocksListScreen({super.key}); // Constructor with optional key parameter

  @override
  State<LocationLocksListScreen> createState() => _LocationLocksListScreenState();
}

/// State class for LocationLocksListScreen
/// Manages the list view and interactions with location locks
class _LocationLocksListScreenState extends State<LocationLocksListScreen> {
  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to load location locks after the first frame is built
    // This ensures the UI is ready before fetching data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Access the LocationLocksController via Provider and load location locks
      context.read<LocationLocksController>().loadLocationLocks();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the LocationLocksController instance using Provider's watch method
    // This ensures the widget rebuilds when the controller notifies listeners
    final controller = context.watch<LocationLocksController>();
    // Get the current list of location locks from the controller
    final locks = controller.locationLocks;

    // Define color constants for consistent theme
    const brown = Color(0xFF553F2B); // Dark brown for text
    const gold = Color(0xFF936B46); // Gold/accent color
    const bg = Color(0xFFF9E9D2); // Light beige background

    // Main scaffold widget that provides the basic visual structure
    return Scaffold(
      backgroundColor: bg, // Set background color
      appBar: AppBar(
        backgroundColor: bg, // Match background color
        elevation: 0, // Remove shadow for flat design
        // Back button for navigation
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: gold, size: 28), // Gold back arrow
          onPressed: () => Navigator.pop(context), // Navigate back when pressed
        ),
        // Screen title
        title: const Text(
          "Saved Location Locks", // Title text
          style: TextStyle(
            fontSize: 24, // Larger font size for title
            fontWeight: FontWeight.bold, // Bold text
            color: brown, // Dark brown color
          ),
        ),
      ),
      // Conditional body: show empty state or list of locks
      body: locks.isEmpty
          ? const Center(
              // Show empty state message when no location locks exist
              child: Text(
                "No location locks saved", // Empty state message
                style: TextStyle(fontSize: 18, color: brown), // Styled text
              ),
            )
          : RefreshIndicator(
              // Pull-to-refresh functionality for the list
              onRefresh: () async => controller.loadLocationLocks(), // Refresh data when pulled
              child: ListView.separated(
                // List view with separators between items
                physics: const AlwaysScrollableScrollPhysics(), // Enable scrolling
                itemCount: locks.length, // Number of items in the list
                // Builder for separators between list items
                separatorBuilder: (_, __) => const Divider(
                  color: gold, // Gold colored divider
                  indent: 16, // Indent from left
                  endIndent: 16, // Indent from right
                ),
                // Builder for each location lock item
                itemBuilder: (context, index) {
                  final lock = locks[index]; // Get the lock at current index
                  final id = lock["id"]; // Extract the unique ID for the lock

                  // Card widget for each location lock
                  return Card(
                    color: const Color(0xFFFFF6EC), // Light cream card background
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Card margins
                    child: ListTile(
                      // Leading icon for visual identification
                      leading: const Icon(Icons.location_on, color: gold, size: 32),
                      // Primary text: location name
                      title: Text(
                        lock["location_name"] ?? "Unnamed Location", // Use location name or fallback
                        style: const TextStyle(
                          color: brown, // Dark brown text
                          fontSize: 18, // Medium font size
                          fontWeight: FontWeight.w600, // Semi-bold weight
                        ),
                      ),
                      // Secondary text: app name and coordinates
                      subtitle: Text(
                        "App: ${lock["app_name"]}\n" // Display app name
                        "Lat: ${lock["latitude"]?.toStringAsFixed(4) ?? "?"}, " // Latitude with 4 decimal places
                        "Lon: ${lock["longitude"]?.toStringAsFixed(4) ?? "?"}", // Longitude with 4 decimal places
                        style: const TextStyle(color: gold, fontSize: 15), // Gold text, smaller font
                      ),
                      // Trailing menu button for actions (edit/delete)
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: gold), // Three-dot menu icon
                        // Handle menu item selection
                        onSelected: (value) async {
                          if (value == 'edit') {
                            // ✅ EDIT ACTION: Navigate to edit screen
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LocationLockConfigScreen(
                                  existingLock: lock, // 👈 Pass existing lock data for editing
                                ),
                              ),
                            );
                            // Reload locks after returning from edit screen
                            controller.loadLocationLocks();
                          } else if (value == 'delete') {
                            // DELETE ACTION: Show confirmation dialog
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFFF9E9D2), // Light beige background
                                title: const Text("Delete Location Lock?", // Dialog title
                                    style: TextStyle(color: brown)),
                                content: Text(
                                  // Confirmation message with lock details
                                  "Are you sure you want to delete lock for ${lock["app_name"]} at ${lock["location_name"]}?",
                                  style: const TextStyle(color: brown), // Dark brown text
                                ),
                                // Dialog action buttons
                                actions: [
                                  // Cancel button
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false), // Return false (cancel)
                                    child: const Text("Cancel", style: TextStyle(color: gold)), // Gold text
                                  ),
                                  // Delete button
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true), // Return true (confirm)
                                    child: const Text("Delete", style: TextStyle(color: Colors.red)), // Red text for destructive action
                                  ),
                                ],
                              ),
                            );

                            // If user confirmed deletion, call controller to delete
                            if (confirm == true) {
                              final success = await controller.deleteLocationLock(id);
                              // Show error message if deletion failed
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("❌ Failed to delete location lock"), // Error message
                                    backgroundColor: Colors.red, // Red background for error
                                  ),
                                );
                              }
                            }
                          }
                        },
                        // Define menu items
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text("Edit")), // Edit option
                          const PopupMenuItem(value: 'delete', child: Text("Delete")), // Delete option
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}