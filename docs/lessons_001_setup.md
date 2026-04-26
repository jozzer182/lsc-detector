# Lessons 001 - Project Setup

## 1. Flutter Version
Flutter 3.41.7 • channel stable • Microsoft Windows [Version 10.0.26200.8246], locale es-CO

## 2. Package Version Conflicts
- No direct pub package version conflicts were encountered during `flutter pub get`. The versions requested were compatible.
- However, the `tflite_flutter` package required a minimum Android SDK version of 26, conflicting with our initial setting of 24.

## 3. Gradle or SDK Version Issues
- The `tflite_flutter` package failed the Gradle build because it required `minSdkVersion 26`.
- **Fix:** We updated `android\app\build.gradle.kts` to use `minSdk = 26` instead of `minSdk = 24`.

## 4. Failed Commands
- `flutter build apk --debug` initially failed due to the `minSdkVersion` requirement from `tflite_flutter`.
  - **Fix:** Modifying the `minSdk` parameter in `build.gradle.kts` and running the build again worked perfectly.
- `flutter analyze` threw 2 warnings initially:
  - `_errorSeed` in `app_theme.dart` was unused. Fixed by adding `// ignore: unused_field`.
  - `AppBar(title: Text(AppConstants.appName))` lacked the `const` keyword. Fixed by changing to `const Text(...)`.

## 5. What Didn't Work As Expected
- In Prompt 1, it was assumed the build file would be `android\app\build.gradle`. However, in modern Flutter projects, it uses Kotlin DSL, so the file is `android\app\build.gradle.kts`.
- It was assumed `minSdkVersion 24` was sufficient, but `tflite_flutter` required `minSdkVersion 26`.
- Added missing `const` constructors where Flutter linting requires them.

## 6. Final State of pubspec.yaml
```yaml
name: flutter_app
description: Detector de señas LSC — MVP
 
publish_to: 'none'
version: 1.0.0+1
 
environment:
  sdk: ^3.7.0
  flutter: '>=3.27.0'
 
dependencies:
  flutter:
    sdk: flutter
 
  # Camera
  camera: ^0.11.0+2
 
  # MediaPipe hand landmark detection (Android, bundles the .task model automatically)
  hand_landmarker: ^2.1.2
 
  # TFLite inference for the custom classifier
  tflite_flutter: ^0.10.4
 
  # Permissions
  permission_handler: ^11.3.1
 
  # Utilities
  flutter_animate: ^4.5.0
 
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
 
flutter:
  uses-material-design: true
  assets:
    - assets/models/
```
