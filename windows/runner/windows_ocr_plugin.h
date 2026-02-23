#ifndef RUNNER_WINDOWS_OCR_PLUGIN_H_
#define RUNNER_WINDOWS_OCR_PLUGIN_H_

#include <flutter/flutter_engine.h>

/// Registers the WindowsOcrPlugin on the given Flutter engine.
///
/// The plugin listens on the `personal_archive/ocr` method channel and
/// exposes the WinRT `Windows.Media.Ocr` API to Dart.
void WindowsOcrPluginRegister(flutter::FlutterEngine* engine);

#endif  // RUNNER_WINDOWS_OCR_PLUGIN_H_
