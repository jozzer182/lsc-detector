// lib/features/detector/services/camera_permission_service.dart
// Handles runtime camera permission on Android.
 
import 'package:permission_handler/permission_handler.dart';
 
enum CameraPermissionStatus { granted, denied, permanentlyDenied }
 
class CameraPermissionService {
  /// Requests camera permission and returns the result.
  /// On Android 26+, the user sees the system dialog if not yet decided.
  static Future<CameraPermissionStatus> request() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return CameraPermissionStatus.granted;
    if (status.isPermanentlyDenied) return CameraPermissionStatus.permanentlyDenied;
    return CameraPermissionStatus.denied;
  }
 
  /// Returns true if permission is currently granted without requesting.
  static Future<bool> isGranted() async =>
      (await Permission.camera.status).isGranted;
 
  /// Opens system app settings so the user can grant permission manually.
  static Future<void> openSettings() => openAppSettings();
}
