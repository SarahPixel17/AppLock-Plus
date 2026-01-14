// Import required Flutter packages and application components
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:flutter/services.dart'; // For MethodChannel and platform communication
import 'package:provider/provider.dart'; // For state management using Provider pattern
import 'passcode_screen.dart'; // Screen for PIN code authentication
import 'pattern_screen.dart'; // Screen for pattern authentication
import 'services/secure_storage_service.dart'; // Service for secure storage of authentication preferences

// Add these imports for additional providers
import 'profile/avatar_provider.dart'; // Provider for managing avatar state
import 'time_locks_controller.dart'; // Controller for managing time-based lock rules
import 'location_locks_controller.dart'; // Controller for managing location-based lock rules
import 'locked_apps_controller.dart'; // Controller for managing manually locked apps

/// UnlockEntrypoint - Special entry point for the unlock interface
/// This widget is launched by native Android UnlockActivity when a locked app is accessed
/// It bypasses the normal app startup and directly shows authentication screen for the locked app
class UnlockEntrypoint extends StatefulWidget {
  const UnlockEntrypoint({Key? key}) : super(key: key); // Constructor with optional key parameter

  @override
  State<UnlockEntrypoint> createState() => _UnlockEntrypointState();
}

/// State class for UnlockEntrypoint
/// Manages communication with native code and displays appropriate authentication screen
class _UnlockEntrypointState extends State<UnlockEntrypoint> {
  // MethodChannel for communicating with native Android unlock activity
  static const MethodChannel _channel = MethodChannel('applock/unlock');
  
  // Package name of the app that triggered the unlock request
  String _lockedPackage = 'unknown';
  
  // Flag to indicate if we're still loading package information from native code
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUnlock(); // Initialize unlock process when widget is created
  }

  /// Initialize unlock interface by communicating with native Android code
  /// Retrieves the package name of the app that needs to be unlocked
  Future<void> _initializeUnlock() async {
    try {
      // Get the locked package from native UnlockActivity
      // This is the app that was just opened and needs authentication
      final String? package = await _channel.invokeMethod<String>('getLockedPackage');

      // Update state with the retrieved package name
      setState(() {
        _lockedPackage = package ?? 'unknown'; // Use 'unknown' as fallback
        _isLoading = false; // Update loading state
      });
      debugPrint("UnlockEntrypoint: Loaded locked package: $_lockedPackage");
    } catch (e) {
      // Handle errors in communication with native code
      debugPrint("Error getting locked package: $e");
      setState(() {
        _isLoading = false; // Still update loading state even on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set up MultiProvider to provide all necessary controllers to the authentication screens
    // This is needed because UnlockEntrypoint creates its own widget tree separate from main app
    return MultiProvider(
      providers: [
        // Avatar provider for avatar state management
        ChangeNotifierProvider<AvatarProvider>(
          create: (context) => AvatarProvider()..load(), // Create and immediately load avatar
        ),
        // Time locks controller for time-based restriction checks
        ChangeNotifierProvider<TimeLocksController>(
          create: (context) => TimeLocksController()..loadTimeLocks(), // Create and load time locks
        ),
        // Location locks controller for location-based restriction checks
        ChangeNotifierProvider<LocationLocksController>(
          create: (context) => LocationLocksController()..loadLocationLocks(), // Create and load location locks
        ),
        // Locked apps controller for manual app lock checks
        ChangeNotifierProvider<LockedAppsController>(
          create: (context) => LockedAppsController()..loadLockedApps(), // Create and load locked apps
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false, // ADD THIS LINE - Hide debug banner in release mode
        theme: ThemeData(
          primarySwatch: Colors.brown, // Brown color theme
          scaffoldBackgroundColor: const Color(0xFFF9E9D2), // Light beige background
        ),
        // Conditional home screen based on loading state
        home: _isLoading ? _buildLoading() : _buildUnlock(),
      ),
    );
  }

  /// Build loading screen while communicating with native code
  /// Shows a progress indicator and loading text
  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2), // Light beige background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF936B46)), // Gold loading indicator
            const SizedBox(height: 20), // Vertical spacing
            const Text('Loading...', style: TextStyle(color: Color(0xFF553F2B))), // Dark brown text
          ],
        ),
      ),
    );
  }

  /// Build the appropriate unlock screen based on user's authentication method
  /// Uses FutureBuilder to asynchronously determine which authentication method to use
  Widget _buildUnlock() {
    return FutureBuilder<String?>(
      // Get user's preferred authentication method from secure storage
      future: SecureStorageService.getAuthMethod(),
      builder: (context, snapshot) {
        // Show loading screen while waiting for authentication method
        if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();
        
        // Determine authentication method, default to 'pin' if none found
        final method = snapshot.data ?? 'pin';
        
        // Return appropriate authentication screen based on user preference
        if (method == 'pattern') {
          // Pattern authentication screen
          return PatternScreen(
            isSetupMode: false, // Authentication mode (not setup)
            appName: _lockedPackage, // Pass the locked app package name
          );
        } else {
          // PIN authentication screen (default)
          return PasscodeScreen(
            isSetupMode: false, // Authentication mode (not setup)
            appName: _lockedPackage, // Pass the locked app package name
            key: UniqueKey(), // Unique key ensures fresh state for each unlock attempt
          );
        }
      },
    );
  }
}