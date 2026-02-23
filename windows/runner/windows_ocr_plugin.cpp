#include "windows_ocr_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <filesystem>
#include <memory>
#include <string>
#include <vector>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Graphics::Imaging;
using namespace Windows::Storage;
using namespace Windows::Storage::Streams;

using ResultPtr =
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>;

/// Loads an image file into a SoftwareBitmap (Bgra8, pre-multiplied alpha).
/// The path is UTF-8; it is converted to a wide string for the Windows API.
static IAsyncOperation<SoftwareBitmap> LoadBitmapFromFile(std::string path) {
  auto wpath = std::filesystem::u8path(path).wstring();
  auto file = co_await StorageFile::GetFileFromPathAsync(wpath);
  auto stream = co_await file.OpenAsync(FileAccessMode::Read);
  auto decoder = co_await BitmapDecoder::CreateAsync(stream);
  co_return co_await decoder.GetSoftwareBitmapAsync(
      BitmapPixelFormat::Bgra8, BitmapAlphaMode::Premultiplied);
}

/// Loads in-memory image bytes into a SoftwareBitmap (Bgra8, pre-multiplied).
/// Accepts any format decodable by WIC (PNG, JPEG, BMP, TIFF, GIF, JPEG-XR).
static IAsyncOperation<SoftwareBitmap> LoadBitmapFromBytes(
    std::vector<uint8_t> bytes) {
  InMemoryRandomAccessStream mem_stream;
  DataWriter writer(mem_stream);
  writer.WriteBytes(array_view<const uint8_t>(bytes));
  co_await writer.StoreAsync();
  co_await writer.FlushAsync();
  writer.DetachStream();
  mem_stream.Seek(0);

  auto decoder = co_await BitmapDecoder::CreateAsync(mem_stream);
  co_return co_await decoder.GetSoftwareBitmapAsync(
      BitmapPixelFormat::Bgra8, BitmapAlphaMode::Premultiplied);
}

static fire_and_forget HandleRecognizeText(flutter::EncodableMap args,
                                           ResultPtr result) {
  apartment_context ui_thread;

  const auto file_it = args.find(flutter::EncodableValue("filePath"));
  const auto bytes_it = args.find(flutter::EncodableValue("imageBytes"));

  const bool has_file =
      file_it != args.end() &&
      std::holds_alternative<std::string>(file_it->second);
  const bool has_bytes =
      bytes_it != args.end() &&
      std::holds_alternative<std::vector<uint8_t>>(bytes_it->second);

  if (has_file == has_bytes) {
    co_await ui_thread;
    result->Error("INVALID_ARGUMENTS",
                  "Provide exactly one of 'filePath' or 'imageBytes'");
    co_return;
  }

  SoftwareBitmap bitmap{nullptr};
  try {
    if (has_file) {
      bitmap = co_await LoadBitmapFromFile(
          std::get<std::string>(file_it->second));
    } else {
      bitmap = co_await LoadBitmapFromBytes(
          std::get<std::vector<uint8_t>>(bytes_it->second));
    }
  } catch (const hresult_error& e) {
    co_await ui_thread;
    result->Error("IMAGE_LOAD_FAILED", to_string(e.message()));
    co_return;
  }

  auto engine = Windows::Media::Ocr::OcrEngine::TryCreateFromUserProfileLanguages();
  if (!engine) {
    co_await ui_thread;
    result->Error("OCR_UNAVAILABLE",
                  "No OCR engine available for the current user languages");
    co_return;
  }

  auto ocr_result = co_await engine.RecognizeAsync(bitmap);

  auto text = to_string(ocr_result.Text());

  // Windows.Media.Ocr does not expose a per-result confidence score.
  co_await ui_thread;
  flutter::EncodableMap response;
  response[flutter::EncodableValue("text")] =
      flutter::EncodableValue(std::move(text));
  response[flutter::EncodableValue("confidence")] =
      flutter::EncodableValue();
  result->Success(flutter::EncodableValue(response));
}

static void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "recognizeText") {
    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
      return;
    }
    HandleRecognizeText(*args, ResultPtr(std::move(result)));
  } else {
    result->NotImplemented();
  }
}

void WindowsOcrPluginRegister(flutter::FlutterEngine* engine) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "personal_archive/ocr",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  channel.release();
}
