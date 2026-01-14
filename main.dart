// Import required Dart and Flutter packages for async operations, UI, platform integration, state management, and storage 
import 'dart:async'; // For Timer and asynchronous operations
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design
import 'package:flutter/services.dart'; // For MethodChannel and platform communication
import 'package:provider/provider.dart'; // For state management using Provider pattern
import 'package:shared_preferences/shared_preferences.dart'; // For simple local storage of non-sensitive data

// Import application screens
import 'main_page.dart'; // Main home screen of the application
import 'profile/avatar_provider.dart'; // Provider for managing avatar state
import 'permissions/permissions_setup_screen.dart'; // Screen for initial permission setup

// Import application controllers (state managers)
import 'time_locks_controller.dart'; // Controller for managing time-based lock rules
import 'location_locks_controller.dart'; // Controller for managing location-based lock rules
import 'locked_apps_controller.dart'; // Controller for managing manually locked apps

// Import application services
import 'services/notification_service.dart'; // Service for handling local notifications
import 'services/background_service.dart'; // Service for background checks and enforcement
import 'services/secure_storage_service.dart'; // Service for secure, encrypted storage

// Import unlock entry point (for handling unlock requests from native)
import 'unlock_entrypoint.dart'; // Special entry point for unlock interface

/// Main entry point of the AppLock+ application
/// Handles both normal app startup and unlock interface startup
void main() async {
  // Ensure Flutter binding is initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service for displaying local notifications
  await NotificationService.init();

  // Check if we're being launched by UnlockActivity (native Android unlock screen)
  try {
    const channel = MethodChannel('applock/unlock'); // Correct unlock channel for native communication
    final package = await channel.invokeMethod<String>('getLockedPackage'); // Get package name from native

    if (package != null && package.isNotEmpty) {
      // Directly launch unlock interface (bypasses normal app startup)
      runApp(const UnlockEntrypoint());
      return; // Exit main() to prevent normal app startup
    }
  } catch (e) {
    // Not launched by UnlockActivity, proceed with normal startup
    debugPrint("Not launched by UnlockActivity: $e");
  }

  // Normal app startup (not triggered by unlock request)
  runApp(const MyApp());
}

/// MyApp - Root widget of the application
/// Sets up theme, providers, and initial navigation based on app state
class MyApp extends StatefulWidget {
  const MyApp({super.key}); // Constructor with optional key parameter

  @override
  State<MyApp> createState() => _MyAppState();

  /// ✅ Start location monitoring service (background service)
  static Future<void> startLocationMonitoring() async {
    try {
      const channel = MethodChannel('applock/location_service');
      await channel.invokeMethod('startLocationService');
      debugPrint("✅ Location monitoring service started");
    } catch (e) {
      debugPrint("❌ Failed to start location service: $e");
    }
  }
}

/// State class for MyApp
/// Manages app initialization, loading state, and first launch detection
class _MyAppState extends State<MyApp> {
  bool _isLoading = true; // Flag to indicate app is initializing
  bool _firstLaunchDone = false; // Flag to track if this is the first app launch

  @override
  void initState() {
    super.initState();
    _initializeApp(); // Start app initialization when widget is created
  }

  /// Initialize the application
  /// Loads preferences, starts background service, and determines if first launch
  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _firstLaunchDone = prefs.getBool("first_launch_done") ?? false; // Check if first launch completed

      // Start background service only for main app, not for unlock interface
      // This service handles periodic checks for time/location-based locks
      await BackgroundService.start();

      setState(() {
        _isLoading = false; // Update state to indicate initialization complete
      });
    } catch (e) {
      debugPrint("App initialization failed: $e");
      setState(() {
        _isLoading = false; // Still set loading to false even on error
      });
    }
  }

  // Define color constants for the application theme
  static const Color kBg = Color(0xFFF9E9D2); // Light beige background
  static const Color kText = Color(0xFF553F2B); // Dark brown text
  static const Color kAccent = Color(0xFF936B46); // Gold/accent color

  @override
  Widget build(BuildContext context) {
    // Show loading screen during initialization
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false, // Hide debug banner in release mode
        home: Scaffold(
          backgroundColor: kBg, // Use theme background color
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF936B46)), // Gold loading indicator
                const SizedBox(height: 20), // Spacing between indicator and text
                Text(
                  'AppLock+', // App name during loading
                  style: TextStyle(
                    fontSize: 24,
                    color: kText, // Dark brown text
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Define the main application theme with custom colors and styling
    final theme = ThemeData(
      useMaterial3: true, // Use Material 3 design system
      scaffoldBackgroundColor: kBg, // Set global background color
      fontFamily: 'Lancelot', // Custom font for medieval/royal feel
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: kText), // Default text color
        titleMedium: TextStyle(color: kText), // Title text color
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBg, // Match app background
        elevation: 0, // Remove shadow for flat design
        foregroundColor: kAccent, // Icon and action color
        centerTitle: true, // Center app bar title
        titleTextStyle: TextStyle(
          fontFamily: 'Lancelot', // Custom font for app bar
          fontSize: 22,
          color: kText, // Dark brown text
          fontWeight: FontWeight.w600, // Semi-bold
        ),
        iconTheme: IconThemeData(color: kAccent), // Gold icons
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: kAccent)
          .copyWith(background: kBg, primary: kAccent), // Color scheme based on accent
      inputDecorationTheme: InputDecorationTheme(
        filled: true, // Fill input backgrounds
        fillColor: Colors.white, // White background for inputs
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Rounded corners
          borderSide: const BorderSide(color: Color(0xFF936B46)), // Gold border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Rounded corners
          borderSide: const BorderSide(color: Color(0xFF936B46)), // Gold border
        ),
      ),
    );

    // Setup MultiProvider to make all controllers available throughout the app
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AvatarProvider>(
          create: (context) => AvatarProvider()..load(),
        ),
        ChangeNotifierProvider<TimeLocksController>(
          create: (context) => TimeLocksController()..loadTimeLocks(),
        ),
        ChangeNotifierProvider<LocationLocksController>(
          create: (context) => LocationLocksController()..loadLocationLocks(),
        ),
        ChangeNotifierProvider<LockedAppsController>(
          create: (context) => LockedAppsController()..loadLockedApps(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AppLock+',
        theme: theme,
        home: _firstLaunchDone
            ? const MainPage()
            : const PermissionsSetupScreen(),
      ),
    );
  }
}
