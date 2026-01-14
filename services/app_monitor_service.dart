// ---
// APP MONITOR SERVICE - Real-time Lock Enforcement Engine
// ---
// Purpose: Continuously monitors time and location to enforce app locks
// Runs every 10 seconds to check if apps should be locked/unlocked
// ---

// Import core Dart libraries for async operations and timers
import 'dart:async';
// Flutter UI and framework libraries
import 'package:flutter/material.dart';
// Platform channels for Flutter ~ Android communication
import 'package:flutter/services.dart';
// Geolocation for GPS position and distance calculations
import 'package:geolocator/geolocator.dart';
// Date/time formatting utilities
import 'package:intl/intl.dart';
// Simple key-value storage for app preferences
import 'package:shared_preferences/shared_preferences.dart';

// Import app controllers that manage different types of locks
import '../time_locks_controller.dart';
import '../location_locks_controller.dart';
import '../locked_apps_controller.dart';

// Import app services for notifications and background tasks
import '../services/notification_service.dart';
import '../services/background_service.dart';

class AppMonitorService {
  static Timer? _timer;
  static bool _isMonitoring = false;
  static DateTime? _lastCheckTime;

  static const _platform = MethodChannel('applock/location_service');
  static const _accessibilityChannel = MethodChannel('applock/accessibility');

  static void startMonitoring(
    BuildContext context,
    TimeLocksController timeLocksController,
    LocationLocksController locationLocksController,
    LockedAppsController lockedAppsController,
  ) {
    if (_isMonitoring) return;

    _isMonitoring = true;
    debugPrint("# AppMonitorService started (foreground)");

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await runBackgroundCheck(
        timeLocksController,
        locationLocksController,
        lockedAppsController,
      );
    });
    
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await runBackgroundCheck(
        timeLocksController,
        locationLocksController,
        lockedAppsController,
      );
    });
  }

  static void stopMonitoring() {
    _timer?.cancel();
    _isMonitoring = false;
    debugPrint("^ AppMonitorService stopped");
  }

  static Future<void> runBackgroundCheck(
    TimeLocksController timeLocksController,
    LocationLocksController locationLocksController,
    LockedAppsController lockedAppsController,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool("notifications_enabled") ?? false;

    _detectTimeTampering(notificationsEnabled);

    final now = DateFormat('HH:mm:ss').format(DateTime.now());
    debugPrint("^ AppMonitorService check @ $now");

    await _checkTimeLocks(timeLocksController, lockedAppsController, now, notificationsEnabled);

    await _checkLocationLocks(
      locationLocksController: locationLocksController,
      lockedAppsController: lockedAppsController,
      notificationsEnabled: notificationsEnabled,
    );

    await _syncLocationLocksWithNative(locationLocksController);

    await BackgroundService.forceCheck();
  }

  // ---
  // LOCATION LOCK SYNC -- USE PACKAGE NAMES
  // ---
  static Future<void> _syncLocationLocksWithNative(
    LocationLocksController locationLocksController) async {
    try {
      final locationLocks = locationLocksController.locationLocks;
      debugPrint("Syncing ${locationLocks.length} location-locked apps with native service");

      for (final lock in locationLocks) {
        final packageName = lock["package_name"] ?? lock["app_name"];
        if (packageName != null && packageName.isNotEmpty) {
          await _accessibilityChannel.invokeMethod('addLocationLockedApp', packageName);
          debugPrint("/ Synced location lock: $packageName");
        }
      }

      debugPrint("/ Successfully synced ${locationLocks.length} location locks with native service");
    } catch (e) {
      debugPrint("Error syncing location locks with native service: $e");
    }
  }

  static Future<void> _checkTimeLocks(
    TimeLocksController timeLocksController,
    LockedAppsController lockedAppsController,
    String currentTime,
    bool notificationsEnabled,
  ) async {
    final now = DateTime.now();
    for (final lock in timeLocksController.timeLocks) {
      final packageName = lock["app_name"];
      final start = lock["start_time"];
      final end = lock["end_time"];
      final startTime = _parseTime(start);
      final endTime = _parseTime(end);
      final withinLockTime = _isTimeWithinRange(now, startTime, endTime);
      if (withinLockTime) {
        if (!lockedAppsController.isLocked(packageName)) {
          await lockedAppsController.addLockedApp(packageName);
          debugPrint("✔ Time-based lock ACTIVATED for $packageName");
        }
        if (notificationsEnabled) {
          await NotificationService.showNotification(
            title: "Time Lock Active",
            body: "App is locked until ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}.",
          );
        }
      } else {
        if (lockedAppsController.isLocked(packageName)) {
          await lockedAppsController.removeLockedApp(packageName);
          debugPrint("✔ Time-based lock DEACTIVATED for $packageName");
        }
      }
    }
  }

  static DateTime _parseTime(String timeStr) {
    try {
      return DateTime.parse(timeStr);
    } catch (_) {
      final parts = timeStr.split(":");
      final now = DateTime.now();
      if (parts.length >= 2) {
        return DateTime(
          now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]),
        );
      }
      return now;
    }
  }

  static bool _isTimeWithinRange(DateTime now, DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      return now.isAfter(start) || now.isBefore(end.add(const Duration(days: 1)));
    } else {
      return now.isAfter(start) && now.isBefore(end);
    }
  }

  // ---
  // FIX #2B: LOCATION LOCK ENFORCEMENT - PACKAGE NAMES
  // ---
  static Future<void> _checkLocationLocks({
    required LocationLocksController locationLocksController,
    required LockedAppsController lockedAppsController,
    required bool notificationsEnabled,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS disabled - location-based locks skipped");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint("Location permission denied");
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      
      final currentLat = position.latitude;
      final currentLng = position.longitude;

      debugPrint("Current location: $currentLat, $currentLng");
      
      // Get ALL location locks
      for (final lock in locationLocksController.locationLocks) {
        final packageName = lock["package_name"] ?? lock["app_name"];
        final lockLat = double.tryParse(lock["latitude"].toString()) ?? 0.0;
        final lockLng = double.tryParse(lock["longitude"].toString()) ?? 0.0;

        final distance = Geolocator.distanceBetween(
          currentLat, currentLng, lockLat, lockLng);

        debugPrint("Location check for $packageName: ${distance.toStringAsFixed(2)}m away");

        // If within 100 meters radius, lock the app
        if (distance <= 100) {
          if (!lockedAppsController.isLocked(packageName)) {
            await lockedAppsController.addLockedApp(packageName);
            debugPrint("✔ Location lock ACTIVATED for $packageName");
            
            // Also sync with native service
            await _syncLocationLockWithNative(packageName, true);
          }
        } else {
          if (lockedAppsController.isLocked(packageName)) {
            await lockedAppsController.removeLockedApp(packageName);
            debugPrint("✔ Location lock DEACTIVATED for $packageName - too far");
            
            // Also sync with native service
            await _syncLocationLockWithNative(packageName, false);
          }
        }
      }
    } catch (e) {
      debugPrint("X Location check error: $e");
    }
  }

  // Helper method to sync with native service
  static Future<void> _syncLocationLockWithNative(String packageName, bool shouldLock) async {
    try {
      const channel = MethodChannel('applock/accessibility');
      if (shouldLock) {
        await channel.invokeMethod('addLocationLockedApp', packageName);
        debugPrint("✓ Location lock synced for: $packageName");
      } else {
        await channel.invokeMethod('removeLocationLockedApp', packageName);
        debugPrint("✓ Location lock removed for: $packageName");
      }
    } catch (e) {
      debugPrint("Failed to sync location lock with native: $e");
    }
  }

  static void _detectTimeTampering(bool notificationsEnabled) {
    final now = DateTime.now();

    if (_lastCheckTime != null) {
      final difference = now.difference(_lastCheckTime!).inMinutes;
      if (difference < -1 || difference > 120) {
        if (notificationsEnabled) {
          NotificationService.showNotification(
            title: "System Time Changed",
            body: "Detected system time modification. This may affect time-based locks.",
          );
        }
        debugPrint("A System time change detected: $difference minutes offset");
      }
    }

    _lastCheckTime = now;
  }

  static Future<void> _startForegroundLocationService() async {
    try {
      await _platform.invokeMethod('startLocationService');
      debugPrint("↑ Location foreground service started");
    } catch (e) {
      debugPrint("X Failed to start location service: $e");
    }
  }

  static Future<void> _stopForegroundLocationService() async {
    try {
      await _platform.invokeMethod('stopLocationService');
      debugPrint("↑ Location foreground service stopped");
    } catch (e) {
      debugPrint("✗ Failed to stop location service: $e");
    }
  }
}