import Cocoa
import FlutterMacOS
import Vision

/// Flutter method-channel plugin that exposes Apple Vision text recognition
/// to the Dart side.
///
/// Channel: `personal_archive/ocr`
///
/// ## Methods
///
/// ### `recognizeText`
///
/// **Arguments** (map):
/// - `filePath` (`String`, optional) – path to an image file on disk.
/// - `imageBytes` (`FlutterStandardTypedData`, optional) – raw image bytes
///   (PNG, JPEG, TIFF, or any format loadable by `CGImageSource`).
///
/// Exactly one of the two must be provided.
///
/// **Returns** (map):
/// - `text` (`String`) – the concatenated recognised text.
/// - `confidence` (`Double?`) – mean per-observation confidence (0.0–1.0),
///   or `nil` if unavailable.
///
/// **Errors** (`FlutterError`):
/// - `INVALID_ARGUMENTS` – neither or both input keys supplied.
/// - `IMAGE_LOAD_FAILED` – the image could not be decoded to a `CGImage`.
/// - `OCR_FAILED` – Vision request failed.
class VisionOcrPlugin {
  static let channelName = "personal_archive/ocr"

  /// Registers this plugin on the given [registrar].
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    let instance = VisionOcrPlugin()
    channel.setMethodCallHandler(instance.handle)
  }

  // MARK: - Method dispatch

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "recognizeText":
      handleRecognizeText(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - recognizeText

  private func handleRecognizeText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(
        code: "INVALID_ARGUMENTS",
        message: "Arguments must be a map",
        details: nil
      ))
      return
    }

    let filePath = args["filePath"] as? String
    let imageBytes = args["imageBytes"] as? FlutterStandardTypedData

    guard (filePath != nil) != (imageBytes != nil) else {
      result(FlutterError(
        code: "INVALID_ARGUMENTS",
        message: "Provide exactly one of 'filePath' or 'imageBytes'",
        details: nil
      ))
      return
    }

    // Load CGImage
    let cgImage: CGImage
    do {
      if let path = filePath {
        cgImage = try loadImageFromFile(path)
      } else {
        cgImage = try loadImageFromBytes(imageBytes!.data)
      }
    } catch {
      result(FlutterError(
        code: "IMAGE_LOAD_FAILED",
        message: "Could not decode image: \(error.localizedDescription)",
        details: nil
      ))
      return
    }

    // Run Vision on a background queue so we never block the platform thread.
    let workItem = DispatchWorkItem { [weak self] in
      self?.recognizeText(in: cgImage, result: result)
    }
    DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
  }

  // MARK: - Image loading helpers

  private func loadImageFromFile(_ path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw NSError(
        domain: "VisionOcrPlugin",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to load image at \(path)"]
      )
    }
    return image
  }

  private func loadImageFromBytes(_ data: Data) throws -> CGImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw NSError(
        domain: "VisionOcrPlugin",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to decode image from bytes"]
      )
    }
    return image
  }

  // MARK: - Vision text recognition

  private func recognizeText(in image: CGImage, result: @escaping FlutterResult) {
    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "OCR_FAILED",
            message: "Vision text recognition failed: \(error.localizedDescription)",
            details: nil
          ))
        }
        return
      }

      guard let observations = request.results as? [VNRecognizedTextObservation] else {
        DispatchQueue.main.async {
          result(["text": "", "confidence": nil] as [String: Any?])
        }
        return
      }

      var lines: [String] = []
      var totalConfidence: Float = 0

      for observation in observations {
        if let candidate = observation.topCandidates(1).first {
          lines.append(candidate.string)
          totalConfidence += candidate.confidence
        }
      }

      let text = lines.joined(separator: "\n")
      let meanConfidence: Double? = observations.isEmpty
        ? nil
        : Double(totalConfidence / Float(observations.count))

      DispatchQueue.main.async {
        result(["text": text, "confidence": meanConfidence] as [String: Any?])
      }
    }

    request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
      try handler.perform([request])
    } catch {
      DispatchQueue.main.async {
        result(FlutterError(
          code: "OCR_FAILED",
          message: "Vision request handler failed: \(error.localizedDescription)",
          details: nil
        ))
      }
    }
  }
}
