// lib/core/constants/app_constants.dart
class AppConstants {
  AppConstants._();
 
  static const String appName = 'Detector LSC';
 
  // Asset paths
  static const String modelPath = 'assets/models/sign_model.tflite';
  static const String labelsPath = 'assets/models/labels.txt';
 
  // Inference
  static const double confidenceThreshold = 0.80;
  static const int landmarkCount = 21;
  static const int landmarkDimensions = 3; // x, y, z
  static const int inputSize = landmarkCount * landmarkDimensions; // 63
 
  // UI
  static const double maxContentWidth = 480.0;
}
