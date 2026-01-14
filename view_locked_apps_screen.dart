import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../services/api_service.dart';
import 'choose_auth_method_screen.dart';
import 'pattern_screen.dart';
import 'passcode_screen.dart';
import '../services/secure_storage_service.dart';
import '../profile/avatar_provider.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

class ViewLockedAppsScreen extends StatefulWidget {
  const ViewLockedAppsScreen({super.key});

  @override
  State<ViewLockedAppsScreen> createState() => _ViewLockedAppsScreenState();
}

class _ViewLockedAppsScreenState extends State<ViewLockedAppsScreen> {
  List<Map<String, dynamic>> _configuredLocks = [];
  List<Map<String, dynamic>> _currentlyActiveLocks = [];
  bool _isLoading = true;
  final String username = "user1";
  final Map<String, String> _appNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadConfiguredLocks();
  }

  // Helper function to get display name for any package name
  Future<String> _getDisplayName(String appNameOrPackage) async {
    if (_appNameCache.containsKey(appNameOrPackage)) {
      return _appNameCache[appNameOrPackage]!;
    }

    if (!appNameOrPackage.contains('.')) {
      _appNameCache[appNameOrPackage] = appNameOrPackage;
      return appNameOrPackage;
    }

    try {
      final Application? app = await DeviceApps.getApp(appNameOrPackage);
      if (app != null) {
        _appNameCache[appNameOrPackage] = app.appName;
        return app.appName;
      }
    } catch (e) {
      print("Error getting app info for $appNameOrPackage: $e");
    }

    final formattedName = _formatPackageName(appNameOrPackage);
    _appNameCache[appNameOrPackage] = formattedName;
    return formattedName;
  }

  String _formatPackageName(String packageName) {
    final parts = packageName.split('.');
    if (parts.length > 1) {
      final lastPart = parts.last;
      if (lastPart.isNotEmpty) {
        return lastPart[0].toUpperCase() + lastPart.substring(1);
      }
    }
    return packageName;
  }

  Future<void> _loadConfiguredLocks() async {
    setState(() => _isLoading = true);
    try {
      final timeLocks = await ApiService.getTimeLocks(username);
      final locationLocks = await ApiService.getLocationLocks(username);
      final now = DateTime.now();

      final allLocks = <Map<String, dynamic>>[];

      // Process TIME-BASED locks
      for (final lock in timeLocks) {
        try {
          final packageName = lock["app_name"] ?? "";
          final displayName = await _getDisplayName(packageName);
          final start = DateTime.parse(lock["start_time"]);
          final end = DateTime.parse(lock["end_time"]);
          final isActive = _isTimeWithinRange(now, start, end);

          allLocks.add({
            "id": lock["id"],
            "app_name": displayName,
            "original_name": packageName,
            "package_name": packageName,
            "lock_type": "time_based",
            "start_time": lock["start_time"],
            "end_time": lock["end_time"],
            "is_active": isActive,
          });
        } catch (e) {
          print("Error processing time lock: $e");
        }
      }

      // Process LOCATION-BASED locks
      for (final lock in locationLocks) {
        try {
          final packageName = lock["app_name"] ?? "";
          final displayName = await _getDisplayName(packageName);
          
          // Check if location lock is active (within 100m radius)
          bool isLocationActive = false;
          try {
            final Position? currentPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
            );
            
            if (currentPosition != null) {
              final lockLat = double.tryParse(lock["latitude"].toString()) ?? 0.0;
              final lockLng = double.tryParse(lock["longitude"].toString()) ?? 0.0;
              
              final distance = Geolocator.distanceBetween(
                currentPosition.latitude,
                currentPosition.longitude,
                lockLat,
                lockLng,
              );
              
              isLocationActive = distance <= 100;
            }
          } catch (e) {
            print("Error checking location: $e");
          }

          allLocks.add({
            "id": lock["id"],
            "app_name": displayName,
            "original_name": packageName,
            "package_name": packageName,
            "lock_type": "location_based",
            "location_name": lock["location_name"],
            "latitude": lock["latitude"],
            "longitude": lock["longitude"],
            "is_active": isLocationActive,
          });
        } catch (e) {
          print("Error processing location lock: $e");
        }
      }

      // Separate currently active locks
      final activeLocks = allLocks.where((lock) => lock["is_active"] == true).toList();

      setState(() {
        _configuredLocks = allLocks;
        _currentlyActiveLocks = activeLocks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load configured locks: $e")),
      );
    }
  }

  bool _isTimeWithinRange(DateTime now, DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      return now.isAfter(start) || now.isBefore(end);
    } else {
      return now.isAfter(start) && now.isBefore(end);
    }
  }

  Future<void> _handleAppTap(Map<String, dynamic> app) async {
    final avatarProvider = context.read<AvatarProvider>();
    await avatarProvider.setExpression(CatExpression.curious);

    final displayName = app["app_name"];
    final originalName = app["original_name"];

    try {
      // Check if app is currently locked
      if (app["is_active"] == true) {
        final authMethod = await SecureStorageService.getAuthMethod();
        final appNameToShow = _isPackageName(displayName) ? "App" : displayName;

        if (authMethod == "pin") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PasscodeScreen(
                isSetupMode: false,
                appName: appNameToShow,
              ),
            ),
          );
        } else if (authMethod == "pattern") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatternScreen(
                isSetupMode: false,
                appName: appNameToShow,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please set a PIN or pattern first."),
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChooseAuthMethodScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$displayName is not locked right now.")),
        );
        _loadConfiguredLocks(); // Refresh status
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error checking lock status: $e")),
      );
    }
  }

  bool _isPackageName(String name) {
    return name.contains('.') &&
        (name.startsWith('com.') ||
            name.startsWith('org.') ||
            name.startsWith('net.') ||
            RegExp(r'^[a-z]+\.[a-z]').hasMatch(name));
  }

  String _getLockTypeDescription(Map<String, dynamic> app) {
    final lockType = app["lock_type"] ?? "";

    switch (lockType) {
      case "time_based":
        final startTime = app["start_time"]?.toString();
        final endTime = app["end_time"]?.toString();
        if (startTime != null && endTime != null) {
          try {
            final start = DateTime.parse(startTime);
            final end = DateTime.parse(endTime);
            final startFormatted =
                "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
            final endFormatted =
                "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
            return "Time Lock: $startFormatted - $endFormatted";
          } catch (_) {
            return "Time Lock: ${startTime.split(' ')[1]} - ${endTime.split(' ')[1]}";
          }
        }
        return "Time Based Lock";
      case "location_based":
        return "Location Lock: ${app["location_name"] ?? "Unknown"}";
      default:
        return "Unknown Lock Type";
    }
  }

  IconData _getLockTypeIcon(Map<String, dynamic> app) {
    final type = app["lock_type"] ?? "";
    switch (type) {
      case "time_based":
        return Icons.access_time;
      case "location_based":
        return Icons.location_on;
      default:
        return Icons.lock_outline;
    }
  }

  Color _getLockTypeColor(Map<String, dynamic> app) {
    final type = app["lock_type"] ?? "";
    switch (type) {
      case "time_based":
        return const Color(0xFF2196F3); // Blue
      case "location_based":
        return const Color(0xFF4CAF50); // Green
      default:
        return const Color(0xFF936B46); // Gold
    }
  }

  Future<void> _deleteLock(int id, String lockType, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF9E9D2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Remove Lock",
          style: TextStyle(
            color: Color(0xFF553F2B),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to remove the $lockType for $displayName?",
          style: const TextStyle(color: Color(0xFF553F2B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    bool success = false;

    if (lockType == "time_based") {
      success = await ApiService.deleteTimeLock(id, username);
    } else if (lockType == "location_based") {
      success = await ApiService.deleteLocationLock(id);
    }

    if (success) {
      setState(() {
        _configuredLocks.removeWhere((app) => app["id"] == id);
        _currentlyActiveLocks.removeWhere((app) => app["id"] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lock removed successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to remove lock")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 18,
      color: Color(0xFF553F2B),
      fontWeight: FontWeight.w600,
    );

    const subtitleStyle = TextStyle(
      fontSize: 14,
      color: Color(0xFF936B46),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9E9D2),
        elevation: 0,
        title: const Text(
          'Configured Locks',
          style: TextStyle(
            fontFamily: 'Lancelot',
            fontWeight: FontWeight.bold,
            color: Color(0xFF553F2B),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF936B46)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF936B46)),
            onPressed: _loadConfiguredLocks,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF936B46)))
          : RefreshIndicator(
              color: const Color(0xFF936B46),
              onRefresh: _loadConfiguredLocks,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Card
                    Card(
                      color: const Color(0xFFFFF6EC),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Total Configured Locks", style: subtitleStyle),
                                Text(
                                  "${_configuredLocks.length}",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF553F2B),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Currently Active", style: subtitleStyle),
                                Text(
                                  "${_currentlyActiveLocks.length}",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF553F2B),
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.security,
                                color: Color(0xFF936B46), size: 40),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // List of Configured Locks
                    Expanded(
                      child: _configuredLocks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_open,
                                      size: 64, color: Color(0xFF936B46)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No configured locks found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFF553F2B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Configure time-based or location-based\nlocks to get started',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadConfiguredLocks,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF936B46),
                                    ),
                                    child: const Text(
                                      "Refresh",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _configuredLocks.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(color: Color(0xFF936B46)),
                              itemBuilder: (context, index) {
                                final app = _configuredLocks[index];
                                final displayName = app["app_name"];
                                final lockType = app["lock_type"];
                                final isActive = app["is_active"] == true;

                                return Card(
                                  color: const Color(0xFFFFF6EC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      _getLockTypeIcon(app),
                                      color: _getLockTypeColor(app),
                                      size: 32,
                                    ),
                                    title: Row(
                                      children: [
                                        Text(displayName ?? "Unknown App",
                                            style: titleStyle),
                                        if (isActive)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "ACTIVE",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      _getLockTypeDescription(app),
                                      style: subtitleStyle,
                                    ),
                                    onTap: () => _handleAppTap(app),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      tooltip: "Remove Lock",
                                      onPressed: () => _deleteLock(
                                          app["id"], lockType, displayName),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}