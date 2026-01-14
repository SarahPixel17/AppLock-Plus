// Import required Flutter packages and application components
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:device_apps/device_apps.dart'; // For accessing installed applications on device
import 'package:provider/provider.dart'; // For state management using Provider pattern
import '../time_locks_controller.dart'; // Controller for managing time-based lock rules

import '../lock_screen_router.dart'; // Router for handling authentication screen navigation

/// TimeLockConfigScreen - Screen for configuring time-based app locks
/// Allows users to select an app and set time restrictions when the app should be locked
/// Supports both creating new time locks and editing existing ones
class TimeLockConfigScreen extends StatefulWidget {
  final Map<String, dynamic>? existingLock; // Optional parameter for editing existing locks

  const TimeLockConfigScreen({super.key, this.existingLock});

  @override
  State<TimeLockConfigScreen> createState() => _TimeLockConfigScreenState();
}

/// State class for TimeLockConfigScreen
/// Manages app selection, time range selection, and save/delete operations
class _TimeLockConfigScreenState extends State<TimeLockConfigScreen> {
  // Time selection variables
  TimeOfDay? _startTime; // Selected start time for lock
  TimeOfDay? _endTime; // Selected end time for lock
  
  // App selection variables
  List<Application> _apps = []; // List of installed applications
  final Set<String> _selectedApps = {}; // Set of selected app names (supports only single selection)
  
  // UI state variables
  bool _isLoading = true; // Flag to indicate apps are being loaded
  bool _isSaving = false; // Flag to indicate save operation in progress
  bool _isDeleting = false; // Flag to indicate delete operation in progress

  @override
  void initState() {
    super.initState();
    _loadApps(); // Load installed apps when screen initializes

    // If editing an existing lock, populate form fields with existing data
    if (widget.existingLock != null) {
      final lock = widget.existingLock!;
      _selectedApps.add(lock["app_name"]); // Pre-select the app
      _startTime = _parseTime(lock["start_time"]); // Parse and set start time
      _endTime = _parseTime(lock["end_time"]); // Parse and set end time
    }
  }

  /// Parse time string to TimeOfDay object
  /// Supports both ISO format (full DateTime) and HH:mm format
  TimeOfDay _parseTime(String timeStr) {
    try {
      // First try to parse as full ISO DateTime string
      final dt = DateTime.parse(timeStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      // If ISO format fails, try parsing as HH:mm format
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]), // Hour part
        minute: int.parse(parts[1]), // Minute part
      );
    }
  }

  /// Load installed applications from the device
  /// Filters out system apps and includes app icons for display
  Future<void> _loadApps() async {
    final apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: false, // Exclude system apps for cleaner UI
      includeAppIcons: true, // Include app icons for visual identification
    );
    setState(() {
      _apps = apps; // Store apps in state variable
      _isLoading = false; // Update loading state
    });
  }

  /// Handle app selection/deselection
  /// Supports single selection only (clears previous selection when new app is selected)
  void _handleAppTap(String appName) {
    setState(() {
      if (_selectedApps.contains(appName)) {
        // Deselect if already selected
        _selectedApps.remove(appName);
      } else {
        // Select new app (single selection only)
        _selectedApps
          ..clear() // Clear any previous selection
          ..add(appName); // Add new selection
      }
    });
  }

  /// Show time picker for selecting start time
  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(), // Current time as default
    );
    if (picked != null) setState(() => _startTime = picked); // Update state if time selected
  }

  /// Show time picker for selecting end time
  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(), // Current time as default
    );
    if (picked != null) setState(() => _endTime = picked); // Update state if time selected
  }

  /// SAVE OR UPDATE SCHEDULE
  /// Validates inputs and saves/updates time lock configuration
  Future<void> _saveSchedule(BuildContext context) async {
    // Validate required inputs
    if (_selectedApps.isEmpty || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please select an app and time range.')),
      );
      return;
    }

    setState(() => _isSaving = true); // Set saving state

    final controller = context.read<TimeLocksController>(); // Get time locks controller
    final now = DateTime.now(); // Current date for time conversion

    // Convert TimeOfDay to DateTime for API submission
    final startDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    // Format as ISO strings for API
    final startStr = startDateTime.toIso8601String();
    final endStr = endDateTime.toIso8601String();

    final selectedAppName = _selectedApps.first; // Get selected app name

    // Find the selected app object to get package name
    final app = _apps.firstWhere(
      (a) => a.appName == selectedAppName,
    );

    final packageName = app.packageName; // Android package name
    final appName = app.appName; // Human-readable app name

    bool success = false;

    // Determine if we're updating existing lock or creating new one
    if (widget.existingLock != null) {
      final id = widget.existingLock!["id"]; // Get existing lock ID
      success = await controller.updateTimeLock(id, packageName, startStr, endStr);
    } else {
      success = await controller.addTimeLock(packageName, startStr, endStr);
    }

    setState(() => _isSaving = false); // Reset saving state

    // Show success/error feedback
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingLock != null
              ? '✅ Time lock updated for $appName' // Update success
              : '✅ Time lock saved for $appName'), // Create success
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.pop(context, true); // Return success flag to previous screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Failed to save time lock."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// ------------------------------------------------------------
  /// ✅ UPDATED DELETE FUNCTION (Solution #4)
  /// ------------------------------------------------------------
  /// Delete existing time lock schedule with confirmation dialog
  Future<void> _deleteSchedule(BuildContext context) async {
    // Show confirmation dialog before deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF9E9D2), // Light beige background
        title: const Text(
          "Delete Time Lock",
          style: TextStyle(color: Color(0xFF553F2B)), // Dark brown text
        ),
        content: const Text(
          "Are you sure you want to delete this schedule?",
          style: TextStyle(color: Color(0xFF553F2B)),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // Return false (cancel)
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF936B46)), // Gold text
            ),
          ),
          // Delete confirmation button
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), // Return true (confirm)
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, // Red for destructive action
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return; // Exit if user cancelled

    setState(() => _isDeleting = true); // Set deleting state

    final controller = context.read<TimeLocksController>(); // Get controller
    final id = widget.existingLock!["id"]; // Get lock ID to delete
    final success = await controller.deleteTimeLock(id); // Call delete

    setState(() => _isDeleting = false); // Reset deleting state

    // Show success/error feedback
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Time lock deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return success flag
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to delete schedule.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define color constants for consistent theme
    const brownText = Color(0xFF553F2B); // Dark brown for text
    const accent = Color(0xFF936B46); // Gold/accent color
    const bg = Color(0xFFF9E9D2); // Light beige background
    
    final isEdit = widget.existingLock != null; // Determine if in edit mode

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0, // Remove shadow
        title: Text(
          isEdit ? 'Edit Time Lock' : 'Configure Time-Based Lock', // Dynamic title
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: brownText,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: accent), // Gold back arrow
          onPressed: () => Navigator.pop(context), // Navigate back
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title for app selection
            const Text(
              'Select App to Lock:',
              style: TextStyle(
                fontSize: 16,
                color: brownText,
                fontWeight: FontWeight.w600, // Semi-bold
              ),
            ),
            const SizedBox(height: 10), // Spacing
            
            // App selection list (loading or loaded)
            _isLoading
                ? const Center(child: CircularProgressIndicator()) // Loading indicator
                : Expanded(
                    child: ListView.builder(
                      itemCount: _apps.length,
                      itemBuilder: (context, index) {
                        final app = _apps[index]; // Current app
                        final isSelected = _selectedApps.contains(app.appName); // Check if selected

                        return ListTile(
                          // App icon (if available)
                          leading: app is ApplicationWithIcon
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8), // Rounded corners
                                  child: Image.memory(
                                    app.icon,
                                    width: 40,
                                    height: 40,
                                  ),
                                )
                              : const Icon(Icons.apps, color: accent), // Fallback icon
                          
                          // App name
                          title: Text(
                            app.appName,
                            style: const TextStyle(
                              color: brownText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          // Package name (gray text for reference)
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          
                          // Checkbox for selection
                          trailing: Checkbox(
                            activeColor: accent, // Gold when checked
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedApps
                                    ..clear() // Clear previous selection (single select)
                                    ..add(app.appName); // Add new selection
                                } else {
                                  _selectedApps.remove(app.appName); // Deselect
                                }
                              });
                            },
                          ),
                          
                          // Handle tap on entire row
                          onTap: () => _handleAppTap(app.appName),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 20), // Spacing
            
            // Section title for time range selection
            const Text(
              'Select Time Range:',
              style: TextStyle(
                fontSize: 16,
                color: brownText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8), // Spacing
            
            // Time selection buttons in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Start Time button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent, // Gold background
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                  ),
                  icon: const Icon(Icons.access_time, color: Colors.white),
                  onPressed: _pickStartTime,
                  label: Text(
                    _startTime == null
                        ? 'Start Time' // Placeholder text
                        : 'Start: ${_startTime!.format(context)}', // Formatted time
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20), // Spacing between buttons
                
                // End Time button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent, // Gold background
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                  ),
                  icon: const Icon(Icons.timer_off, color: Colors.white),
                  onPressed: _pickEndTime,
                  label: Text(
                    _endTime == null
                        ? 'End Time' // Placeholder text
                        : 'End: ${_endTime!.format(context)}', // Formatted time
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const Spacer(), // Push buttons to bottom
            
            // Action buttons at bottom
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button (only shown in edit mode)
                  if (isEdit) ...[
                    ElevatedButton.icon(
                      onPressed: _isDeleting ? null : () => _deleteSchedule(context), // Disable when deleting
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent, // Red for destructive action
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: Text(
                        _isDeleting ? 'Deleting...' : 'Delete Schedule',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16), // Spacing between buttons
                  ],
                  
                  // Save/Update button
                  ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveSchedule(context), // Disable when saving
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent, // Gold background
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isSaving
                          ? 'Saving...' // Saving state text
                          : (isEdit ? 'Update Schedule' : 'Save Schedule'), // Dynamic text
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }
}