// Import required Flutter packages, state management, and custom fonts
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:provider/provider.dart'; // For state management using Provider pattern
import 'package:google_fonts/google_fonts.dart'; // For custom Google Fonts integration

// Import application screens for navigation
import 'auth_setup_screen.dart'; // Screen for setting up authentication methods (PIN/Pattern)
import 'time_lock_config_screen.dart'; // Screen for configuring time-based app locks
import 'location_lock_config_screen.dart'; // Screen for configuring location-based app locks
import 'view_locked_apps_screen.dart'; // Screen for viewing all locked applications
import 'settings_screen.dart'; // Screen for application settings and preferences

// Import avatar/profile related components
import '../profile/avatar_provider.dart'; // Provider for managing avatar state (character and expression)
import '../widgets/animated_cat_avatar.dart'; // Animated cat avatar widget for visual feedback

// Import services and controllers for application functionality
import 'services/app_monitor_service.dart'; // Service for monitoring app usage and enforcing locks
import 'services/permission_service.dart'; // Service for handling runtime permission requests
import 'time_locks_controller.dart'; // Controller for managing time-based lock rules
import 'location_locks_controller.dart'; // Controller for managing location-based lock rules
import 'locked_apps_controller.dart'; // Controller for managing manually locked apps

/// MainPage - Primary home screen of the AppLock+ application
/// Provides navigation to all major features and displays the animated avatar
class MainPage extends StatefulWidget {
  const MainPage({super.key}); // Constructor with optional key parameter

  @override
  State<MainPage> createState() => _MainPageState();
}

/// State class for MainPage
/// Manages app monitoring lifecycle and builds the main menu UI
class _MainPageState extends State<MainPage> {
  // Flag to track if app monitoring service has been started
  // Prevents multiple initializations of the monitoring service
  bool _monitoringStarted = false;

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to execute code after the first frame is built
    // This ensures the UI is ready before starting background services
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Request all necessary runtime permissions (location, notifications, usage access)
      await PermissionService.requestAllPermissions(context);

      // Start app monitoring service if not already started
      if (!_monitoringStarted) {
        AppMonitorService.startMonitoring(
          context, // BuildContext for navigation and UI operations
          context.read<TimeLocksController>(), // Access time locks controller
          context.read<LocationLocksController>(), // Access location locks controller
          context.read<LockedAppsController>(), // Access locked apps controller
        );
        _monitoringStarted = true; // Update flag to prevent duplicate starts
      }
    });
  }

  @override
  void dispose() {
    // Stop app monitoring service when screen is disposed
    // This is important to free up resources when app is closed
    AppMonitorService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the current avatar state from AvatarProvider using Provider pattern
    final avatarProvider = context.watch<AvatarProvider>();
    
    // Get device screen width for responsive design calculations
    final screenWidth = MediaQuery.of(context).size.width;

    // Base design width for scaling calculations (reference design width)
    const designWidth = 1080.0;
    // Calculate scaling factor based on current screen width relative to design width
    final scale = screenWidth / designWidth;

    // Define text style for menu buttons using Google Fonts with responsive font size
    final menuTextStyle = GoogleFonts.rye(
      fontSize: 38 * scale, // Scale font size based on screen width
      color: const Color(0xFF553F2B), // Dark brown color matching theme
      height: 1.25, // Line height for better text spacing
    );

    // Main scaffold widget that provides the basic visual structure
    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2), // Light beige background color
      body: SafeArea(
        // SafeArea ensures content is not obscured by device notches or system UI
        child: Stack(
          // Stack allows overlapping widgets (background, buttons, avatar, etc.)
          children: [
            /// 🌸 BACKGROUND IMAGE
            /// Full-screen decorative background image covering the entire screen
            Positioned.fill(
              child: Image.asset(
                'assets/ui/mainmenunew.png', // Path to main menu background image
                fit: BoxFit.cover, // Cover entire screen while maintaining aspect ratio
              ),
            ),

            /// ⚙️ SETTINGS BUTTON
            /// Navigation button to access application settings (top-right corner)
            Positioned(
              top: 8, // Position from top of screen
              right: 8, // Position from right of screen
              child: IconButton(
                icon: Image.asset(
                  'assets/ui/settingicon.png', // Path to custom settings icon
                  height: screenWidth * 0.095, // Responsive icon height (9.5% of screen width)
                ),
                onPressed: () => Navigator.push(
                  // Navigate to SettingsScreen when pressed
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),

            /// 🐱 ANIMATED CAT AVATAR
            /// Central interactive avatar positioned based on design specifications
            Positioned(
              left: 297 * scale, // X position scaled from design spec
              top: 305 * scale, // Y position scaled from design spec
              width: 486 * scale, // Width scaled from design spec
              height: 486 * scale, // Height scaled from design spec
              child: AnimatedCatAvatar(
                // Custom animated avatar widget
                character: avatarProvider.character, // Current character from provider
                expression: avatarProvider.expression, // Current expression from provider
                size: 486 * scale, // Size parameter for internal calculations
              ),
            ),

            /// 🔐 Set Authentication Method Button (Left-side menu option)
            /// Navigates to authentication setup screen (PIN or Pattern)
            _menuTextButton(
              scale: scale, // Scaling factor for responsive positioning
              x: 80, // X position from design spec (before scaling)
              y: 1100, // Y position from design spec (before scaling)
              w: 375, // Width from design spec (before scaling)
              h: 200, // Height from design spec (before scaling)
              text: "Set Authentication\nMethod", // Button text with line breaks
              style: menuTextStyle, // Pre-defined text style
              onTap: () => Navigator.push(
                // Navigate to AuthSetupScreen when pressed
                context,
                MaterialPageRoute(builder: (_) => const AuthSetupScreen()),
              ),
            ),

            /// ⏰ Configure Time-Based Lock Button (Right-side menu option)
            /// Navigates to time-based lock configuration screen
            /// TEXT LOWER: Uses vertical offset to adjust text positioning
            _menuTextButton(
              scale: scale,
              x: 681, // X position from design spec (before scaling)
              y: 1135, // Y position from design spec (before scaling)
              w: 323, // Width from design spec (before scaling)
              h: 200, // Height from design spec (before scaling)
              text: "Configure\nTime-Based\nLock", // Button text with line breaks
              style: menuTextStyle,
              textOffset: const Offset(0, 10), // ✅ DOWN: Vertical offset to adjust text position
              onTap: () => Navigator.push(
                // Navigate to TimeLockConfigScreen when pressed
                context,
                MaterialPageRoute(builder: (_) => const TimeLockConfigScreen()),
              ),
            ),

            /// 📍 Configure Location-Based Lock Button (Bottom-left menu option)
            /// Navigates to location-based lock configuration screen
            _menuTextButton(
              scale: scale,
              x: 190, // X position from design spec (before scaling)
              y: 1845, // Y position from design spec (before scaling)
              w: 320, // Width from design spec (before scaling)
              h: 210, // Height from design spec (before scaling)
              text: "Configure\nLocation-Based\nLock", // Button text with line breaks
              style: menuTextStyle,
              onTap: () => Navigator.push(
                // Navigate to LocationLockConfigScreen when pressed
                context,
                MaterialPageRoute(builder: (_) => const LocationLockConfigScreen()),
              ),
            ),

            /// 🔑 View Locked Apps Button (Bottom-right menu option)
            /// Navigates to screen displaying all manually locked applications
            /// TEXT LEFT: Uses horizontal offset to adjust text positioning
            _menuTextButton(
              scale: scale,
              x: 660, // X position from design spec (before scaling)
              y: 1715, // Y position from design spec (before scaling)
              w: 300, // Width from design spec (before scaling)
              h: 210, // Height from design spec (before scaling)
              text: "View\nLocked\nApps", // Button text with line breaks
              style: menuTextStyle,
              textOffset: const Offset(-12, 0), // ✅ LEFT: Horizontal offset to adjust text position
              onTap: () => Navigator.push(
                // Navigate to ViewLockedAppsScreen when pressed
                context,
                MaterialPageRoute(builder: (_) => const ViewLockedAppsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ FINAL FIX — PIXEL-PERFECT TEXT CONTROL HELPER METHOD
  /// Creates a custom text button with precise positioning and hit detection
  /// This method ensures pixel-perfect alignment across different screen sizes
  /// 
  /// Parameters:
  /// @param scale - Scaling factor for responsive design (screenWidth / designWidth)
  /// @param x - X coordinate from design spec (before scaling)
  /// @param y - Y coordinate from design spec (before scaling)
  /// @param w - Width from design spec (before scaling)
  /// @param h - Height from design spec (before scaling)
  /// @param text - Button text (can contain line breaks with \n)
  /// @param style - Text style including font, size, and color
  /// @param onTap - Callback function when button is tapped
  /// @param textOffset - Optional offset for fine-tuning text position (defaults to Offset.zero)
  Widget _menuTextButton({
    required double scale,
    required double x,
    required double y,
    required double w,
    required double h,
    required String text,
    required TextStyle style,
    required VoidCallback onTap,
    Offset textOffset = Offset.zero, // Default to no offset
  }) {
    return Positioned(
      left: x * scale, // Apply scaling to X position
      top: y * scale, // Apply scaling to Y position
      width: w * scale, // Apply scaling to width
      height: h * scale, // Apply scaling to height
      child: GestureDetector(
        behavior: HitTestBehavior.translucent, // Allow taps on transparent areas
        onTap: onTap, // Execute provided callback when tapped
        child: Align(
          alignment: Alignment.center, // Center content within the positioned area
          child: Transform.translate(
            // Apply text offset for fine-tuning (also scaled)
            offset: Offset(
              textOffset.dx * scale, // Scale horizontal offset
              textOffset.dy * scale, // Scale vertical offset
            ),
            child: Text(
              text,
              textAlign: TextAlign.center, // Center align text within the button
              softWrap: true, // Allow text to wrap to multiple lines
              maxLines: 4, // Maximum number of lines (prevents overflow)
              overflow: TextOverflow.visible, // Allow text to be visible even if it overflows
              style: style, // Apply provided text style
            ),
          ),
        ),
      ),
    );
  }
}