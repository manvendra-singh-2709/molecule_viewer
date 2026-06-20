import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('showCameraVideo')
external JSBoolean _showCameraVideo();

@JS('hideCameraVideo')
external JSBoolean _hideCameraVideo();

class CameraBackground extends StatefulWidget {
  const CameraBackground({super.key});

  @override
  State<CameraBackground> createState() => _CameraBackgroundState();
}

class _CameraBackgroundState extends State<CameraBackground> {
  static const String viewType = 'hand-tracking-camera-view';
  static bool _registered = false;

  @override
  void initState() {
    super.initState();

    _showCameraVideo();

    if (!_registered) {
      _registered = true;

      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final web.Element? element =
              web.document.getElementById('handTrackingVideo');

          if (element is web.HTMLVideoElement) {
            _showCameraVideo();
            return element;
          }

          final web.HTMLDivElement div = web.HTMLDivElement()
            ..textContent = 'Camera not ready';

          div.style.width = '100%';
          div.style.height = '100%';
          div.style.backgroundColor = 'black';
          div.style.color = 'white';
          div.style.display = 'flex';
          div.style.alignItems = 'center';
          div.style.justifyContent = 'center';

          return div;
        },
      );
    }
  }

  @override
  void dispose() {
    _hideCameraVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: viewType);
  }
}