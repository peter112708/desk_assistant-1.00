// windows/runner/sticky_note_popup.h
#pragma once

#include <windows.h>
#include <string>
#include <flutter/binary_messenger.h>

// Lightweight Win32 sticky note popup (no Flutter engine dependency)
class StickyNotePopup {
 public:
  StickyNotePopup(const std::string& id,
                  const std::string& title,
                  const std::string& content,
                  int color_index,
                  int x,
                  int y,
                  flutter::BinaryMessenger* messenger);
  ~StickyNotePopup();

  bool Create();
  void Destroy();
  void UpdateContent(const std::string& title,
                     const std::string& content,
                     int color_index);

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp);
  friend void RegisterPopupClass();

  void OnPaint();
  void OnLButtonDown();
  void OnRButtonUp(int x, int y);
  void OnLButtonDblClk();
  void NotifyDartDeleted();

  static COLORREF GetNoteColor(int index);

  std::string id_;
  std::string title_;
  std::string content_;
  int color_index_ = 0;
  int x_ = 0, y_ = 0;
  bool expanded_ = false;
  bool collapsed_ever_ = false;

  HWND hwnd_ = nullptr;
  HFONT hfont_title_ = nullptr;
  HFONT hfont_content_ = nullptr;
  HBRUSH hbrush_bg_ = nullptr;
  flutter::BinaryMessenger* messenger_ = nullptr;

  static constexpr int kCollapsedWidth = 180;
  static constexpr int kCollapsedHeight = 36;
  static constexpr int kExpandedWidth = 260;
  static constexpr int kExpandedHeight = 200;
  static constexpr int kTitleBarHeight = 32;
};

// Moved outside the class so RegisterClass can access WndProc
void RegisterPopupClass();
