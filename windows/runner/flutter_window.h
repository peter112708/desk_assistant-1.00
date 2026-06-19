#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <unordered_map>
#include <string>

#include "win32_window.h"

class StickyNotePopup;

// A window that hosts a Flutter view and manages sticky note popups.
class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void SetupStickyNotesChannel(flutter::FlutterEngine* engine);
  void CreateStickyPopup(const std::string& id, const std::string& title,
                         const std::string& content, int color_index,
                         int x, int y);
  void DestroyStickyPopup(const std::string& id);

  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channel instance (must be held to keep handler alive)
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> sticky_channel_;

  // Sticky popup registry (id -> popup)
  std::unordered_map<std::string, StickyNotePopup*> sticky_popups_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
