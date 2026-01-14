// Import required Flutter packages and dependencies
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:provider/provider.dart'; // For state management using Provider pattern
import 'package:google_fonts/google_fonts.dart'; // For custom Google Fonts integration

// Import application screens
import 'passcode_screen.dart'; // Screen for PIN code setup/authentication
import 'pattern_screen.dart'; // Screen for pattern setup/authentication
import 'settings_screen.dart'; // Screen for application settings

// Import avatar/profile related components
import '../profile/avatar_provider.dart'; // Provider for managing avatar state (character and expression)
import '../widgets/animated_cat_avatar.dart'; // Animated cat avatar widget for visual feedback

/// AuthSetupScreen - Main screen for setting up authentication methods (PIN or Pattern)
/// This screen allows users to choose between setting up a PIN or Pattern lock
/// Displays an animated avatar and provides navigation to authentication setup screens
class AuthSetupScreen extends StatelessWidget {
  const AuthSetupScreen({super.key}); // Constructor with optional key parameter

  @override
  Widget build(BuildContext context) {
    // Get the current avatar state from AvatarProvider using Provider pattern
    final avatarProvider = context.watch<AvatarProvider>();
    
    // Get device screen dimensions for responsive design
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Base design width for scaling calculations (reference design width)
    const designWidth = 1080.0;
    // Calculate scaling factor based on current screen width relative to design width
    final scale = screenWidth / designWidth;

    // Define text style for buttons using Google Fonts with responsive font size
    final buttonTextStyle = GoogleFonts.rye(
      fontSize: 52 * scale, // Scale font size based on screen width
      color: const Color(0xFF553F2B), // Dark brown color matching theme
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
            /// Full-screen decorative background image
            Positioned.fill(
              child: Image.asset(
                'assets/ui/setauthenticationnew.png', // Path to background image asset
                fit: BoxFit.cover, // Cover entire screen while maintaining aspect ratio
              ),
            ),

            /// ⬅️ BACK BUTTON
            /// Navigation button to return to previous screen
            Positioned(
              top: 8, // Position from top of screen
              left: 8, // Position from left of screen
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back, // Back arrow icon
                  color: const Color(0xFF936B46), // Medium brown color
                  size: screenWidth * 0.085, // Responsive icon size (8.5% of screen width)
                ),
                onPressed: () => Navigator.pop(context), // Navigate back when pressed
              ),
            ),

            /// ⚙️ SETTINGS BUTTON
            /// Navigation button to access application settings
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
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ),

            /// 🐱 ANIMATED CAT AVATAR (DO NOT MOVE - Positioned based on design spec)
            /// Central interactive avatar that responds to authentication choices
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

            /// 🔘 AUTHENTICATION BUTTONS
            /// Column containing PIN and Pattern setup buttons
            Positioned(
              left: 0, // Align to left edge
              right: 0, // Align to right edge
              top: screenHeight * 0.64, // Position at 64% of screen height from top
              child: Column(
                // Vertical arrangement of buttons
                children: [
                  /// 🔐 SET PIN BUTTON
                  /// Button to navigate to PIN setup screen
                  SizedBox(
                    width: screenWidth * 0.88, // 88% of screen width
                    height: 58, // Fixed height in logical pixels
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to PasscodeScreen in setup mode
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PasscodeScreen(isSetupMode: true), // Setup mode flag
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // White button background
                        elevation: 4, // Shadow elevation for depth
                        shadowColor: Colors.black26, // Semi-transparent black shadow
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18), // Rounded corners
                        ),
                      ),
                      child: Text("Set PIN", style: buttonTextStyle), // Button text with custom style
                    ),
                  ),

                  /// ✅ VERTICAL SPACER BETWEEN BUTTONS
                  /// Improved spacing for better visual separation and touch targets
                  const SizedBox(height: 20),

                  /// 🔑 SET PATTERN BUTTON
                  /// Button to navigate to Pattern setup screen
                  SizedBox(
                    width: screenWidth * 0.88, // 88% of screen width (matches PIN button)
                    height: 58, // Fixed height in logical pixels (matches PIN button)
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to PatternScreen in setup mode
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PatternScreen(isSetupMode: true), // Setup mode flag
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // White button background
                        elevation: 4, // Shadow elevation for depth
                        shadowColor: Colors.black26, // Semi-transparent black shadow
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18), // Rounded corners
                        ),
                      ),
                      child: Text("Set Pattern", style: buttonTextStyle), // Button text with custom style
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}