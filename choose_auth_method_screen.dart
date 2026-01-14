// Import required Flutter packages and application screens
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import '../services/api_service.dart'; // Service for API communication with backend
import 'passcode_screen.dart'; // Screen for PIN code setup
import 'pattern_screen.dart'; // Screen for pattern setup

/// ChooseAuthMethodScreen - Screen for selecting authentication method (PIN or Pattern)
/// This screen allows users to choose their preferred unlock method before setup
/// It communicates with the backend to save the user's preference
class ChooseAuthMethodScreen extends StatefulWidget {
  const ChooseAuthMethodScreen({super.key}); // Constructor with optional key parameter

  @override
  State<ChooseAuthMethodScreen> createState() => _ChooseAuthMethodScreenState();
}

/// State class for ChooseAuthMethodScreen
/// Manages loading state and handles authentication method selection
class _ChooseAuthMethodScreenState extends State<ChooseAuthMethodScreen> {
  // Loading state to show progress indicator during API calls
  bool _loading = false;
  
  // Hardcoded username - TODO: replace with actual logged-in user's username
  final String username = "user1";

  /// Handles the selection of an authentication method
  /// Sends the selected method to the backend and navigates to appropriate setup screen
  /// 
  /// @param method - The authentication method ("pin" or "pattern")
  Future<void> _chooseMethod(String method) async {
    // Set loading state to true to show progress indicator
    setState(() => _loading = true);
    
    // Call API service to save the authentication method preference
    final success = await ApiService.setAuthMethod(username, method);
    
    // Set loading state back to false when API call completes
    setState(() => _loading = false);

    // Check if widget is still mounted before updating state
    if (!mounted) return;

    // Handle successful method selection
    if (success) {
      // Show success notification using SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ $method selected as unlock method")),
      );

      // Navigate to the appropriate setup screen based on selected method
      if (method == "pin") {
        // Navigate to PIN setup screen in setup mode
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PasscodeScreen(isSetupMode: true)),
        );
      } else {
        // Navigate to Pattern setup screen in setup mode
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatternScreen(isSetupMode: true)),
        );
      }
    } else {
      // Show error notification if API call failed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to save selection")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define color constants for consistent theme
    const brown = Color(0xFF553F2B); // Dark brown color for text
    const accent = Color(0xFF936B46); // Medium brown accent color
    
    // Main scaffold widget that provides the basic visual structure
    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2), // Light beige background color
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9E9D2), // Match background color
        elevation: 0, // Remove shadow for flat design
        centerTitle: true, // Center the title text
        title: const Text(
          "Choose Unlock Method", // Screen title
          style: TextStyle(color: brown, fontWeight: FontWeight.bold), // Styled text
        ),
      ),
      body: Center(
        // Center content vertically and horizontally
        child: _loading
            // Show loading indicator when making API call
            ? const CircularProgressIndicator(color: accent)
            // Show method selection buttons when not loading
            : Column(
                mainAxisAlignment: MainAxisAlignment.center, // Center column vertically
                children: [
                  // Instruction text for user
                  const Text(
                    "Select your preferred unlock method:",
                    style: TextStyle(fontSize: 20, color: brown), // Styled text
                    textAlign: TextAlign.center, // Center align text
                  ),
                  const SizedBox(height: 40), // Vertical spacing
                  
                  // PIN Method Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent, // Button background color
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), // Button padding
                    ),
                    icon: const Icon(Icons.lock_outline), // Lock icon
                    label: const Text("Use PIN", style: TextStyle(fontSize: 18)), // Button text
                    onPressed: () => _chooseMethod("pin"), // Call method with "pin" parameter
                  ),
                  
                  const SizedBox(height: 20), // Vertical spacing between buttons
                  
                  // Pattern Method Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent, // Button background color
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), // Button padding
                    ),
                    icon: const Icon(Icons.fingerprint), // Fingerprint/pattern icon
                    label: const Text("Use Pattern", style: TextStyle(fontSize: 18)), // Button text
                    onPressed: () => _chooseMethod("pattern"), // Call method with "pattern" parameter
                  ),
                ],
              ),
      ),
    );
  }
}