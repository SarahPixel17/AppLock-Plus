// Import required Flutter and plugin packages
import 'package:flutter/material.dart'; // For Color class and debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // For local notifications
import 'secure_storage_service.dart'; // Custom service for secure storage operations

/// Notification service for managing local notifications in the AppLock+ application
/// Handles both general notifications and location-based alerts with separate channels
class NotificationService {
  // Static instance of the FlutterLocalNotificationsPlugin for managing notifications
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notification channels and plugin
  /// Sets up notification channels for Android 8.0+ (Oreo) and initializes the plugin
  static Future<void> init() async {
    // Android-specific initialization settings with app icon reference
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // General initialization settings (currently Android only, can add iOS later)
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    // Initialize the notifications plugin with the settings
    await _notifications.initialize(initSettings);

    // Create notification channels explicitly for Android 8.0+ (required for Oreo and above)
    
    // General notification channel for app events (locks, settings, etc.)
    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      'applock_general', // Channel ID - must be unique
      'AppLock+ Notifications', // Channel name shown to users
      description: 'General notifications for AppLock+ (e.g., locks, settings)', // Channel description
      importance: Importance.high, // High importance for notifications
    );

    // Specialized channel for location-based alerts
    const AndroidNotificationChannel locationChannel =
        AndroidNotificationChannel(
      'applock_location', // Channel ID - must be unique
      'AppLock+ Location Alerts', // Channel name shown to users
      description: 'Location-based lock/unlock alerts for AppLock+', // Channel description
      importance: Importance.high, // High importance for notifications
    );

    // Register the notification channels with the Android system
    // Note: resolvePlatformSpecificImplementation is used to get Android-specific plugin
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(generalChannel);
    await androidPlugin?.createNotificationChannel(locationChannel);
  }

  /// Check if notifications are enabled by the user
  /// Reads the notification setting from secure storage
  /// Returns true by default if there's an error reading the setting
  static Future<bool> _areNotificationsEnabled() async {
    try {
      // Check the notification preference stored in secure storage
      return await SecureStorageService.isNotificationsEnabled();
    } catch (e) {
      // Log the error and default to enabled to ensure notifications work
      debugPrint("Error checking notification settings: $e");
      return true; // Default to enabled if there's an error
    }
  }

  /// General-purpose notification for app events
  /// Shows notifications for general AppLock+ events like lock activations
  static Future<void> showNotification({
    required String title, // Title of the notification
    required String body, // Body text of the notification
  }) async {
    try {
      // Check if notifications are enabled before proceeding
      if (!await _areNotificationsEnabled()) {
        debugPrint("Notifications are disabled, skipping: $title");
        return; // Exit early if notifications are disabled
      }

      // Android-specific notification details for the general channel
      const androidDetails = AndroidNotificationDetails(
        'applock_general', // Channel ID (must match created channel)
        'AppLock+ Notifications', // Channel name
        channelDescription: 'General notifications for AppLock+ events', // Channel description
        importance: Importance.max, // Maximum importance for notification
        priority: Priority.high, // High priority for delivery
        enableVibration: true, // Enable vibration
        playSound: true, // Enable sound
        styleInformation: BigTextStyleInformation(''), // Style for large text (empty for default)
      );

      // Platform-agnostic notification details wrapper
      const details = NotificationDetails(android: androidDetails);

      // Show the notification with ID 0 (can be changed for multiple notifications)
      await _notifications.show(
        0, // Notification ID (0 for general notifications)
        title,
        body,
        details,
      );
      debugPrint("Notification shown: $title");
    } catch (e) {
      // Log any errors that occur during notification display
      debugPrint("Error showing notification: $e");
    }
  }

  /// Location-based notification for geographic triggers
  /// Shows specialized notifications for location-based lock/unlock events
  static Future<void> showLocationNotification({
    required String title, // Title of the location notification
    required String body, // Body text of the location notification
  }) async {
    try {
      // Check if notifications are enabled before proceeding
      if (!await _areNotificationsEnabled()) {
        debugPrint("Notifications are disabled, skipping location notification: $title");
        return; // Exit early if notifications are disabled
      }

      // Android-specific notification details for the location channel
      final androidDetails = AndroidNotificationDetails(
        'applock_location', // Channel ID (must match created channel)
        'AppLock+ Location Alerts', // Channel name
        channelDescription: 'Location-based lock/unlock alerts', // Channel description
        importance: Importance.max, // Maximum importance for notification
        priority: Priority.high, // High priority for delivery
        enableVibration: true, // Enable vibration
        playSound: true, // Enable sound
        styleInformation: const BigTextStyleInformation(''), // Style for large text
        color: const Color(0xFF936B46), // Custom accent color for location notifications
      );

      // Platform-agnostic notification details wrapper
      final details = NotificationDetails(android: androidDetails);

      // Show the notification with ID 1 (distinct from general notifications)
      await _notifications.show(
        1, // Notification ID (1 for location notifications)
        title,
        body,
        details,
      );
      debugPrint("Location notification shown: $title");
    } catch (e) {
      // Log any errors that occur during location notification display
      debugPrint("Error showing location notification: $e");
    }
  }
}