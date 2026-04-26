// lib/features/detector/services/inference_service.dart
// Loads sign_model.tflite and classifies 21 hand landmarks into A or B.
// Normalization mirrors the Python train_model.py pipeline exactly.
 
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/constants/app_constants.dart';
 
class InferenceResult {
  final String label;
  final double confidence;
  final List<double> allScores;
 
  const InferenceResult({
    required this.label,
    required this.confidence,
    required this.allScores,
  });
 
  /// True when confidence meets or exceeds the threshold in AppConstants.
  bool get isReliable => confidence >= AppConstants.confidenceThreshold;
}
 
class InferenceService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
 
  bool get isInitialized => _isInitialized;
  List<String> get labels => List.unmodifiable(_labels);
 
  Future<void> initialize() async {
    // 1. Load labels
    final rawLabels = await rootBundle.loadString(AppConstants.labelsPath);
    _labels = rawLabels
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
 
    if (_labels.isEmpty) {
      throw Exception(
        'labels.txt está vacío o mal formateado. '
        'Debe contener una etiqueta por línea, p.ej.: A\\nB',
      );
    }
 
    // 2. Load TFLite model
    try {
      _interpreter = await Interpreter.fromAsset(AppConstants.modelPath);
    } on Exception catch (e) {
      throw Exception(
        'Error cargando sign_model.tflite: $e\n'
        'Verifica que el archivo existe en assets/models/ y está '
        'declarado en pubspec.yaml bajo flutter: assets:',
      );
    }
 
    _isInitialized = true;
    debugPrint(
      'InferenceService listo. Clases: $_labels | '
      'Input: ${_interpreter!.getInputTensor(0).shape} | '
      'Output: ${_interpreter!.getOutputTensor(0).shape}',
    );
  }
 
  /// Classifies a list of exactly 21 landmarks.
  /// Returns null if input is invalid or interpreter is not ready.
  InferenceResult? predict(
    List<({double x, double y, double z})> landmarks,
  ) {
    if (!_isInitialized || _interpreter == null) return null;
 
    if (landmarks.length != AppConstants.landmarkCount) {
      debugPrint(
        'predict() recibió ${landmarks.length} landmarks, '
        'se esperaban ${AppConstants.landmarkCount}.',
      );
      return null;
    }
 
    // Build raw float array
    final raw = Float32List(AppConstants.inputSize);
    for (int i = 0; i < landmarks.length; i++) {
      raw[i * 3]     = landmarks[i].x;
      raw[i * 3 + 1] = landmarks[i].y;
      raw[i * 3 + 2] = landmarks[i].z;
    }
 
    // Normalize — must match train_model.py _normalize() exactly:
    //   1. Subtract wrist (landmark index 0) from all points
    //   2. Divide by max absolute value (scale-invariant)
    final normalized = _normalize(raw);
 
    // Run inference — shapes: input [1,63], output [1, num_classes]
    final input  = [normalized];
    final output = [List<double>.filled(_labels.length, 0.0)];
 
    try {
      _interpreter!.run(input, output);
    } on Exception catch (e) {
      debugPrint('Error en inferencia TFLite: $e');
      return null;
    }
 
    final scores = List<double>.from(output[0]);
 
    // Argmax
    int maxIdx = 0;
    double maxScore = scores[0];
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIdx = i;
      }
    }
 
    return InferenceResult(
      label: _labels[maxIdx],
      confidence: maxScore,
      allScores: scores,
    );
  }
 
  Float32List _normalize(Float32List raw) {
    final out = Float32List(raw.length);
    final wx = raw[0];
    final wy = raw[1];
    final wz = raw[2];
 
    for (int i = 0; i < AppConstants.landmarkCount; i++) {
      out[i * 3]     = raw[i * 3]     - wx;
      out[i * 3 + 1] = raw[i * 3 + 1] - wy;
      out[i * 3 + 2] = raw[i * 3 + 2] - wz;
    }
 
    double maxAbs = 0;
    for (final v in out) {
      if (v.abs() > maxAbs) maxAbs = v.abs();
    }
    if (maxAbs > 0) {
      for (int i = 0; i < out.length; i++) {
        out[i] /= maxAbs;
      }
    }
 
    return out;
  }
 
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
