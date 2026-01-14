// Import required Flutter packages and application services
import 'package:flutter/material.dart'; // For Flutter UI components and ChangeNotifier
import 'package:shared_preferences/shared_preferences.dart'; // For simple local storage of non-sensitive data
import '../services/api_service.dart'; // Service for API communication with backend

/// PatternController - Manages pattern authentication logic and state
/// This controller handles pattern saving, loading, and verification
/// Uses ChangeNotifier to update UI components when pattern data changes
class PatternController extends ChangeNotifier {
  // Internal list to store pattern points (each point is an index from 0-8 for 3x3 grid)
  List<int> _pattern = [];
  
  // Hardcoded username - TODO: replace with actual logged-in user's username
  final String username = "user1"; // TODO: make dynamic when you add login

  /// Getter for pattern (read-only access)
  List<int> get pattern => _pattern;

  /// Save pattern to MySQL + cache locally
  /// Called when user sets up a new pattern during initial setup
  /// 
  /// @param newPattern - List of integers representing the pattern (0-8 for 3x3 grid)
  /// @return bool - True if save was successful, false otherwise
  Future<bool> savePattern(List<int> newPattern) async {
    _pattern = newPattern; // Update local pattern state

    // Save to local cache (SharedPreferences) for offline access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pattern', newPattern.map((e) => e.toString()).toList());

    // Save to backend API (MySQL database) for cross-device sync
    // Join pattern numbers with commas to create a string (e.g., "0,3,6,7,8")
    final success = await ApiService.savePattern(username, newPattern.join(","));
    
    if (success) notifyListeners(); // Notify UI widgets if save was successful
    return success; // Return success/failure status
  }

  /// Load pattern from MySQL (fallback to cache if offline)
  /// Attempts to load from backend first, falls back to local cache if API fails
  Future<void> loadPattern() async {
    try {
      // STEP 1: Try to load from backend API (primary data source)
      final settings = await ApiService.getUserSettings(username);
      
      // Check if settings exist and contain a pattern
      if (settings != null && settings["user"]["pattern"] != null) {
        final patternString = settings["user"]["pattern"];
        
        // Process pattern string if not empty
        if (patternString.isNotEmpty) {
          // Convert comma-separated string back to list of integers
          _pattern = patternString.split(",").map((e) => int.parse(e)).toList();
          notifyListeners(); // Notify UI widgets to update

          // Update local cache with fresh data from backend
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('pattern', _pattern.map((e) => e.toString()).toList());
          return; // Exit early since we successfully loaded from backend
        }
      }
    } catch (e) {
      // Log API error but continue to fallback
      print("❌ loadPattern error: $e");
    }

    // STEP 2: Fallback to local cache (for offline mode or API failure)
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('pattern');
    
    // If cached pattern exists, load it
    if (saved != null) {
      _pattern = saved.map((e) => int.parse(e)).toList();
      notifyListeners(); // Notify UI widgets to update
    }
    // If no cached pattern exists, _pattern remains empty list
  }

  /// Verify input pattern directly with MySQL (fallback to local cache)
  /// Compares user input against saved pattern from backend or local cache
  /// 
  /// @param input - List of integers representing user's pattern input
  /// @return bool - True if input matches saved pattern, false otherwise
  Future<bool> verifyPattern(List<int> input) async {
    try {
      // STEP 1: Always try database first for most up-to-date verification
      final settings = await ApiService.getUserSettings(username);
      
      // Check if settings exist and contain a pattern
      if (settings != null && settings["user"]["pattern"] != null) {
        final patternString = settings["user"]["pattern"];
        
        // Process pattern string if not empty
        if (patternString.isNotEmpty) {
          // Convert comma-separated string back to list of integers
          final dbPattern = patternString.split(",").map((e) => int.parse(e)).toList();
          
          // Compare input pattern with database pattern
          return _isSamePattern(dbPattern, input);
        }
      }
    } catch (e) {
      // Log database error but continue to fallback
      print("❌ verifyPattern DB error: $e");
    }

    // STEP 2: Fallback → local cache (for offline verification)
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('pattern');
    
    // If cached pattern exists, compare with input
    if (saved != null) {
      final localPattern = saved.map((e) => int.parse(e)).toList();
      return _isSamePattern(localPattern, input);
    }

    // STEP 3: No pattern found anywhere (user hasn't set up pattern)
    return false;
  }

  /// Compare helper - Checks if two pattern sequences are identical
  /// Compares both length and each individual element in order
  /// 
  /// @param a - First pattern sequence to compare
  /// @param b - Second pattern sequence to compare
  /// @return bool - True if patterns are identical, false otherwise
  bool _isSamePattern(List<int> a, List<int> b) {
    // First check length - patterns must have same number of points
    if (a.length != b.length) return false;
    
    // Compare each element in sequence
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false; // Mismatch found
    }
    
    return true; // All elements match
  }
}