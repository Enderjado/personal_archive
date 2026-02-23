#include "windows_ocr_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

static void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void WindowsOcrPluginRegister(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "personal_archive/ocr",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  // prevent the channel from being destroyed when this scope exits
  // (the ref is held internally by the engine's messenger)
  channel.release();
}
