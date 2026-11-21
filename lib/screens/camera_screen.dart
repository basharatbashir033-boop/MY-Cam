import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/camera_service.dart';
import '../services/gallery_service.dart';
import '../services/mirror_processor.dart';

/// true  = preview fills the whole screen (edges of the 4:3 photo are cropped
///         on screen, the saved photo still contains the full frame).
/// false = 4:3 preview exactly like the iPhone Camera app (what you see is
///         the full frame that gets saved).
const bool kFillScreen = true;

/// The camera plugin already shows the front camera mirrored on iOS, so only
/// the back camera preview needs an extra horizontal flip. If your preview of
/// the front camera ever looks un-mirrored, set this to false.
const bool kFrontPreviewIsMirroredByPlugin = true;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _service = CameraService();

  bool _ready = false;
  bool _busy = false;
  bool _flashOn = false;
  bool _screenFlash = false;
  bool _blink = false;
  bool _pausedByLifecycle = false;
  int _pending = 0;
  String? _error;
  String? _lastPhoto;
  Offset? _focusPoint;
  Future<void> _queue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    GalleryService.ensureAccess().catchError((_) => false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_pausedByLifecycle) {
      _pausedByLifecycle = true;
      if (mounted) setState(() => _ready = false);
      _service.dispose();
    } else if (state == AppLifecycleState.resumed && _pausedByLifecycle) {
      _pausedByLifecycle = false;
      _start(direction: _service.direction);
    }
  }

  Future<void> _start({CameraLensDirection? direction}) async {
    if (mounted) {
      setState(() {
        _ready = false;
        _error = null;
      });
    }
    try {
      await _service.initialize(direction: direction);
      await _service.setFlash(_flashOn);
      if (!mounted) return;
      setState(() => _ready = true);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'CameraAccessDenied' ||
                e.code == 'CameraAccessDeniedWithoutPrompt' ||
                e.code == 'CameraAccessRestricted'
            ? 'Camera access is off.\nEnable it in Settings > MY Cam > Camera.'
            : (e.description ?? 'Could not start the camera.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not start the camera.');
    }
  }

  Future<void> _flipCamera() async {
    if (_busy || !_service.hasMultipleCameras) return;
    HapticFeedback.selectionClick();
    final next = _service.isFront
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _start(direction: next);
  }

  Future<void> _toggleFlash() async {
    HapticFeedback.selectionClick();
    setState(() => _flashOn = !_flashOn);
    await _service.setFlash(_flashOn);
  }

  Future<void> _onCapture() async {
    if (_busy || !_ready || !_service.isReady) return;
    _busy = true;
    try {
      HapticFeedback.mediumImpact();

      if (_service.isFront && _flashOn) {
        setState(() => _screenFlash = true);
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }

      final raw = await _service.takePicture();

      if (!mounted) return;
      setState(() {
        _screenFlash = false;
        _blink = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (mounted) setState(() => _blink = false);
      });

      _enqueueSave(raw.path);
    } catch (e) {
      if (mounted) {
        setState(() => _screenFlash = false);
        _toast('Capture failed. Please try again.');
      }
    } finally {
      _busy = false;
    }
  }

  /// Photos are mirrored and saved one after another in the background so a
  /// 12MP image never has to compete with another one for memory.
  void _enqueueSave(String rawPath) {
    if (mounted) setState(() => _pending++);
    _queue = _queue.then((_) async {
      String? processed;
      try {
        processed = await MirrorProcessor.process(rawPath);
        await GalleryService.saveImage(processed);
        final previous = _lastPhoto;
        if (mounted) setState(() => _lastPhoto = processed);
        if (previous != null && previous != processed) {
          _deleteQuietly(previous);
        }
      } on GalleryPermissionException catch (e) {
        _toast(e.toString());
      } catch (e) {
        _toast('Could not save the photo.');
      } finally {
        _deleteQuietly(rawPath);
        if (mounted) setState(() => _pending--);
      }
    });
  }

  void _deleteQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Future<void> _openPhotos() async {
    HapticFeedback.selectionClick();
    try {
      await launchUrl(Uri.parse('photos-redirect://'));
    } catch (_) {
      _toast('Could not open Photos.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _onTapPreview(TapUpDetails d, Size box) async {
    if (!_ready) return;
    final dx = (d.localPosition.dx / box.width).clamp(0.0, 1.0);
    final dy = (d.localPosition.dy / box.height).clamp(0.0, 1.0);
    setState(() => _focusPoint = d.localPosition);
    // The picture on screen is mirrored, so mirror the x coordinate back.
    await _service.focusAt(Offset(1 - dx, dy));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _focusPoint = null);
  }

  // ---------------------------------------------------------------- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreviewLayer(),
          if (_screenFlash) Container(color: Colors.white),
          if (_blink) Container(color: Colors.black),
          _buildTopBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildPreviewLayer() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, size: 56, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _start, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final controller = _service.controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final size = controller.value.previewSize!;
    // previewSize is reported in landscape; portrait is height x width.
    Widget preview = SizedBox(
      width: size.height,
      height: size.width,
      child: CameraPreview(controller),
    );

    final needsFlip = _service.isFront ? !kFrontPreviewIsMirroredByPlugin : true;
    if (needsFlip) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: preview,
      );
    }

    Widget framed = kFillScreen
        ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: preview,
            ),
          )
        : Center(
            child: AspectRatio(
              aspectRatio: size.height / size.width,
              child: FittedBox(fit: BoxFit.cover, child: preview),
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onTapPreview(d, box),
          child: Stack(
            fit: StackFit.expand,
            children: [
              framed,
              if (_focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 36,
                  top: _focusPoint!.dy - 36,
                  child: IgnorePointer(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: const Color(0xFFFFCC00), width: 1.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _CircleButton(
                icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                color: _flashOn ? const Color(0xFFFFCC00) : Colors.white,
                onTap: _toggleFlash,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flip, size: 16, color: Color(0xFFFFCC00)),
                    SizedBox(width: 6),
                    Text(
                      'MIRROR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 128,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _GalleryThumb(
                  path: _lastPhoto,
                  busy: _pending > 0,
                  onTap: _openPhotos,
                ),
                _ShutterButton(onTap: _onCapture),
                _CircleButton(
                  icon: Icons.flip_camera_ios_outlined,
                  size: 52,
                  onTap: _flipCamera,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black38,
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.path,
    required this.busy,
    required this.onTap,
  });

  final String? path;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white70, width: 1.5),
          color: Colors.white10,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null)
              Image.file(
                File(path!),
                fit: BoxFit.cover,
                cacheWidth: 168,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white54,
                ),
              )
            else
              const Icon(Icons.photo_library_outlined, color: Colors.white54),
            if (busy)
              const ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: Container(
        width: 82,
        height: 82,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          margin: EdgeInsets.all(_down ? 5 : 0),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
