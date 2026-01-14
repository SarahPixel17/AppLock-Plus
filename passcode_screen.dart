// Import required Dart and Flutter packages for async operations, UI, platform integration, fonts, state management, and device app access
import 'dart:async'; // For Timer and asynchronous operations
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:flutter/services.dart'; // For MethodChannel and platform communication
import 'package:google_fonts/google_fonts.dart'; // For custom Google Fonts integration
import 'package:provider/provider.dart'; // For state management using Provider pattern

// Import application screens and components
import 'settings_screen.dart'; // Screen for application settings
import '../profile/avatar_provider.dart'; // Provider for managing avatar state
import 'passcode_controller.dart'; // Controller for managing PIN input and verification

// Import application services
import './services/api_service.dart'; // Service for API communication with backend
import './services/secure_storage_service.dart'; // Service for secure, encrypted storage

import 'package:device_apps/device_apps.dart'; // ⭐ REQUIRED for app info lookup (installed apps)

/// PasscodeScreen - Screen for PIN code entry during setup or authentication
/// This screen handles both PIN setup (when isSetupMode = true) and PIN verification (when isSetupMode = false)
/// Can be triggered for unlocking specific apps or general authentication
class PasscodeScreen extends StatefulWidget {
  final bool isSetupMode; // Determines if screen is for setting up new PIN (true) or verifying existing PIN (false)
  final String? appName; // Optional: Name of app being unlocked (may be package name)

  const PasscodeScreen({
    super.key,
    this.isSetupMode = false,
    this.appName,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

/// State class for PasscodeScreen
/// Manages PIN input, verification, idle timer, and unlock logging
class _PasscodeScreenState extends State<PasscodeScreen> {
  final PasscodeController _controller = PasscodeController(); // Controller for PIN input logic
  final int _pinLength = 4; // Fixed PIN length (4 digits)
  String _enteredPin = ""; // Current PIN being entered as a string

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

  // ------------------------------------------------------------
  // ⭐ UPDATED: Unlock attempt logging with app-name mapping
  // ------------------------------------------------------------
  /// Logs unlock attempts (success or failure) to secure storage
  /// Maps package names to human-readable app names for better logging
  Future<void> _logUnlockAttempt(bool success) async {
    try {
      String displayName = widget.appName ?? 'Unknown App'; // Default display name
      String packageName = widget.appName ?? 'unknown'; // Default package name

      // If the provided name looks like a package name, try to resolve the real app name
      if (_isPackageName(displayName)) {
        // 1️⃣ Try DeviceApps (installed apps) to get actual app info
        final app = await _getAppInfo(displayName);
        if (app != null) {
          displayName = app.appName; // Use actual app name
          packageName = app.packageName; // Use actual package name

          // Save mapping for future use (improves performance for future lookups)
          await SecureStorageService.saveAppNameMapping(packageName, app.appName);
        } else {
          // 2️⃣ Try previously saved mapping from secure storage
          final savedName = await SecureStorageService.getAppName(displayName);
          if (savedName != null) {
            displayName = savedName; // Use previously saved name
          }
        }
      }

      // Create unlock log entry with all relevant information
      final unlockLog = {
        'package_name': packageName, // Always store original package name (for native service)
        'app_name': displayName,     // Human-readable name (for user display)
        'unlock_method': 'pin',      // Authentication method used
        'timestamp': DateTime.now().toIso8601String(), // ISO format timestamp
        'success': success,          // Whether unlock was successful
      };

      // Save log entry to secure storage
      await SecureStorageService.saveUnlockLog(unlockLog);
      print("✓ Unlock attempt logged: $displayName");
    } catch (e) {
      print("X Failed to log unlock attempt: $e"); // Log error but don't crash
    }
  }

  // ------------------------------------------------------------
  // ⭐ Helper: Get app info from installed apps
  // ------------------------------------------------------------
  /// Retrieves application information by package name using DeviceApps
  Future<Application?> _getAppInfo(String packageName) async {
    try {
      return await DeviceApps.getApp(packageName);
    } catch (e) {
      print("Error getting app info for $packageName: $e");
      return null; // Return null on error
    }
  }

  // ------------------------------------------------------------

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

  /// Handles digit button presses (0-9)
  /// Updates PIN input, resets idle timer, and triggers verification when PIN is complete
  void _onKeyPressed(String value) async {
    _resetIdleTimer(); // Reset idle timer on user interaction
    if (mounted) {
      await Provider.of<AvatarProvider>(context, listen: false)
          .setExpression(CatExpression.curious); // Set avatar to curious
    }

    setState(() {
      _controller.addDigit(value); // Add digit to controller
      _enteredPin = _controller.code.join(); // Update entered PIN string
    });

    // In authentication mode, auto-verify when 4 digits are entered
    if (!widget.isSetupMode && _enteredPin.length == _pinLength) {
      await Future.delayed(const Duration(milliseconds: 250)); // Brief delay for UX
      _verifyPin(); // Verify the entered PIN
    }
  }

  /// Handles delete/backspace button press
  /// Removes last digit from PIN input and resets idle timer
  void _onDelete() async {
    _resetIdleTimer(); // Reset idle timer on user interaction
    if (mounted) {
      await Provider.of<AvatarProvider>(context, listen: false)
          .setExpression(CatExpression.curious); // Set avatar to curious
    }

    setState(() {
      _controller.deleteDigit(); // Remove last digit
      _enteredPin = _controller.code.join(); // Update entered PIN string
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

  /// Saves new PIN during setup mode
  /// Saves to both backend API and local secure storage
  Future<void> _savePin() async {
    _resetIdleTimer(); // Reset idle timer

    // Validate PIN length
    if (_enteredPin.length != _pinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a 4-digit PIN")), // Show error
      );
      return;
    }

    final avatar = Provider.of<AvatarProvider>(context, listen: false);
    await avatar.setExpression(CatExpression.curious); // Set avatar to curious

    // Save PIN to backend API
    bool saved = await ApiService.savePin("user1", _enteredPin);

    if (saved) {
      // Save PIN and authentication method to local secure storage
      await SecureStorageService.savePin(_enteredPin);
      await SecureStorageService.saveAuthMethod("pin");
      await avatar.setExpression(CatExpression.happy); // Set avatar to happy

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PIN saved successfully!")), // Show success
      );

      await Future.delayed(const Duration(seconds: 1)); // Brief delay for user to see success
      if (mounted) Navigator.pop(context); // Return to previous screen
    } else {
      await avatar.setExpression(CatExpression.sad); // Set avatar to sad
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save PIN.")), // Show error
      );
    }
  }

  // ------------------------------------------------------------
  // VERIFY PIN — Updated with unlock logging
  // ------------------------------------------------------------
  /// Verifies entered PIN against saved PIN in secure storage
  /// Handles both success and failure scenarios with appropriate feedback
  Future<void> _verifyPin() async {
    _resetIdleTimer(); // Reset idle timer
    final avatar = Provider.of<AvatarProvider>(context, listen: false);
    final savedPin = await SecureStorageService.getPin(); // Retrieve saved PIN

    // Check if entered PIN matches saved PIN
    if (savedPin == _enteredPin) {
      await avatar.setExpression(CatExpression.happy); // Set avatar to happy

      // ⭐ Log SUCCESSFUL unlock attempt
      await _logUnlockAttempt(true);

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

      // ⭐ Log FAILED unlock attempt
      await _logUnlockAttempt(false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect PIN.")), // Show error
      );

      // Clear PIN input for retry
      setState(() {
        _controller.clear();
        _enteredPin = "";
      });

      await Future.delayed(const Duration(seconds: 1)); // Brief delay
      await avatar.setExpression(CatExpression.curious); // Reset avatar to curious
    }
  }

  // ------------------------------------------------------------

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

    // Calculate responsive button size and spacing
    final buttonSize = w * 0.19; // Button size as 19% of screen width
    final buttonSpacing = w * 0.045; // Spacing as 4.5% of screen width

    // WillPopScope handles Android hardware back button
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9E9D2), // Light beige background
        appBar: AppBar(
          backgroundColor: const Color(0xFFF9E9D2), // Match background
          elevation: 0, // Remove shadow
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                size: w * 0.07, color: const Color(0xFF553F2B)), // Back arrow
            onPressed: () async {
              await _notifyUnlockCancelled(); // Notify native code
              Navigator.pop(context); // Navigate back
            },
          ),
          title: Text(
            widget.isSetupMode ? "Set PIN" : "Enter PIN", // Dynamic title
            style: GoogleFonts.rye(
                fontSize: w * 0.045, color: const Color(0xFF553F2B)), // Custom font
          ),
          centerTitle: true,
          actions: [
            // Settings button (top-right)
            IconButton(
              icon: Image.asset(
                "assets/ui/settingicon.png", // Custom settings icon
                height: w * 0.07, // Responsive icon size
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            SizedBox(width: w * 0.03), // Right padding
          ],
        ),
        body: SafeArea(
          // Ensure content isn't obscured by notches/system UI
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Even vertical spacing
            children: [
              // Top section: Avatar, app name, and PIN dots
              Column(
                children: [
                  // Avatar image
                  Image.asset(
                    avatar.currentAsset, // Current avatar image
                    width: w * 0.32, // Responsive width
                    height: w * 0.32, // Responsive height (square)
                  ),
                  SizedBox(height: h * 0.012), // Vertical spacing
                  
                  // Display app name if provided (and not a package name)
                  if (!widget.isSetupMode &&
                      widget.appName != null &&
                      !_isPackageName(widget.appName!))
                    Text(
                      "Unlocking ${widget.appName}", // Show readable app name
                      style: const TextStyle(
                        color: Color(0xFF936B46), // Gold text
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  // Generic message for package names
                  if (!widget.isSetupMode &&
                      widget.appName != null &&
                      _isPackageName(widget.appName!))
                    const Text(
                      "Unlocking App", // Generic message
                      style: TextStyle(
                        color: Color(0xFF936B46), // Gold text
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  SizedBox(height: h * 0.012), // Vertical spacing
                  
                  // PIN indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _controller.code.length; // Dot filled if digit entered
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150), // Smooth animation
                        margin: const EdgeInsets.all(5), // Dot spacing
                        width: 14, // Dot width
                        height: 14, // Dot height
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, // Circular dots
                          color: filled
                              ? const Color(0xFFD2AE83) // Filled: light brown
                              : const Color(0x33D2AE83), // Empty: light brown with 20% opacity
                        ),
                      );
                    }),
                  ),
                ],
              ),
              
              // Bottom section: Numeric keypad
              Column(
                children: [
                  // Generate 4 rows of buttons
                  for (final row in const [
                    ["1", "2", "3"],
                    ["4", "5", "6"],
                    ["7", "8", "9"],
                    ["0", "del"] // Last row has 0 and delete
                  ])
                    Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: buttonSpacing / 2), // Row spacing
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: row.map((value) {
                          if (value == "del") {
                            // Delete/backspace button
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: buttonSpacing / 2),
                              child: _circleButton(
                                size: buttonSize,
                                onTap: _onDelete,
                                child: const Icon(Icons.backspace,
                                    size: 25, color: Color(0xFF553F2B)), // Backspace icon
                              ),
                            );
                          }
                          // Numeric button (0-9)
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: buttonSpacing / 2),
                            child: _circleButton(
                              size: buttonSize,
                              onTap: () => _onKeyPressed(value), // Handle digit press
                              child: Text(
                                value,
                                style: GoogleFonts.rye(
                                    fontSize: 25,
                                    color: const Color(0xFF553F2B)), // Custom font
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Save button (only shown in setup mode)
        bottomNavigationBar: widget.isSetupMode
            ? Padding(
                padding:
                    EdgeInsets.fromLTRB(w * 0.18, 0, w * 0.18, h * 0.02), // Responsive padding
                child: SizedBox(
                  height: 55, // Fixed button height
                  child: ElevatedButton(
                    onPressed: _savePin, // Save PIN when pressed
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9E9D2), // Light beige background
                      foregroundColor: const Color(0xFF553F2B), // Dark brown text
                      elevation: 2, // Subtle shadow
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Rounded corners
                        side: const BorderSide(
                            color: Color(0xFF553F2B), width: 1.2), // Dark brown border
                      ),
                    ),
                    child: Text("Save PIN",
                        style: GoogleFonts.rye(fontSize: 18)), // Custom font
                  ),
                ),
              )
            : null, // No bottom bar in authentication mode
      ),
    );
  }

  /// Helper widget for circular keypad buttons
  /// Creates a circular button with shadow and tap interaction
  Widget _circleButton({
    required double size, // Button diameter
    required Widget child, // Button content (text or icon)
    required VoidCallback onTap, // Tap callback
  }) {
    return InkWell(
      onTap: onTap, // Handle tap
      customBorder: const CircleBorder(), // Circular tap area
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle, // Circular button
          color: Colors.white, // White background
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(2, 3)) // Subtle shadow
          ],
        ),
        child: child, // Button content
      ),
    );
  }
}