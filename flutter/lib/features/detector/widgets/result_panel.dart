// lib/features/detector/widgets/result_panel.dart
// Shows current prediction: animated letter card, confidence bar, sparkline.
 
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/inference_service.dart';
import '../../../core/constants/app_constants.dart';
 
class ResultPanel extends StatelessWidget {
  final InferenceResult? result;
  final bool handDetected;
  final List<double> confidenceHistory;
 
  const ResultPanel({
    super.key,
    required this.result,
    required this.handDetected,
    required this.confidenceHistory,
  });
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
 
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _LetterCard(result: result, handDetected: handDetected),
                const SizedBox(width: 20),
                Expanded(child: _buildInfo(theme)),
              ],
            ),
            if (handDetected && result != null) ...[
              const SizedBox(height: 16),
              _ConfidenceBar(result: result!),
              if (confidenceHistory.length >= 2) ...[
                const SizedBox(height: 10),
                _HistorySparkline(
                  values: confidenceHistory,
                  threshold: AppConstants.confidenceThreshold,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
 
  Widget _buildInfo(ThemeData theme) {
    if (!handDetected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sin mano', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Muestra la mano frente a la cámara',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
 
    final r = result;
    if (r == null) {
      return Text('Procesando...', style: theme.textTheme.titleLarge);
    }
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          r.isReliable ? 'Seña detectada' : 'Confianza baja',
          style: theme.textTheme.labelLarge?.copyWith(
            color: r.isReliable
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Letra ${r.label}',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: r.isReliable
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!r.isReliable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Ajusta la posición de la mano',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }
}
 
// ── Letter card ────────────────────────────────────────────────────────────
 
class _LetterCard extends StatelessWidget {
  final InferenceResult? result;
  final bool handDetected;
 
  const _LetterCard({required this.result, required this.handDetected});
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final isReliable = r?.isReliable ?? false;
    final showLetter = handDetected && r != null;
 
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(showLetter ? r.label : '__empty__'),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: (showLetter && isReliable)
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: showLetter
              ? Text(
                  r.label,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: isReliable
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 48,
                  ),
                )
                  .animate()
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 250.ms,
                    curve: Curves.easeOutBack,
                  )
              : Icon(
                  Icons.pan_tool_outlined,
                  size: 36,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}
 
// ── Confidence bar ─────────────────────────────────────────────────────────
 
class _ConfidenceBar extends StatelessWidget {
  final InferenceResult result;
 
  const _ConfidenceBar({required this.result});
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = result.confidence.clamp(0.0, 1.0);
    final barColor = result.isReliable
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Confianza', style: theme.textTheme.labelLarge),
            Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.labelLarge?.copyWith(color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: pct),
            duration: const Duration(milliseconds: 150),
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ],
    );
  }
}
 
// ── History sparkline ──────────────────────────────────────────────────────
 
class _HistorySparkline extends StatelessWidget {
  final List<double> values;
  final double threshold;
  final Color color;
 
  const _HistorySparkline({
    required this.values,
    required this.threshold,
    required this.color,
  });
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Historial  ',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: values,
                color: color,
                threshold: threshold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
 
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double threshold;
 
  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.threshold,
  });
 
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
 
    // Threshold reference line
    canvas.drawLine(
      Offset(0, size.height * (1 - threshold)),
      Offset(size.width, size.height * (1 - threshold)),
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );
 
    // Sparkline
    final path = Path();
    final step = size.width / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height * (1 - values[i].clamp(0.0, 1.0));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }
 
  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
