#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "sticky_note_popup.h"

using flutter::EncodableValue;
using flutter::EncodableMap;
using flutter::MethodCall;
using flutter::MethodResult;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  for (auto& [id, popup] : sticky_popups_) {
    if (popup) {
      popup->Destroy();
      delete popup;
    }
  }
  sticky_popups_.clear();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupStickyNotesChannel(flutter_controller_->engine());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  for (auto& [id, popup] : sticky_popups_) {
    if (popup) {
      popup->Destroy();
      delete popup;
    }
  }
  sticky_popups_.clear();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// Setup method channel: "sticky_notes" for Dart <-> Native communication
void FlutterWindow::SetupStickyNotesChannel(flutter::FlutterEngine* engine) {
  sticky_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      engine->messenger(), "sticky_notes",
      &flutter::StandardMethodCodec::GetInstance());

  sticky_channel_->SetMethodCallHandler(
      [this](const MethodCall<EncodableValue>& call,
             std::unique_ptr<MethodResult<EncodableValue>> result) {
        const auto& method = call.method_name();
        const auto* args = std::get_if<EncodableMap>(call.arguments());

        if (method == "createPopup") {
          if (!args) { result->Error("BAD_ARGS", "Expected map"); return; }
          auto id = std::get<std::string>((*args).at(EncodableValue("id")));
          auto title = std::get<std::string>((*args).at(EncodableValue("title")));
          auto content = std::get<std::string>((*args).at(EncodableValue("content")));
          auto color_index = std::get<int>((*args).at(EncodableValue("colorIndex")));
          auto x = std::get<int>((*args).at(EncodableValue("x")));
          auto y = std::get<int>((*args).at(EncodableValue("y")));

          CreateStickyPopup(id, title, content, color_index, x, y);
          result->Success(EncodableValue(true));

        } else if (method == "destroyPopup") {
          if (!args) { result->Error("BAD_ARGS", "Expected map"); return; }
          auto id = std::get<std::string>((*args).at(EncodableValue("id")));
          DestroyStickyPopup(id);
          result->Success(EncodableValue(true));

        } else if (method == "listPopups") {
          std::vector<EncodableValue> ids;
          for (const auto& [id, popup] : sticky_popups_) {
            ids.push_back(EncodableValue(id));
          }
          result->Success(EncodableValue(ids));

        } else if (method == "destroyAllPopups") {
          for (auto& [id, popup] : sticky_popups_) {
            if (popup) {
              popup->Destroy();
              delete popup;
            }
          }
          sticky_popups_.clear();
          result->Success(EncodableValue(true));

        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::CreateStickyPopup(const std::string& id,
                                      const std::string& title,
                                      const std::string& content,
                                      int color_index,
                                      int x, int y) {
  DestroyStickyPopup(id);

  auto* popup = new StickyNotePopup(
      id, title, content, color_index, x, y,
      flutter_controller_->engine()->messenger());
  if (popup->Create()) {
    sticky_popups_[id] = popup;
  } else {
    delete popup;
  }
}

void FlutterWindow::DestroyStickyPopup(const std::string& id) {
  auto it = sticky_popups_.find(id);
  if (it != sticky_popups_.end()) {
    if (it->second) {
      it->second->Destroy();
      delete it->second;
    }
    sticky_popups_.erase(it);
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
