/// PasscodeController - Manages PIN code input, storage, and verification logic
/// This controller handles the state for PIN entry during both setup and authentication modes
class PasscodeController {
  // Current input code being entered by the user
  // Stores digits as strings as they are entered (max 4 digits)
  final List<String> _inputCode = [];
  
  // Saved PIN code that was set during setup mode
  // This is the reference code against which input is verified during authentication
  List<String> _savedCode = []; // ← Saved PIN

  /// Getter for the current input code
  /// Provides read-only access to the current digits entered by the user
  List<String> get code => _inputCode;

  /// Add a digit to the current input code
  /// Only adds if the current code length is less than 4 (max PIN length)
  /// 
  /// @param digit - The digit (0-9) to add to the input code
  void addDigit(String digit) {
    if (_inputCode.length < 4) {
      _inputCode.add(digit);
    }
  }

  /// Delete the last digit from the current input code
  /// Removes the most recently entered digit (if any exist)
  void deleteDigit() {
    if (_inputCode.isNotEmpty) {
      _inputCode.removeLast();
    }
  }

  /// Clear the current input code
  /// Removes all digits from the input, useful for resetting after failed attempts
  void clear() {
    _inputCode.clear();
  }

  /// Save PIN during setup mode
  /// Copies the current input code to the saved code reference
  /// This should be called when the user successfully confirms their PIN during setup
  void saveCode() {
    _savedCode = List.from(_inputCode); // Create a copy of the input code
  }

  /// Verify PIN during login/authentication
  /// Compares the current input code against the saved reference code
  /// 
  /// @return bool - True if the input code matches the saved code, false otherwise
  bool verifyCode() {
    return _inputCode.join() == _savedCode.join(); // Convert lists to strings and compare
  }

  /// Check if a PIN has been saved (i.e., setup has been completed)
  /// Useful for determining if the user needs to set up a PIN before authentication
  bool get isCodeSaved => _savedCode.isNotEmpty;
}