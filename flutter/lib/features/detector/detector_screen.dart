// lib/features/detector/detector_screen.dart
// Main screen: live camera preview + real-time hand landmark detection.
// TFLite inference is NOT included here — it is added in Prompt 3.
 
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'services/camera_permission_service.dart';
import 'services/inference_service.dart';
import 'widgets/landmark_painter.dart';
import 'widgets/result_panel.dart';
 
enum _ScreenState {
  loading,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  error,
}
 
class DetectorScreen extends StatefulWidget {
  const DetectorScreen({super.key});
 
  @override
  State<DetectorScreen> createState() => _DetectorScreenState();
}
 
class _DetectorScreenState extends State<DetectorScreen>
    with WidgetsBindingObserver {
 
  // ── Screen state ───────────────────────────────────────────────────────
  _ScreenState _screenState = _ScreenState.loading;
  String _errorMessage = '';
 
  // ── Camera ─────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
 
  // ── Hand landmarker ────────────────────────────────────────────────────
  HandLandmarkerPlugin? _handLandmarker;
  List<Hand> _detectedHands = [];
  bool _isProcessingFrame = false;
 
  // ── Inference ──────────────────────────────────────────────────────────
  final InferenceService _inferenceService = InferenceService();
  InferenceResult? _lastResult;
  final List<double> _confidenceHistory = [];
  static const int _maxHistory = 10;
 
  // ── Lifecycle ──────────────────────────────────────────────────────────
 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll(); // changed from _initialize()
  }

  Future<void> _initializeAll() async {
    // Load TFLite model first — fail fast before opening camera
    try {
      await _inferenceService.initialize();
    } catch (e) {
      _setError(e.toString());
      return;
    }
    await _initialize();
  }
 
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _inferenceService.dispose();
    super.dispose();
  }
 
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause camera when app goes to background; resume when it returns.
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
 
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }
 
  // ── Initialization ─────────────────────────────────────────────────────
 
  Future<void> _initialize() async {
    // Step 1: Request runtime camera permission
    final permStatus = await CameraPermissionService.request();
 
    if (permStatus == CameraPermissionStatus.permanentlyDenied) {
      _setScreenState(_ScreenState.permissionPermanentlyDenied);
      return;
    }
    if (permStatus == CameraPermissionStatus.denied) {
      _setScreenState(_ScreenState.permissionDenied);
      return;
    }
 
    // Step 2: Get available cameras
    try {
      _cameras = await availableCameras();
    } catch (e) {
      _setError('Error al obtener cámaras: $e');
      return;
    }
 
    if (_cameras.isEmpty) {
      _setError('No se encontraron cámaras en este dispositivo.');
      return;
    }
 
    // Prefer front camera — more natural for sign language
    _selectedCameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;
 
    // Step 3: Start camera stream + hand landmarker
    await _startCamera();
  }
 
  Future<void> _startCamera() async {
    await _disposeCamera();
 
    final camera = _cameras[_selectedCameraIndex];
 
    final controller = CameraController(
      camera,
      ResolutionPreset.medium, // ~720p — good balance for landmark accuracy
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Required by hand_landmarker
    );
 
    try {
      await controller.initialize();
    } catch (e) {
      _setError('Error al inicializar la cámara: $e');
      return;
    }
 
    // Initialize hand landmarker — try GPU first, fall back to CPU
    try {
      _handLandmarker = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.6,
        delegate: HandLandmarkerDelegate.gpu,
      );
    } catch (_) {
      try {
        _handLandmarker = HandLandmarkerPlugin.create(
          numHands: 1,
          minHandDetectionConfidence: 0.6,
          delegate: HandLandmarkerDelegate.cpu,
        );
      } catch (e2) {
        _setError('Error al cargar el detector de manos: $e2');
        return;
      }
    }
 
    _cameraController = controller;
    await controller.startImageStream(_onCameraFrame);

    debugPrint(
      'Camera started — sensorOrientation: ${camera.sensorOrientation}, '
      'previewSize: ${controller.value.previewSize}, '
      'isFront: $_isFrontCamera',
    );

    if (mounted) setState(() => _screenState = _ScreenState.ready);
  }
 
  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _handLandmarker = null;
    _isProcessingFrame = false;
 
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
  }
 
  // ── Frame processing ───────────────────────────────────────────────────
 
  void _onCameraFrame(CameraImage image) {
    // Guard: drop frames that arrive while we are still processing the last one
    if (_isProcessingFrame) return;
    final plugin = _handLandmarker;
    final controller = _cameraController;
    if (plugin == null || controller == null) return;
 
    _isProcessingFrame = true;
    try {
      final hands = plugin.detect(
        image,
        controller.description.sensorOrientation,
      );

      // ── NEW: run inference if a hand was detected ──────────────────────
      InferenceResult? result;
      if (hands.isNotEmpty) {
        final lms = hands.first.landmarks;
        final points = lms
            .map((lm) => (
                  x: _isFrontCamera ? lm.x : 1.0 - lm.x,
                  y: lm.y,
                  z: lm.z,
                ))
            .toList();
        result = _inferenceService.predict(points);
      }
      // ── END NEW ────────────────────────────────────────────────────────

      if (mounted) {
        setState(() {
          _detectedHands = hands;
          // ── NEW: update inference state ────────────────────────────────
          _lastResult = result;
          if (result != null) {
            _confidenceHistory.add(result.confidence);
            if (_confidenceHistory.length > _maxHistory) {
              _confidenceHistory.removeAt(0);
            }
          } else if (hands.isEmpty) {
            _confidenceHistory.clear();
          }
          // ── END NEW ────────────────────────────────────────────────────
        });
      }
    } catch (e) {
      // Silently skip bad frames — never crash the stream
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }
 
  // ── Camera switching ───────────────────────────────────────────────────
 
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _screenState = _ScreenState.loading;
      _detectedHands = [];
      _lastResult = null;
      _confidenceHistory.clear();
    });
    await _startCamera();
  }
 
  // ── Helpers ────────────────────────────────────────────────────────────
 
  void _setError(String msg) {
    _errorMessage = msg;
    _setScreenState(_ScreenState.error);
  }
 
  void _setScreenState(_ScreenState state) {
    if (mounted) setState(() => _screenState = state);
  }
 
  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_selectedCameraIndex].lensDirection ==
          CameraLensDirection.front;
  // ── Orientation helpers ──────────────────────────────────────────────

  /// Calculates how many 90° clockwise turns are needed so the camera
  /// preview appears upright in portrait mode.
  ///
  /// Front camera: the platform mirrors horizontally, reversing the
  /// effective rotation direction → rotate WITH sensorOrientation.
  /// Back camera: no mirror → rotate AGAINST sensorOrientation.
  int _previewQuarterTurns(int sensorOrientation) {
    final turns = sensorOrientation ~/ 360;
    // Front camera: the platform mirrors horizontally, so we compensate
    // by rotating in the opposite direction to the sensor orientation.
    // Back camera: no mirror → rotate WITH sensorOrientation.
    if (_isFrontCamera) {
      return (2 + turns) % 4;
    }
    return turns % 4;
  }

  /// Builds the camera preview + landmark overlay inside a rotation-
  /// corrected, aspect-ratio-aware container that fills the available space.
  Widget _buildOrientedPreview(CameraController controller) {
    final sensorOrientation = controller.description.sensorOrientation;
    final quarterTurns = _previewQuarterTurns(sensorOrientation);
    final previewSize = controller.value.previewSize!;

    // previewSize from the camera is always in landscape (w > h).
    // We keep the SizedBox in landscape to match the raw sensor frame,
    // then RotatedBox rotates it to portrait.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: Transform.scale(
          scaleX: _isFrontCamera ? 1 : -1,
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: SizedBox(
              width: previewSize.width,
              height: previewSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  CustomPaint(
                    painter: LandmarkPainter(
                      hands: _detectedHands,
                      previewSize: previewSize,
                      isFrontCamera: _isFrontCamera,
                      quarterTurns: quarterTurns,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector LSC'),
        actions: [
          if (_screenState == _ScreenState.ready && _cameras.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_rounded),
              tooltip: 'Cambiar cámara',
            ),
        ],
      ),
      body: switch (_screenState) {
        _ScreenState.loading => _buildLoading(),
        _ScreenState.permissionDenied =>
          _buildPermissionDenied(permanent: false),
        _ScreenState.permissionPermanentlyDenied =>
          _buildPermissionDenied(permanent: true),
        _ScreenState.error => _buildError(),
        _ScreenState.ready => _buildCamera(),
      },
    );
  }
 
  // ── State screens ──────────────────────────────────────────────────────
 
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Iniciando cámara...'),
        ],
      ),
    );
  }
 
  Widget _buildPermissionDenied({required bool permanent}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined,
                size: 72, color: theme.colorScheme.error),
            const SizedBox(height: 24),
            Text(
              'Permiso de cámara requerido',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              permanent
                  ? 'El acceso a la cámara fue denegado permanentemente. '
                    'Ve a Configuración > Aplicaciones > Detector LSC > '
                    'Permisos y activa la cámara manualmente.'
                  : 'Esta app necesita acceso a la cámara para detectar señas. '
                    'Toca el botón para solicitar el permiso nuevamente.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: permanent
                  ? CameraPermissionService.openSettings
                  : _initialize,
              child: Text(
                permanent ? 'Abrir configuración' : 'Solicitar permiso',
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 72, color: theme.colorScheme.error),
            const SizedBox(height: 24),
            Text('Ocurrió un error',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () {
                setState(() => _screenState = _ScreenState.loading);
                _initialize();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildCamera() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoading();
    }
 
    final theme = Theme.of(context);
    final handDetected = _detectedHands.isNotEmpty;
 
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera preview + landmarks with orientation correction ─────
        _buildOrientedPreview(controller),
 
        // ── Status chip (top center) ────────────────────────────────────
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Chip(
                key: ValueKey(handDetected),
                avatar: Icon(
                  handDetected
                      ? Icons.sign_language
                      : Icons.pan_tool_outlined,
                  size: 18,
                  color: handDetected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  handDetected ? 'Mano detectada' : 'Sin mano',
                  style: TextStyle(
                    color: handDetected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: handDetected
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
        ),
 
        // ── Result Panel ─────────────────────────────────────────────────
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: ResultPanel(
            result: _lastResult,
            handDetected: _detectedHands.isNotEmpty,
            confidenceHistory: List.unmodifiable(_confidenceHistory),
          ),
        ),
      ],
    );
  }
}
