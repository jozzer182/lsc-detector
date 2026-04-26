# Lessons 002 - Camera & Hand Landmark Integration

## 1. GPU vs CPU Delegate
- The code attempts GPU delegate first, then falls back to CPU.
- On the Samsung SM-G991U1 (Snapdragon 888, Adreno 660), the GPU delegate works.
- Note: tflite logs show `Failed to load OpenCL library` but this is for MediaPipe's internal TFLite, not our custom model. Detection still works via the GPU fallback path.

## 2. Gradle / Kotlin Build Errors
- **libc++_shared.so conflict**: Added `packaging { resources { pickFirsts += "**/libc++_shared.so" } }` to `android\app\build.gradle.kts`.
- No other Gradle errors encountered.

## 3. sensorOrientation & Preview Rotation Fix
- **Samsung S21 front camera: sensorOrientation = 270**
- **Samsung S21 back camera: sensorOrientation = 90**
- **previewSize: 720x480** (always reported in native landscape format by the Camera API).

**CRITICAL ISSUE 1: Preview Rotation**
- CameraX on Android provides the raw sensor frames in landscape.
- **Fix**: Wrapped the `CameraPreview` inside a `RotatedBox` to manually rotate it to portrait.
  - Formula used for both cameras: `quarterTurns = (sensorOrientation ~/ 90) % 4`.
  - The `CameraPreview` and `CustomPaint` (landmark overlay) are wrapped in a `SizedBox` matching the raw landscape dimensions (`720x480`), ensuring the `RotatedBox` turns them together correctly.

## 4. Landmark Coordinate Mapping Fix
**CRITICAL ISSUE 2: Landmark Misalignment**
- The `hand_landmarker` plugin (MediaPipe) returns landmarks in a **portrait-corrected** coordinate space because we pass `sensorOrientation` to the `detect()` method.
- However, our `CustomPainter` draws on a **pre-rotation landscape canvas** (which is then rotated by `RotatedBox`).
- **Fix**: Implemented an inverse-transformation in `LandmarkPainter`. We take the portrait-corrected coordinates `(nx, ny)` and map them back to the landscape canvas space depending on the `quarterTurns`.
- **Front Camera Mirroring**: For the front camera, the platform mirrors the image horizontally, so we also flip the X coordinate (`nx = 1.0 - nx`) before applying the rotation transform.

## 5. Frame Rate
- Uses `ResolutionPreset.medium` (~720p, 720x480 actual on S21).
- Frame guard (`_isProcessingFrame`) prevents backpressure.
- `HWUI onFlyCompress` messages in logs are normal Android GPU compositing.

## 6. hand_landmarker v2.2.0 API
- **No unnamed constructor** — must use `HandLandmarkerPlugin.create()`.
- Accepted params: `numHands`, `minHandDetectionConfidence`, `delegate`.
- Does NOT accept: `minHandPresenceConfidence`, `minTrackingConfidence`.

## 7. Camera Package
- No black screen issues. `imageFormatGroup: ImageFormatGroup.yuv420` is correct.
- `E/ProxyApiRegistrar: missing-instance-error` appears in logs — this is a known camera_android_camerax issue, does not affect functionality.

## 8. What Didn't Work As Described
- HandLandmarkerPlugin constructor API mismatch (see #6).
- Camera preview orientation was NOT handled by CameraX automatically (see #3).
- `withOpacity()` deprecated in current Flutter SDK — suppressed with ignore comment.

## 9. Does the hand skeleton appear on screen?
- YES — landmarks detect and render. Orientation fix applied to correct the upside-down preview.
