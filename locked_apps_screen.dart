// Import required Flutter packages, Google Fonts, state management, and application components
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:google_fonts/google_fonts.dart'; // For custom Google Fonts integration
import 'package:provider/provider.dart'; // For state management using Provider pattern
import '../services/api_service.dart'; // Service for API communication with backend
import '../services/secure_storage_service.dart'; // Service for secure storage of authentication preferences
import '../profile/avatar_provider.dart'; // Provider for managing avatar state
import 'passcode_screen.dart'; // Screen for PIN code authentication
import 'pattern_screen.dart'; // Screen for pattern authentication

/// LockedAppsScreen - Screen that displays all manually locked applications
/// Shows a list of apps that have been manually locked by the user
/// Allows users to tap on apps to check lock status and potentially authenticate
class LockedAppsScreen extends StatefulWidget {
  const LockedAppsScreen({super.key}); // Constructor with optional key parameter

  @override
  State<LockedAppsScreen> createState() => _LockedAppsScreenState();
}

/// State class for LockedAppsScreen
/// Manages loading state, locked apps data, and user interactions
class _LockedAppsScreenState extends State<LockedAppsScreen> {
  // Hardcoded username - TODO: replace with actual logged-in user's username
  final String username = "user1"; // Replace with dynamic username if you have login
  
  // State variables for managing loading state and locked apps data
  bool _isLoading = true; // Flag to indicate data is being loaded
  List<Map<String, dynamic>> _lockedApps = []; // List to store locked apps data

  @override
  void initState() {
    super.initState();
    _loadLockedApps(); // Load locked apps when screen initializes
  }

  /// Load locked apps from the API
  /// Fetches the list of manually locked apps for the current user
  Future<void> _loadLockedApps() async {
    setState(() => _isLoading = true); // Show loading indicator
    final apps = await ApiService.getLockedApps(username); // Fetch from API
    setState(() {
      _lockedApps = apps; // Update state with fetched data
      _isLoading = false; // Hide loading indicator
    });
  }

  /// Handle tap on a locked app item
  /// Checks if app is currently locked and navigates to appropriate authentication screen
  /// 
  /// @param appName - The name of the app that was tapped
  Future<void> _handleAppTap(String appName) async {
    // Get avatar provider to update avatar expression based on user action
    final avatarProvider = context.read<AvatarProvider>();
    await avatarProvider.setExpression(CatExpression.curious); // Set avatar to curious expression

    // Check if the app is currently locked (may have time/location based restrictions)
    final isLocked = await ApiService.isAppCurrentlyLocked(username, appName);

    // If app is locked, navigate to authentication screen
    if (isLocked) {
      // Get user's preferred authentication method from secure storage
      final authMethod = await SecureStorageService.getAuthMethod();

      // Navigate to appropriate authentication screen based on user preference
      if (authMethod == "pin") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PasscodeScreen(isSetupMode: false), // Authentication mode (not setup)
          ),
        );
      } else if (authMethod == "pattern") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PatternScreen(isSetupMode: false), // Authentication mode (not setup)
          ),
        );
      } else {
        // No authentication method set - show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Please set a PIN or pattern first.")),
        );
      }
    } else {
      // App is not currently locked - show informational message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ $appName is not locked right now.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get avatar provider for displaying current avatar state
    final avatarProvider = context.watch<AvatarProvider>();
    
    // Get device screen dimensions for responsive design
    final size = MediaQuery.of(context).size;
    final w = size.width; // Screen width
    final h = size.height; // Screen height

    // Main scaffold widget that provides the basic visual structure
    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2), // Light beige background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9E9D2), // Match background color
        elevation: 0, // Remove shadow for flat design
        title: Text(
          "Locked Apps", // Screen title
          style: GoogleFonts.rye( // Custom font from Google Fonts
            fontSize: w * 0.05, // Responsive font size (5% of screen width)
            color: const Color(0xFF553F2B), // Dark brown text color
          ),
        ),
        centerTitle: true, // Center the title text
      ),
      // Conditional body based on loading state and data availability
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF553F2B))) // Loading indicator
          : _lockedApps.isEmpty
              ? Center( // Empty state when no locked apps
                  child: Text(
                    "No locked apps yet!", // Empty state message
                    style: GoogleFonts.rye(
                      fontSize: w * 0.045, // Responsive font size (4.5% of screen width)
                      color: const Color(0xFF553F2B), // Dark brown text color
                    ),
                  ),
                )
              : Padding( // List view when locked apps exist
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05), // Horizontal padding (5% of screen width)
                  child: ListView.builder(
                    itemCount: _lockedApps.length, // Number of items in the list
                    itemBuilder: (context, index) {
                      final app = _lockedApps[index]; // Get app at current index
                      final appName = app["app_name"]; // Extract app name from data

                      // Card widget for each locked app
                      return Card(
                        color: const Color(0xFFFFFFFF), // White card background
                        elevation: 3, // Shadow elevation for depth
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Rounded corners
                        ),
                        margin: EdgeInsets.symmetric(vertical: h * 0.01), // Vertical margin (1% of screen height)
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: w * 0.05, // Horizontal padding (5% of screen width)
                            vertical: h * 0.01, // Vertical padding (1% of screen height)
                          ),
                          // Leading widget: avatar image
                          leading: Image.asset(
                            avatarProvider.currentAsset, // Current avatar image from provider
                            width: w * 0.12, // Responsive width (12% of screen width)
                            height: w * 0.12, // Responsive height (12% of screen width - square aspect)
                          ),
                          // Title: app name
                          title: Text(
                            appName,
                            style: GoogleFonts.rye(
                              fontSize: w * 0.045, // Responsive font size (4.5% of screen width)
                              color: const Color(0xFF553F2B), // Dark brown text color
                            ),
                          ),
                          // Trailing icon: lock symbol
                          trailing: const Icon(
                            Icons.lock_outline, // Lock icon
                            color: Color(0xFF936B46), // Gold/accent color
                          ),
                          // Handle tap on the list item
                          onTap: () => _handleAppTap(appName),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}