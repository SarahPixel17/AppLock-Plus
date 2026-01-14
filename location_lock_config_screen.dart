// Import required packages for data serialization, HTTP requests, geolocation, app management, state management, and mapping
import 'dart:convert'; // For JSON encoding and decoding
import 'package:flutter/material.dart'; // For Flutter UI components
import 'package:http/http.dart' as http; // For making HTTP requests to external APIs
import 'package:geolocator/geolocator.dart'; // For accessing device GPS/location services
import 'package:device_apps/device_apps.dart'; // For accessing installed applications on device
import 'package:provider/provider.dart'; // For state management with Provider pattern
import 'package:flutter_map/flutter_map.dart'; // For displaying interactive maps
import 'package:latlong2/latlong.dart'; // For handling latitude/longitude coordinates
import '../location_locks_controller.dart'; // Custom controller for managing location locks

/// LocationLockConfigScreen - Screen for creating or editing location-based app locks
/// Allows users to select an app, choose a location via map or search, and configure location-based restrictions
class LocationLockConfigScreen extends StatefulWidget {
  final Map<String, dynamic>? existingLock; // Optional parameter for editing existing locks

  const LocationLockConfigScreen({super.key, this.existingLock});

  @override
  State<LocationLockConfigScreen> createState() => _LocationLockConfigScreenState();
}

/// State class for LocationLockConfigScreen
/// Manages UI state, user inputs, and location selection logic
class _LocationLockConfigScreenState extends State<LocationLockConfigScreen> {
  // Controllers for text input fields
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State variables for app selection, loading states, and data storage
  Application? _selectedApp; // Currently selected application to lock
  bool _isSaving = false; // Flag to indicate save operation in progress
  bool _isLoadingApps = true; // Flag to indicate apps are being loaded
  List<Application> _installedApps = []; // List of installed applications on device
  LatLng? _selectedPosition; // Selected geographical coordinates (latitude/longitude)
  late MapController _mapController; // Controller for the map widget

  // Variables for location search functionality
  List<Map<String, dynamic>> _searchResults = []; // Results from location search API
  bool _isSearching = false; // Flag to indicate search operation in progress

  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // Initialize map controller
    _loadInstalledApps(); // Load installed apps when screen initializes

    // If editing an existing lock, populate form fields with existing data
    if (widget.existingLock != null) {
      final lock = widget.existingLock!;
      _locationNameController.text = lock["location_name"] ?? "";
      _selectedPosition = LatLng(
        double.tryParse(lock["latitude"].toString()) ?? 6.4510, // Default to UUM latitude
        double.tryParse(lock["longitude"].toString()) ?? 100.2770, // Default to UUM longitude
      );
    }
  }

  /// Load installed applications from the device
  /// Filters out system apps and includes app icons for display
  Future<void> _loadInstalledApps() async {
    try {
      // Get list of installed non-system applications with icons
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false, // Exclude system apps for cleaner UI
        includeAppIcons: true, // Include app icons for visual identification
      );
      setState(() {
        _installedApps = apps; // Store apps in state variable
        _isLoadingApps = false; // Update loading state

        // If editing existing lock, pre-select the previously selected app
        if (widget.existingLock != null) {
          final existingAppName = widget.existingLock!["app_name"];
          _selectedApp = apps.firstWhere(
            (a) => a.appName == existingAppName, // Find app by name
            orElse: () => apps.isNotEmpty ? apps.first : apps[0], // Fallback to first app
          );
        }
      });
    } catch (e) {
      // Handle errors during app loading
      setState(() => _isLoadingApps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("X Failed to load apps: $e")),
      );
    }
  }

  /// Get current device location using GPS
  /// Requests location permissions if not already granted
  Future<void> _useCurrentLocation() async {
    // Check if location services are enabled on the device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("♥ Location services are disabled")),
      );
      return;
    }

    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("X Location permission denied")),
        );
        return;
      }
    }

    // Handle permanently denied permissions
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("♠ Location permissions permanently denied")),
      );
      return;
    }

    // Get current position with high accuracy
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Update state with current location
    setState(() {
      _selectedPosition = LatLng(position.latitude, position.longitude);
    });

    // Move map to current location and zoom in
    _mapController.move(_selectedPosition!, 17.0);
    // Perform reverse geocoding to get location name
    await _reverseGeocode(_selectedPosition!);
  }

  /// Search for locations using OpenStreetMap Nominatim API
  /// Converts place names to geographical coordinates
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear(); // Clear results for empty query
      });
      return;
    }

    setState(() => _isSearching = true); // Set searching state

    try {
      // Construct API URL for location search
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5',
      );

      // Make HTTP GET request with custom user agent (required by Nominatim)
      final response = await http.get(url, headers: {
        'User-Agent': 'AppLockPlus/1.0 (https://applockplus.local)'
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data); // Store search results
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Search failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search error: $e")),
      );
    } finally {
      setState(() => _isSearching = false); // Reset searching state
    }
  }

  /// Handle selection of a search result
  /// Updates map position and performs reverse geocoding
  void _onSearchResultSelected(Map<String, dynamic> result) {
    final lat = double.parse(result['lat']); // Extract latitude
    final lon = double.parse(result['lon']); // Extract longitude

    setState(() {
      _selectedPosition = LatLng(lat, lon); // Update selected position
      _searchResults.clear(); // Clear search results
      _searchController.clear(); // Clear search text field
    });

    // Move map to selected location and zoom in
    _mapController.move(_selectedPosition!, 17.0);
    // Get human-readable name for the coordinates
    _reverseGeocode(_selectedPosition!);
  }

  /// Convert geographical coordinates to human-readable address
  /// Uses OpenStreetMap reverse geocoding API
  Future<void> _reverseGeocode(LatLng pos) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
    );

    final response = await http.get(url, headers: {
      'User-Agent': 'AppLockPlus/1.0 (https://applockplus.local)'
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        // Use display_name from API or fallback text
        _locationNameController.text =
            data["display_name"] ?? "Unnamed Location";
      });
    }
  }

  // ----------------------------------------------------------------------
  // ✅ UPDATED SAVE METHOD – USES CORRECT PACKAGE NAME (Update #4 Applied)
  // ----------------------------------------------------------------------
  
  /// Save or update location lock rule
  /// Uses real package name instead of app name for native integration
  Future<void> _saveLocationRule() async {
    // Use custom name or fallback to "Unnamed Location"
    final name = _locationNameController.text.trim().isEmpty
        ? "Unnamed Location"
        : _locationNameController.text.trim();

    // Validate required inputs
    if (_selectedApp == null || _selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select an app and a location."),
        ),
      );
      return;
    }

    setState(() => _isSaving = true); // Set saving state
    final controller =
        Provider.of<LocationLocksController>(context, listen: false);

    bool success = false;

    // ✅ USE REAL PACKAGE NAME (critical for native service integration)
    final packageName = _selectedApp!.packageName;

    // Determine if we're updating existing lock or creating new one
    if (widget.existingLock != null) {
      final id = widget.existingLock!["id"];
      success = await controller.updateLocationLock(
        id, // Existing lock ID
        _selectedApp!.appName, // Human-readable app name
        packageName, // REAL PACKAGE NAME for native service
        name, // Location name
        _selectedPosition!.latitude, // Latitude
        _selectedPosition!.longitude, // Longitude
      );
    } else {
      success = await controller.addLocationLock(
        context, // BuildContext for navigation
        _selectedApp!.appName, // Human-readable app name
        packageName, // REAL PACKAGE NAME for native service
        name, // Location name
        _selectedPosition!.latitude, // Latitude
        _selectedPosition!.longitude, // Longitude
      );
    }

    setState(() => _isSaving = false); // Reset saving state

    // Show success/error feedback
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Location lock saved for ${_selectedApp!.appName}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return success flag to previous screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✗ Failed to save location lock"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define color constants for consistent theme
    const brown = Color(0xFF553F2B); // Dark brown for text
    const gold = Color(0xFF936B46); // Gold/accent color
    const bg = Color(0xFFF9E9D2); // Light beige background

    final isEdit = widget.existingLock != null; // Determine if in edit mode

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0, // Remove shadow
        title: Text(
          isEdit ? 'Edit Location Lock' : 'Add Location Lock',
          style: const TextStyle(
              color: brown, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: gold),
          onPressed: () => Navigator.pop(context), // Navigate back
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Selection Dropdown
            _isLoadingApps
                ? const Center(child: CircularProgressIndicator()) // Loading indicator
                : DropdownButtonFormField<Application>(
                    value: _selectedApp,
                    isExpanded: true, // Expand to full width
                    items: _installedApps.map((app) {
                      return DropdownMenuItem(
                        value: app,
                        child: Row(
                          children: [
                            if (app is ApplicationWithIcon) // Display app icon if available
                              Image.memory(app.icon, width: 28, height: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                app.appName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (a) => setState(() => _selectedApp = a), // Update selected app
                    decoration: InputDecoration(
                      labelText: "Select App to Lock",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

            const SizedBox(height: 20), // Vertical spacing

            // Location Search Field
            TextField(
              controller: _searchController,
              onSubmitted: _searchLocation, // Trigger search on enter
              decoration: InputDecoration(
                hintText: "Search location (e.g., UUM Library)",
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ) // Show loading during search
                    : IconButton(
                        icon: const Icon(Icons.search, color: gold),
                        onPressed: () =>
                            _searchLocation(_searchController.text),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Search Results List (displayed when results exist)
            if (_searchResults.isNotEmpty)
              Container(
                height: 150, // Fixed height for results container
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: gold), // Gold border
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, i) {
                    final res = _searchResults[i];
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: gold),
                      title: Text(
                        res['display_name'] ?? "Unknown",
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _onSearchResultSelected(res), // Handle selection
                    );
                  },
                ),
              ),

            const SizedBox(height: 20), // Vertical spacing

            // Interactive Map Container
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: gold),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedPosition ??
                        const LatLng(6.4510, 100.2770), // Default to UUM location
                    initialZoom: 14, // Initial zoom level
                    onTap: (tapPos, point) {
                      setState(() => _selectedPosition = point); // Update on tap
                      _reverseGeocode(point); // Get location name for coordinates
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", // OpenStreetMap tiles
                      subdomains: const ['a', 'b', 'c'], // Load balancing subdomains
                    ),
                    if (_selectedPosition != null) // Show marker if location selected
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 50,
                            height: 50,
                            point: _selectedPosition!,
                            child: const Icon(Icons.location_pin,
                                color: Colors.red, size: 40), // Red location pin
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20), // Vertical spacing

            // Location Name Text Field
            TextField(
              controller: _locationNameController,
              decoration: InputDecoration(
                hintText: "Location name (auto or custom)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20), // Vertical spacing

            // "Use Current Location" Button
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.my_location, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _useCurrentLocation,
                label: const Text(
                  "Use Current Location",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 20), // Vertical spacing

            // Save/Update Button
            Center(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveLocationRule, // Disable when saving
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 35, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _isSaving
                      ? "Saving..." // Show saving text during operation
                      : (isEdit ? "Update Location Lock" : "Save Location Lock"),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }
}