// Import required Flutter packages
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:flutter_overlay_window/flutter_overlay_window.dart'; // For creating system overlay windows

/// OverlayBlockScreen - System overlay window that appears when a locked app is accessed
/// This widget creates a semi-transparent overlay that blocks access to locked applications
/// It appears on top of other apps using Android's overlay window permission
class OverlayBlockScreen extends StatelessWidget {
  const OverlayBlockScreen({super.key}); // Constructor with optional key parameter

  @override
  Widget build(BuildContext context) {
    // Main scaffold widget that provides the basic visual structure for the overlay
    return Scaffold(
      // Semi-transparent black background to dim the underlying app
      backgroundColor: Colors.black.withOpacity(0.7), // 70% opacity black
      body: Center(
        // Center widget to position content in the middle of the screen
        child: Container(
          padding: const EdgeInsets.all(24), // Internal spacing inside the container
          decoration: BoxDecoration(
            color: Colors.white, // White background for the message box
            borderRadius: BorderRadius.circular(20), // Rounded corners (20px radius)
          ),
          // Text message displayed to the user
          child: const Text(
            "🔒 This app is locked by AppLock+", // Lock emoji + explanatory text
            style: TextStyle(fontSize: 18, color: Colors.black), // Font size and color
          ),
        ),
      ),
    );
  }
}