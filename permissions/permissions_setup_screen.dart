import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import '../main_page.dart'; 

class PermissionsSetupScreen extends StatefulWidget {
  const PermissionsSetupScreen({super.key});

  @override
  State<PermissionsSetupScreen> createState() => _PermissionsSetupScreenState();
}

class _PermissionsSetupScreenState extends State<PermissionsSetupScreen> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _usageGranted = false;
  bool _accessibilityGranted = false;

  static const MethodChannel _platform = MethodChannel('applock/accessibility');

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// ✅ Check all current permissions
  Future<void> _checkPermissions() async {
    _locationGranted = await Permission.location.isGranted;
    _notificationGranted = await Permission.notification.isGranted;
    _usageGranted = await Permission.systemAlertWindow.isGranted;

    try {
      final result = await _platform.invokeMethod('isAccessibilityServiceEnabled');
      _accessibilityGranted = result == true;
    } catch (_) {
      _accessibilityGranted = false;
    }

    if (mounted) setState(() {});
  }

  /// ✅ Open accessibility settings
  Future<void> _openAccessibilitySettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.ACCESSIBILITY_SETTINGS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
    await Future.delayed(const Duration(seconds: 2));
    _checkPermissions();
  }

  /// ✅ Open usage access settings
  Future<void> _openUsageAccessSettings() async {
    try {
      await AppSettings.openAppSettings();
      await Future.delayed(const Duration(seconds: 2));
      _checkPermissions();
    } catch (e) {
      debugPrint("⚠️ Failed to open usage access settings: $e");
      const intent = AndroidIntent(
        action: 'android.settings.USAGE_ACCESS_SETTINGS',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    }
  }

  /// ✅ Request a permission directly
  Future<void> _grantPermission(Permission permission) async {
    final result = await permission.request();
    if (result.isGranted) _checkPermissions();
  }

  /// ✅ Complete setup and go to Main Page
  Future<void> _completeSetup() async {
    if (!_locationGranted ||
        !_notificationGranted ||
        !_usageGranted ||
        !_accessibilityGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please enable all permissions before finishing."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("first_launch_done", true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()), // ✅ Navigate directly
    );
  }

  /// ✅ UI tile builder
  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFFFDF3E2),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF936B46)),
        title: Text(
          title,
          style: const TextStyle(
              color: Color(0xFF553F2B), fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description, style: const TextStyle(color: Colors.grey)),
        trailing: Icon(
          granted ? Icons.check_circle : Icons.warning_amber_rounded,
          color: granted ? Colors.green : Colors.redAccent,
        ),
        onTap: onTap,
      ),
    );
  }

  /// ✅ Build Screen
  @override
  Widget build(BuildContext context) {
    final allGranted = _locationGranted &&
        _notificationGranted &&
        _usageGranted &&
        _accessibilityGranted;

    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9E9D2),
        elevation: 0,
        title: const Text(
          "Permission Setup",
          style: TextStyle(color: Color(0xFF553F2B), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF936B46)),
            onPressed: _checkPermissions,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "AppLock+ requires the following permissions for secure app locking.",
              style: TextStyle(
                color: Color(0xFF553F2B),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            _buildPermissionTile(
              icon: Icons.location_on,
              title: "Location Access",
              description: "Needed for location-based lock rules.",
              granted: _locationGranted,
              onTap: () => _grantPermission(Permission.location),
            ),
            _buildPermissionTile(
              icon: Icons.notifications,
              title: "Notifications Access",
              description: "Needed to alert you when locks are triggered.",
              granted: _notificationGranted,
              onTap: () => _grantPermission(Permission.notification),
            ),
            _buildPermissionTile(
              icon: Icons.lock_outline,
              title: "Accessibility Service",
              description: "Used for detecting locked app launches.",
              granted: _accessibilityGranted,
              onTap: _openAccessibilitySettings,
            ),
            _buildPermissionTile(
              icon: Icons.bar_chart,
              title: "Usage Access",
              description: "Allows AppLock+ to monitor active apps.",
              granted: _usageGranted,
              onTap: _openUsageAccessSettings,
            ),

            const Spacer(),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF936B46),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: allGranted ? _completeSetup : null,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                "Finish Setup",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
