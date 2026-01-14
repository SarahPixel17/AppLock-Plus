// Import required Dart and Flutter packages for async operations, math, UI, platform integration, pattern lock, state management, and device app access
import 'dart:async'; // For Timer and asynchronous operations
import 'dart:math' as math; // For math operations (min function)
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:flutter/services.dart'; // For MethodChannel, HapticFeedback, and platform communication
import 'package:pattern_lock/pattern_lock.dart'; // For pattern lock grid widget
import 'package:provider/provider.dart'; // For state management using Provider pattern
import 'package:device_apps/device_apps.dart'; // ⭐ REQUIRED for app info lookup (installed apps)

// Import application services and components
import '../services/secure_storage_service.dart'; // Service for secure, encrypted storage
import '../services/api_service.dart'; // Service for API communication with backend
import '../profile/avatar_provider.dart'; // Provider for managing avatar state
import 'settings_screen.dart'; // Screen for application settings

/// PatternScreen - Screen for pattern authentication during setup or verification
/// This screen handles both pattern setup (when isSetupMode = true) and pattern verification (when isSetupMode = false)
/// Uses a 3x3 pattern grid for drawing unlock patterns
class PatternScreen extends StatefulWidget {
  final bool isSetupMode; // Determines if screen is for setting up new pattern (true) or verifying existing pattern (false)
  final String? appName; // Optional: Name of app being unlocked (may be package name)

  const PatternScreen({
    super.key,
    this.isSetupMode = false,
    this.appName,
  });

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

/// State class for PatternScreen
/// Manages pattern input, confirmation flow, idle timer, and unlock logging
class _PatternScreenState extends State<PatternScreen> {
  List<int>? _firstPattern; // Stores first pattern during setup confirmation phase
  bool _isConfirming = false; // Flag to track if user is confirming their pattern during setup
  Timer? _idleTimer; // Timer for detecting idle state (no user input)
  static const MethodChannel _unlockChannel = MethodChannel("applock/unlock"); // Channel for native unlock communication

  @override
  void initState() {
    super.initState();
    _resetIdleTimer(); // Start idle timer when screen initializes
  }

  @override
  void dispose() {
    _idleTimer?.cancel(); // Cancel timer to prevent memory leaks
    super.dispose();
  }

  /// Resets the idle timer (called on any user interaction)
  /// After 10 seconds of inactivity, sets avatar to sleeping expression
  void _resetIdleTimer() {
    _idleTimer?.cancel(); // Cancel existing timer
    _idleTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted) return; // Check if widget is still in tree
      final avatar = Provider.of<AvatarProvider>(context, listen: false);
      await avatar.setExpression(CatExpression.sleeping); // Set sleeping avatar
    });
  }

  /// Notifies native Android code of successful unlock
  /// Only called in authentication mode (not setup mode)
  Future<void> _notifyUnlockSuccess() async {
    if (widget.isSetupMode) return; // Only for authentication mode
    try {
      await _unlockChannel.invokeMethod("onUnlockSuccess"); // Call native method
    } catch (e) {
      debugPrint("▲ onUnlockSuccess error: $e"); // Log error but don't crash
    }
  }

  /// Notifies native Android code of cancelled unlock (back button pressed)
  /// Only called in authentication mode (not setup mode)
  Future<void> _notifyUnlockCancelled() async {
    if (widget.isSetupMode) return; // Only for authentication mode
    try {
      await _unlockChannel.invokeMethod("onUnlockCancelled"); // Call native method
    } catch (e) {
      debugPrint("▲ onUnlockCancelled error: $e"); // Log error but don't crash
    }
  }

  /// Logs unlock attempts (success or failure) to secure storage
  /// Maps package names to human-readable app names for better logging
  Future<void> _logUnlockAttempt(bool success) async {
    try {
      String displayName = widget.appName ?? 'Unknown App'; // Default display name
      String packageName = widget.appName ?? 'unknown'; // Default package name

      // If the provided name looks like a package name, try to resolve the real app name
      if (_isPackageName(displayName)) {
        // Try DeviceApps (installed apps) to get actual app info
        final app = await _getAppInfo(displayName);
        if (app != null) {
          displayName = app.appName; // Use actual app name
          packageName = app.packageName; // Use actual package name
          // Save mapping for future use (improves performance for future lookups)
          await SecureStorageService.saveAppNameMapping(packageName, app.appName);
        } else {
          // Try previously saved mapping from secure storage
          final saved = await SecureStorageService.getAppName(displayName);
          if (saved != null) {
            displayName = saved; // Use previously saved name
          }
        }
      }

      // Create unlock log entry with all relevant information
      final unlockLog = {
        'package_name': packageName, // Always store original package name (for native service)
        'app_name': displayName, // Human-readable name (for user display)
        'unlock_method': 'pattern', // Authentication method used
        'timestamp': DateTime.now().toIso8601String(), // ISO format timestamp
        'success': success, // Whether unlock was successful
      };

      // Save log entry to secure storage
      await SecureStorageService.saveUnlockLog(unlockLog);
      print("✓ Unlock attempt logged: $displayName");
    } catch (e) {
      print("X Failed to log unlock attempt: $e"); // Log error but don't crash
    }
  }

  /// Retrieves application information by package name using DeviceApps
  Future<Application?> _getAppInfo(String packageName) async {
    try {
      return await DeviceApps.getApp(packageName);
    } catch (e) {
      print("Error getting app info for $packageName: $e");
      return null; // Return null on error
    }
  }

  /// Saves new pattern during setup mode
  /// Saves to both local secure storage and backend API
  Future<void> _savePattern(List<int> pattern) async {
    final avatar = Provider.of<AvatarProvider>(context, listen: false);

    try {
      final patternString = pattern.join(","); // Convert pattern list to comma-separated string
      // Save pattern and authentication method to local secure storage
      await SecureStorageService.savePattern(patternString);
      await SecureStorageService.saveAuthMethod("pattern");
      // Save pattern to backend API
      await ApiService.savePattern("user1", patternString);

      await avatar.setExpression(CatExpression.happy); // Set avatar to happy
      HapticFeedback.mediumImpact(); // Provide tactile feedback

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pattern saved successfully!")), // Show success
      );

      await Future.delayed(const Duration(milliseconds: 800)); // Brief delay for UX
      if (mounted) Navigator.pop(context); // Return to previous screen
    } catch (e) {
      await avatar.setExpression(CatExpression.sad); // Set avatar to sad
      HapticFeedback.vibrate(); // Provide error tactile feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save pattern.")), // Show error
      );
    }
  }

  /// Verifies entered pattern against saved pattern in secure storage
  /// Handles both success and failure scenarios with appropriate feedback
  Future<void> _verifyPattern(List<int> pattern) async {
    final avatar = Provider.of<AvatarProvider>(context, listen: false);
    final savedPattern = await SecureStorageService.getPattern(); // Retrieve saved pattern

    // Check if pattern has been set up
    if (savedPattern == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No pattern set.")), // Show error
      );
      return;
    }

    final input = pattern.join(","); // Convert input pattern to string
    final correct = (input == savedPattern); // Compare with saved pattern

    if (correct) {
      await avatar.setExpression(CatExpression.happy); // Set avatar to happy
      HapticFeedback.mediumImpact(); // Provide success tactile feedback

      await _logUnlockAttempt(true); // Log successful unlock attempt

      // Show success message with appropriate text
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appName != null && _isPackageName(widget.appName!)
                ? "App unlocked!" // Generic message for package names
                : widget.appName != null
                    ? "${widget.appName} unlocked!" // Specific app name
                    : "Unlocked", // Generic unlock
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500)); // Brief delay
      await _notifyUnlockSuccess(); // Notify native code
      await Future.delayed(const Duration(milliseconds: 500)); // Additional delay
      if (mounted) Navigator.pop(context, true); // Return with success result
    } else {
      await avatar.setExpression(CatExpression.sad); // Set avatar to sad
      HapticFeedback.vibrate(); // Provide error tactile feedback

      await _logUnlockAttempt(false); // Log failed unlock attempt

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect Pattern.")), // Show error
      );
    }
  }

  /// Determines if a string is likely an Android package name
  /// Package names typically follow reverse domain notation (com.example.app)
  bool _isPackageName(String name) {
    return name.contains('.') &&
        (name.startsWith('com.') ||
            name.startsWith('org.') ||
            name.startsWith('net.') ||
            RegExp(r'^[a-z]+\.[a-z]').hasMatch(name)); // Regex for pattern like "example.app"
  }

  /// Handles back button press (Android hardware back button)
  /// Notifies native code of cancelled unlock before allowing navigation
  Future<bool> _onWillPop() async {
    await _notifyUnlockCancelled(); // Notify native code
    return true; // Allow back navigation
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>(); // Get current avatar state
    final size = MediaQuery.of(context).size; // Get screen dimensions
    final w = size.width; // Screen width
    final h = size.height; // Screen height

    // Calculate avatar size based on minimum screen dimension for responsiveness
    final minSide = math.min(w, h);
    final avatarSize = minSide * 0.45; // Avatar size as 45% of minimum screen dimension

    // WillPopScope handles Android hardware back button
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9E9D2), // Light beige background
        appBar: AppBar(
          backgroundColor: const Color(0xFFF9E9D2), // Match background
          elevation: 0, // Remove shadow
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: const Color(0xFF936B46), size: w * 0.08), // Back arrow
            onPressed: () async {
              await _notifyUnlockCancelled(); // Notify native code
              Navigator.pop(context); // Navigate back
            },
          ),
          title: Text(
            widget.isSetupMode ? "Draw Pattern" : "Enter Pattern", // Dynamic title
            style: TextStyle(
              fontSize: w * 0.055, // Responsive font size
              fontWeight: FontWeight.w600, // Semi-bold
              color: const Color(0xFF553F2B), // Dark brown text
            ),
          ),
          centerTitle: true,
          actions: [
            // Settings button (top-right)
            IconButton(
              icon: Image.asset("assets/ui/settingicon.png", height: w * 0.085), // Custom settings icon
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            SizedBox(width: w * 0.04), // Right padding
          ],
        ),
        body: SafeArea(
          // Ensure content isn't obscured by notches/system UI
          child: Center(
            child: Column(
              children: [
                // Avatar image
                Image.asset(
                  avatar.currentAsset, // Current avatar image
                  width: avatarSize, // Responsive width
                  height: avatarSize, // Responsive height
                ),
                const SizedBox(height: 20), // Vertical spacing
                
                // Dynamic instruction text based on mode and context
                Text(
                  widget.isSetupMode
                      ? (_isConfirming
                          ? "Confirm your pattern" // Confirmation phase
                          : "Draw your pattern") // Initial pattern entry
                      : (widget.appName != null && _isPackageName(widget.appName!)
                          ? "Unlock App" // Generic message for package names
                          : widget.appName != null
                              ? "Unlock ${widget.appName}" // Specific app name
                              : "Draw unlock pattern"), // Generic unlock
                  style: const TextStyle(
                      color: Color(0xFF553F2B), fontSize: 18), // Dark brown text
                ),
                const SizedBox(height: 20), // Vertical spacing

                // ⭐⭐ REPLACED SECTION — NEW COMPACT PATTERN GRID ⭐⭐
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: w * 0.70, // Pattern grid width as 70% of screen width
                      height: h * 0.40, // Pattern grid height as 40% of screen height
                      child: PatternLock(
                        dimension: 3, // 3x3 grid (9 points total)
                        pointRadius: w * 0.035, // Responsive point radius
                        relativePadding: 0.08, // Padding relative to container size
                        selectThreshold: (w * 0.10).round(), // Touch sensitivity threshold
                        fillPoints: true, // Fill selected points
                        showInput: true, // Show pattern line as user draws
                        selectedColor: const Color(0xFFD2AE83), // Selected point color (light brown)
                        notSelectedColor: const Color(0xFF936B46), // Unselected point color (gold)
                        onInputComplete: (pattern) async { // Called when user completes pattern
                          _resetIdleTimer(); // Reset idle timer on user interaction
                          HapticFeedback.selectionClick(); // Provide subtle tactile feedback

                          // Setup mode logic (two-step pattern confirmation)
                          if (widget.isSetupMode) {
                            if (!_isConfirming) {
                              // First pattern entry phase
                              setState(() {
                                _firstPattern = pattern; // Store first pattern
                                _isConfirming = true; // Move to confirmation phase
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Pattern recorded. Confirm it."), // Instruction
                                ),
                              );
                              return; // Wait for confirmation pattern
                            }

                            // Confirmation phase - check if patterns match
                            if (pattern.join(",") == _firstPattern!.join(",")) {
                              await _savePattern(pattern); // Save pattern if they match
                            } else {
                              // Patterns don't match - restart setup
                              setState(() {
                                _isConfirming = false;
                                _firstPattern = null;
                              });
                              await avatar.setExpression(CatExpression.sad); // Set avatar to sad
                              HapticFeedback.vibrate(); // Provide error feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("❌ Patterns do not match. Try again."), // Error
                                ),
                              );
                            }
                          } else {
                            // Authentication mode - verify entered pattern
                            await _verifyPattern(pattern);
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20), // Bottom spacing
              ],
            ),
          ),
        ),
      ),
    );
  }
}