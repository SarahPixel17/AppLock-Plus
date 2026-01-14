// Import required Flutter package for UI components
import 'package:flutter/material.dart'; // For Flutter UI components and Material Design

/// PasscodeDot - Visual indicator for PIN code input digits
/// This widget displays a single dot that can be either filled or empty
/// Used in PIN entry screens to show how many digits have been entered
/// 
/// Visual representation:
/// - Filled dot: User has entered a digit at this position
/// - Empty dot: This position is still awaiting user input
class PasscodeDot extends StatelessWidget {
  final bool filled; // Determines whether the dot should be filled (true) or empty (false)

  const PasscodeDot({super.key, required this.filled}); // Constructor with required filled parameter

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8), // External spacing around the dot (8 pixels on all sides)
      width: 16, // Fixed width of 16 logical pixels
      height: 16, // Fixed height of 16 logical pixels (creates a perfect circle when width == height)
      decoration: BoxDecoration(
        shape: BoxShape.circle, // Makes the container circular (instead of rectangular)
        color: filled ? Colors.black : Colors.grey[300], // Conditional color:
          // - Black when filled (digit entered)
          // - Light grey (shade 300) when empty
        border: Border.all(color: Colors.black26), // Subtle border (26% opacity black) for better visibility
          // This creates a thin outline around the dot, visible in both filled and empty states
      ),
    );
  }
}