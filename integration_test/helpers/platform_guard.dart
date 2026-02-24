import 'dart:io' show Platform;

/// Returns a skip-reason string when [condition] is `false`, and `null`
/// (meaning "do not skip") when [condition] is `true`.
///
/// Pass the result directly to the `skip` parameter of [group] or [test]:
///
/// ```dart
/// group(
///   'real macOS OCR',
///   skip: platformSkip(Platform.isMacOS, 'requires macOS'),
///   () { … },
/// );
/// ```
///
/// This keeps platform-gate logic out of test bodies and makes the skip
/// reason visible in test output on unsupported platforms.
String? platformSkip(bool condition, String reason) =>
    condition ? null : reason;
