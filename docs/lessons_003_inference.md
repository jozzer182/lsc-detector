# Lessons 003 - TFLite Inference

## 1. TFLite Tensor Shapes
- **Input shape:** `[1, 63]`
- **Output shape:** `[1, 2]`

## 2. Inference Accuracy
- YES — the model correctly distinguished letter A from letter B.

## 3. Confidence % for Letter A (held steady)
- Stabilized at high confidence (~95-100%).

## 4. Confidence % for Letter B (held steady)
- Stabilized at high confidence (~95-100%).

## 5. UI Transitions
- The card correctly changes to the primary color when the confidence is ≥ 80% (reliable).

## 6. Real-time Sparkline
- The sparkline successfully updates in real-time, drawing a history curve using the confidence history queue of the last 10 frames.

## 7. Camera Rotation & Overlays
- YES — The RotatedBox and landmark overlay survived the edits perfectly. The landmarks stay aligned over the hand, and the preview remains upright.

## 8. Performance / Frame Rate
- The frame rate remains smooth. TFLite inference using the `[1, 63]` flat array is extremely lightweight and adds no noticeable latency overhead compared to the raw `HandLandmarker` extraction step.

## 9. Normalization Details
- The Dart normalization method matches the Python pipeline perfectly:
  1. Subtract the wrist coordinate (`raw[0]`, `raw[1]`, `raw[2]`) from all 21 points to make the features translation-invariant.
  2. Divide by the maximum absolute coordinate value across the hand to make it scale-invariant.
- No scaling or shifting mismatches were detected.

## 10. Final Verdict
- YES — The MVP works end-to-end. The camera captures the image, MediaPipe extracts the 21 landmarks, the coordinates are normalized, TFLite predicts the gesture (A or B), and the UI animates the result cleanly in real-time.

## 11. Top 3 Suggested Improvements for Next Iteration
1. **Model Expansion:** The current model only supports 2 classes. The pipeline needs to be scaled to support the full LSC alphabet.
2. **Smoothing/Debouncing:** The prediction can flicker slightly if the hand moves fast or is partially occluded. Implementing a simple moving average or requiring `N` consecutive frames of the same prediction before updating the UI letter would improve UX.
3. **Temporal Context:** Static landmark frames are good for the alphabet, but some LSC letters require motion (e.g., J, Z). Future iterations should track landmark trajectories over time (e.g., passing a sequence of `[time_steps, 63]` into an LSTM or 1D-CNN) to classify dynamic signs.
