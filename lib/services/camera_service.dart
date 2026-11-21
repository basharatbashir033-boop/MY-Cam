import 'dart:ui' show Offset;

import 'package:camera/camera.dart';

/// Thin wrapper around [CameraController] for MY Cam.
class CameraService {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  CameraLensDirection _direction = CameraLensDirection.back;
  bool _flashOn = false;

  CameraController? get controller => _controller;
  CameraLensDirection get direction => _direction;
  bool get isFront => _direction == CameraLensDirection.front;
  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get hasMultipleCameras {
    final hasFront =
        _cameras.any((c) => c.lensDirection == CameraLensDirection.front);
    final hasBack =
        _cameras.any((c) => c.lensDirection == CameraLensDirection.back);
    return hasFront && hasBack;
  }

  /// Opens the camera at the highest resolution (12MP photos on iPhone 8 Plus)
  /// with auto exposure and auto focus.
  Future<void> initialize({CameraLensDirection? direction}) async {
    await dispose();
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    if (_cameras.isEmpty) {
      throw CameraException('noCamera', 'No camera found on this device.');
    }
    _direction = direction ?? _direction;

    final description = _cameras.firstWhere(
      (c) => c.lensDirection == _direction,
      orElse: () {
        _direction = _cameras.first.lensDirection;
        return _cameras.first;
      },
    );

    final controller = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    _controller = controller;
    await controller.initialize();

    await _safely(() => controller.setExposureMode(ExposureMode.auto));
    await _safely(() => controller.setFocusMode(FocusMode.auto));
    await _applyFlash();
  }

  Future<void> switchCamera() {
    final next = isFront ? CameraLensDirection.back : CameraLensDirection.front;
    return initialize(direction: next);
  }

  /// The back camera uses the real flash. The front camera has no flash, so
  /// the screen shows a white "screen flash" instead (handled in the UI).
  Future<void> setFlash(bool on) async {
    _flashOn = on;
    await _applyFlash();
  }

  Future<void> _applyFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (isFront) return;
    await _safely(
      () => c.setFlashMode(_flashOn ? FlashMode.always : FlashMode.off),
    );
  }

  /// [point] is in camera-sensor space (0..1). Auto focus + auto exposure.
  Future<void> focusAt(Offset point) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await _safely(() => c.setFocusPoint(point));
    await _safely(() => c.setExposurePoint(point));
  }

  Future<XFile> takePicture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      throw CameraException('notReady', 'Camera is not ready.');
    }
    return c.takePicture();
  }

  Future<void> dispose() async {
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on CameraException {
      // Feature not supported on this lens; ignore.
    }
  }
}
