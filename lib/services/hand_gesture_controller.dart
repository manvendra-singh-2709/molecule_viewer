import 'dart:async';
import 'dart:js_interop';

@JS('initHandTracking')
external JSPromise<JSBoolean> _initHandTracking();

@JS('getHandGesture')
external JSObject? _getHandGesture();

@JS('requestCameraAgain')
external JSPromise<JSBoolean> _requestCameraAgain();

@JS('getCameraPermissionStatus')
external JSString? _getCameraPermissionStatus();

extension GestureObject on JSObject {
  external double get pinchDistance;
  external double get rotationX;
  external double get rotationY;
  external double get rotationZ;
}

class HandGesture {
  final double scale;
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  const HandGesture({
    required this.scale,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
  });
}

class HandGestureController {
  void Function(HandGesture gesture)? onGestureUpdate;

  Timer? _timer;
  bool _started = false;

  final double scaleSensitivity = 0.8;
  final double rotationSensitivity = 10.0;

  final double minScale = 0.3;
  final double maxScale = 5.0;

  final double smoothAlpha = 0.14;

  double _currentScale = 1.0;
  double _currentRx = 0.0;
  double _currentRy = 0.0;
  double _currentRz = 0.0;

  double _baseScale = 1.0;
  double _baseRx = 0.0;
  double _baseRy = 0.0;
  double _baseRz = 0.0;

  double? _startPinch;
  double? _startPalmX;
  double? _startPalmY;

  bool _handWasVisible = false;

  Future<bool> initializeOnly() async {
    final JSBoolean ok = await _initHandTracking().toDart;
    return ok.toDart;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final bool initialized = await initializeOnly();

    if (!initialized) {
      _started = false;
      print('Failed to initialize MediaPipe');
      return;
    }

    _timer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        final JSObject? obj = _getHandGesture();

        if (obj == null) {
          _handWasVisible = false;
          _startPinch = null;
          _startPalmX = null;
          _startPalmY = null;
          return;
        }

        final double pinch = obj.pinchDistance;

        final double palmY = obj.rotationX;
        final double palmX = obj.rotationY;

        if (!_handWasVisible) {
          _handWasVisible = true;

          _baseScale = _currentScale;
          _baseRx = _currentRx;
          _baseRy = _currentRy;
          _baseRz = _currentRz;

          _startPinch = pinch;
          _startPalmX = palmX;
          _startPalmY = palmY;
        }

        final double startPinch = _startPinch ?? pinch;
        final double startPalmX = _startPalmX ?? palmX;
        final double startPalmY = _startPalmY ?? palmY;

        final double rawScaleRatio = pinch / startPinch;

        final double targetScale = (_baseScale *
                (1.0 + (rawScaleRatio - 1.0) * scaleSensitivity))
            .clamp(minScale, maxScale);

        final double deltaPalmX = palmX - startPalmX;
        final double deltaPalmY = palmY - startPalmY;

        final double targetRy =
            _baseRy + deltaPalmX * rotationSensitivity;

        final double targetRx =
            _baseRx + deltaPalmY * rotationSensitivity;

        final double targetRz = _baseRz;

        _currentScale += (targetScale - _currentScale) * smoothAlpha;
        _currentRx += (targetRx - _currentRx) * smoothAlpha;
        _currentRy += (targetRy - _currentRy) * smoothAlpha;
        _currentRz += (targetRz - _currentRz) * smoothAlpha;

        onGestureUpdate?.call(
          HandGesture(
            scale: _currentScale,
            rotationX: _currentRx,
            rotationY: _currentRy,
            rotationZ: _currentRz,
          ),
        );
      },
    );
  }

  Future<bool> requestCameraAgain() async {
    final JSBoolean ok = await _requestCameraAgain().toDart;
    return ok.toDart;
  }

  String? getCameraPermissionStatus() {
    return _getCameraPermissionStatus()?.toDart;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}