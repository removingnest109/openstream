import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'src/openstream_app.dart';

const _windowWidthKey = 'openstream.windowWidth';
const _windowHeightKey = 'openstream.windowHeight';
const _windowXKey = 'openstream.windowX';
const _windowYKey = 'openstream.windowY';
const _windowStateKey = 'openstream.windowState';

const _windowStateNormal = 'normal';
const _windowStateMaximized = 'maximized';
const _windowStateFullscreen = 'fullscreen';

const _defaultDesktopWindowSize = Size(1280, 820);
const _minimumDesktopWindowSize = Size(900, 620);

_WindowSizePersistenceListener? _windowSizePersistenceListener;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktopPlatform()) {
    JustAudioMediaKit.ensureInitialized();
    await _initializeDesktopWindowState();
  }

  runApp(const OpenStreamApp());
}

Future<void> _initializeDesktopWindowState() async {
  final prefs = await SharedPreferences.getInstance();

  await windowManager.ensureInitialized();

  final savedWidth = prefs.getDouble(_windowWidthKey);
  final savedHeight = prefs.getDouble(_windowHeightKey);
  final savedX = prefs.getDouble(_windowXKey);
  final savedY = prefs.getDouble(_windowYKey);
  final savedWindowState =
      prefs.getString(_windowStateKey) ?? _windowStateNormal;
  final hasSavedSize =
      savedWidth != null &&
      savedHeight != null &&
      savedWidth > 0 &&
      savedHeight > 0;
  final hasSavedPosition =
      savedX != null && savedY != null && savedX.isFinite && savedY.isFinite;

  final windowSize = hasSavedSize
      ? Size(savedWidth, savedHeight)
      : _defaultDesktopWindowSize;

  final windowOptions = WindowOptions(
    size: windowSize,
    center: !hasSavedPosition,
    minimumSize: _minimumDesktopWindowSize,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (hasSavedPosition) {
      await windowManager.setPosition(Offset(savedX, savedY));
    }

    await windowManager.show();

    if (savedWindowState == _windowStateMaximized) {
      await windowManager.maximize();
    } else if (savedWindowState == _windowStateFullscreen) {
      await windowManager.setFullScreen(true);
    }

    await windowManager.focus();
  });

  _windowSizePersistenceListener = _WindowSizePersistenceListener(prefs);
  windowManager.addListener(_windowSizePersistenceListener!);
}

bool _isDesktopPlatform() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.linux:
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class _WindowSizePersistenceListener extends WindowListener {
  _WindowSizePersistenceListener(this._prefs);

  final SharedPreferences _prefs;
  Timer? _debounceTimer;

  @override
  void onWindowResize() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen()) {
        return;
      }

      final size = await windowManager.getSize();
      await _prefs.setDouble(_windowWidthKey, size.width);
      await _prefs.setDouble(_windowHeightKey, size.height);
    });
  }

  @override
  void onWindowMove() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen()) {
        return;
      }

      final position = await windowManager.getPosition();
      await _prefs.setDouble(_windowXKey, position.dx);
      await _prefs.setDouble(_windowYKey, position.dy);
    });
  }

  @override
  void onWindowMaximize() {
    unawaited(_prefs.setString(_windowStateKey, _windowStateMaximized));
  }

  @override
  void onWindowUnmaximize() {
    unawaited(_prefs.setString(_windowStateKey, _windowStateNormal));
  }

  @override
  void onWindowEnterFullScreen() {
    unawaited(_prefs.setString(_windowStateKey, _windowStateFullscreen));
  }

  @override
  void onWindowLeaveFullScreen() {
    unawaited(_prefs.setString(_windowStateKey, _windowStateNormal));
  }
}
