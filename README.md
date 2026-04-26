<div align="center">

# 🤟 LSC Detector

**Real-time Colombian Sign Language detection, powered by on-device ML**

[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.27-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-%E2%89%A53.10-FFD43B?style=for-the-badge&logo=python&logoColor=black)](https://python.org)
[![MediaPipe](https://img.shields.io/badge/MediaPipe-Hand_Landmarker-34A853?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/edge/mediapipe)
[![TFLite](https://img.shields.io/badge/TensorFlow_Lite-MLP_Classifier-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![License](https://img.shields.io/badge/License-MIT-2ea44f?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android_8.0%2B-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)

</div>

---

A Flutter Android app that detects **Colombian Sign Language (LSC)** letters in real time using the device camera — **100% offline, no internet required**. The current MVP accurately classifies letters **A** and **B** with ~95% confidence at rest, and is designed to scale to the full 27-letter LSC alphabet. The companion Python pipeline lets you collect hand landmark data, train a custom TFLite MLP classifier, and drop the model straight into the app.

---

## 🔬 How It Works

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────┐
│  📷 Camera  │────▶│  hand_landmarker │────▶│  21 Landmarks │
│   (Live)    │     │   (MediaPipe)    │     │   (x, y, z)   │
└─────────────┘     └──────────────────┘     └───────┬───────┘
                                                     │
                                                     ▼
                                            ┌────────────────┐
                                            │ Normalization  │
                                            │ • Center wrist │
                                            │ • Scale by max │
                                            └───────┬────────┘
                                                    │
                                                    ▼
                                           ┌─────────────────┐
                                           │  TFLite MLP     │
                                           │  [1,63] → [1,2] │
                                           │  Classifier     │
                                           └───────┬─────────┘
                                                   │
                                                   ▼
                                           ┌─────────────────┐
                                           │  Flutter UI     │
                                           │  Letter + %     │
                                           │  Confidence     │
                                           └─────────────────┘
```

1. The **camera** streams live frames to MediaPipe's `hand_landmarker` task.
2. MediaPipe extracts **21 3D hand landmarks** (63 floats total).
3. Coordinates are **normalized** — centered on the wrist and scaled by the maximum absolute value — matching the Python training pipeline exactly.
4. The flattened `[1, 63]` vector is fed into a lightweight **TFLite MLP classifier**.
5. The **Flutter UI** displays the predicted letter with a real-time confidence sparkline.

---

## 📁 Project Structure

> **Monorepo** — Flutter app and Python ML pipeline live side-by-side.

```
lsc_detector/
│
├── flutter/                        # 📱 Flutter Android application
│   ├── lib/
│   │   ├── main.dart               # App entry point
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   │   └── app_constants.dart
│   │   │   └── theme/
│   │   │       └── app_theme.dart   # Material 3 Expressive theme
│   │   └── features/
│   │       └── detector/
│   │           ├── detector_screen.dart
│   │           ├── services/
│   │           │   ├── camera_permission_service.dart
│   │           │   └── inference_service.dart    # TFLite + normalization
│   │           └── widgets/
│   │               ├── landmark_painter.dart     # Hand skeleton overlay
│   │               └── result_panel.dart         # Letter + sparkline card
│   ├── assets/
│   │   └── models/
│   │       ├── sign_model.tflite    # Pre-trained MLP (A/B, ~25 KB)
│   │       └── labels.txt           # Class labels: A, B
│   ├── android/                     # Android build config (minSdk 26)
│   └── pubspec.yaml
│
├── python/                          # 🐍 ML training pipeline
│   ├── collect_data.py              # Webcam-based landmark collector
│   ├── train_model.py               # MLP training + TFLite export
│   ├── dataset.csv                  # Recorded landmark samples
│   ├── sign_model.tflite            # Exported model (source of truth)
│   └── labels.txt                   # Exported labels
│
├── docs/                            # 📝 Development notes
│   ├── lessons_001_setup.md
│   ├── lessons_002_camera.md
│   ├── lessons_003_inference.md
│   └── lessons_004_github.md
│
├── .vscode/
│   └── extensions.json              # Recommended VS Code extensions
├── .gitignore                       # Monorepo-wide exclusion rules
└── README.md
```

---

## ⚙️ Tech Stack

| Layer | Technology | Role |
|:------|:-----------|:-----|
| 📷 Camera | `camera` (CameraX) | Live video streaming with YUV420 frames |
| ✋ Hand Detection | MediaPipe `hand_landmarker` | Extracts 21 3D hand landmarks per frame |
| 📐 Embeddings | 63-float vector (x,y,z × 21) | Wrist-centered, scale-normalized coordinates |
| 🧠 Classifier | TensorFlow Lite MLP | 3-layer dense network (128→64→32→2 softmax) |
| 📱 UI Framework | Flutter 3.27+ | Cross-platform toolkit, Material 3 Expressive |
| 🔄 State | StatefulWidget | Frame-level state with processing guard |
| 🎨 Theme System | Material 3 Expressive | Light + dark mode, dynamic confidence colors |
| 🏋️ Training | TensorFlow / Keras + scikit-learn | Model training, evaluation, and TFLite export |

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Version | Notes |
|:------------|:--------|:------|
| Flutter SDK | ≥ 3.27 | `flutter --version` to verify |
| Android SDK | API 26+ | `minSdk = 26` required by `tflite_flutter` |
| Python | ≥ 3.10 | Only needed for model re-training |
| Device | Real Android phone | ⚠️ Emulator does NOT support camera streams |

### Clone & Run

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/lsc_detector.git
cd lsc_detector

# 2. Install Flutter dependencies
cd flutter
flutter pub get

# 3. Connect your Android device (USB debugging enabled)
flutter devices

# 4. Run the app
flutter run
```

> **Note:** A pre-trained model for letters **A** and **B** is already included in `flutter/assets/models/`. You can start detecting immediately — no Python setup needed.

---

## 🏋️ Training Your Own Model

Want to add more letters or improve accuracy? Follow these steps:

### Step 1 — Install Python Dependencies

```bash
cd python
pip install opencv-python mediapipe numpy pandas tensorflow scikit-learn
```

### Step 2 — Record Samples

```bash
python collect_data.py
```

- Select your webcam at startup (index shown automatically).
- Hold the sign for a letter, then press **SPACE** to save a sample.
- Press **Q** to quit the current letter.
- The script collects 30 samples per letter by default.

### Step 3 — Train & Export

```bash
python train_model.py
```

- Trains a 3-layer MLP with batch normalization and dropout.
- Exports `sign_model.tflite` (~25 KB) and `labels.txt`.
- **Recommendation:** 30+ samples per class for MVP, 100+ for production quality.

### Step 4 — Copy Model to Flutter

```bash
# Windows
copy sign_model.tflite ..\flutter\assets\models\sign_model.tflite
copy labels.txt ..\flutter\assets\models\labels.txt
```

### Step 5 — Rebuild the App

```bash
cd ..\flutter
flutter run
```

---

## 🧩 Key Technical Learnings

| Topic | Detail |
|:------|:-------|
| Preview rotation | Samsung front camera `sensorOrientation=270` requires `RotatedBox` with `quarterTurns = (sensorOrientation ~/ 90) % 4` to display the preview correctly in portrait mode |
| Landmark coordinate space | `hand_landmarker` returns portrait-corrected coords when `sensorOrientation` is passed — but the canvas is pre-rotation landscape, requiring inverse-transform in `LandmarkPainter` |
| TFLite minSdk | `tflite_flutter` requires `minSdk = 26` (Android 8.0), not the default `24` — build fails with a cryptic Gradle error if this isn't set |
| build.gradle.kts | Modern Flutter uses Kotlin DSL — Groovy syntax like `minSdkVersion 24` breaks the build; must use `minSdk = 26` |
| Normalization | Must match the Python pipeline exactly: subtract wrist coordinates (point 0) from all 21 landmarks, then divide by `max(abs(all_values))` |
| Confidence threshold | 80% threshold separates reliable predictions (green card) from low-confidence ones (muted display), reducing visual noise |

---

## 🗺️ Roadmap

- [x] MVP: real-time A/B detection on Android
- [x] Material 3 Expressive UI with confidence visualization
- [x] On-device inference, no internet required
- [ ] Temporal smoothing (N-frame voting before updating the UI letter)
- [ ] Full LSC alphabet (27 letters)
- [ ] Dynamic signs with motion (J, Z) using LSTM/sequence model
- [ ] iOS support
- [ ] Data augmentation pipeline for robust training

---

## 📝 Development Notes

Detailed development notes, troubleshooting, and lessons learned are in the [docs/](docs/) folder:

| File | Topic |
|:-----|:------|
| [lessons_001_setup.md](docs/lessons_001_setup.md) | Project setup, Gradle issues, `minSdk` fix |
| [lessons_002_camera.md](docs/lessons_002_camera.md) | Camera integration, rotation fix, landmark alignment |
| [lessons_003_inference.md](docs/lessons_003_inference.md) | TFLite inference, normalization, UI transitions |
| [lessons_004_github.md](docs/lessons_004_github.md) | Security audit, Git setup, repository organization |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<div align="center">

**Built with ❤️ for the deaf community in Colombia 🇨🇴**

</div>
