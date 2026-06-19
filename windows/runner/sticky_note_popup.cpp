// windows/runner/sticky_note_popup.cpp
#include "sticky_note_popup.h"

#include <string>
#include <dwmapi.h>
#include <windowsx.h>

namespace {

constexpr const wchar_t kStickyPopupClass[] = L"STICKY_NOTE_POPUP_WINDOW";
static bool g_class_registered = false;
static HINSTANCE g_hinst = nullptr;

}  // namespace

void RegisterPopupClass() {
  if (g_class_registered) return;
  g_hinst = GetModuleHandle(nullptr);

  WNDCLASS wc{};
  wc.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
  wc.lpfnWndProc = StickyNotePopup::WndProc;
  wc.hInstance = g_hinst;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = nullptr;
  wc.lpszClassName = kStickyPopupClass;
  RegisterClass(&wc);
  g_class_registered = true;
}

StickyNotePopup::StickyNotePopup(const std::string& id,
                                 const std::string& title,
                                 const std::string& content,
                                 int color_index,
                                 int x,
                                 int y,
                                 flutter::BinaryMessenger* messenger)
    : id_(id),
      title_(title),
      content_(content),
      color_index_(color_index),
      x_(x),
      y_(y),
      messenger_(messenger) {
  expanded_ = false;     // start as a small side tab
  collapsed_ever_ = false;
}

StickyNotePopup::~StickyNotePopup() {
  Destroy();
}

bool StickyNotePopup::Create() {
  RegisterPopupClass();

  int w = kCollapsedWidth;
  int h = kCollapsedHeight;

  hwnd_ = CreateWindowEx(
      WS_EX_TOOLWINDOW | WS_EX_TOPMOST,
      kStickyPopupClass,
      L"Sticky",
      WS_POPUP,
      x_, y_, w, h,
      nullptr, nullptr, g_hinst, this);

  if (!hwnd_) return false;

  hfont_title_ = CreateFont(
      16, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei UI");

  hfont_content_ = CreateFont(
      13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei UI");

  hbrush_bg_ = CreateSolidBrush(GetNoteColor(color_index_));

  ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
  UpdateWindow(hwnd_);
  return true;
}

void StickyNotePopup::Destroy() {
  if (hfont_title_) { DeleteObject(hfont_title_); hfont_title_ = nullptr; }
  if (hfont_content_) { DeleteObject(hfont_content_); hfont_content_ = nullptr; }
  if (hbrush_bg_) { DeleteObject(hbrush_bg_); hbrush_bg_ = nullptr; }

  if (hwnd_) {
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
}

void StickyNotePopup::UpdateContent(const std::string& title,
                                    const std::string& content,
                                    int color_index) {
  title_ = title;
  content_ = content;
  color_index_ = color_index;
  if (hbrush_bg_) { DeleteObject(hbrush_bg_); }
  hbrush_bg_ = CreateSolidBrush(GetNoteColor(color_index_));
  if (hwnd_) InvalidateRect(hwnd_, nullptr, TRUE);
}

LRESULT CALLBACK StickyNotePopup::WndProc(HWND hwnd, UINT msg,
                                          WPARAM wp, LPARAM lp) {
  StickyNotePopup* self = nullptr;

  if (msg == WM_NCCREATE) {
    auto* cs = reinterpret_cast<CREATESTRUCT*>(lp);
    self = static_cast<StickyNotePopup*>(cs->lpCreateParams);
    SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    self->hwnd_ = hwnd;
  } else {
    self = reinterpret_cast<StickyNotePopup*>(
        GetWindowLongPtr(hwnd, GWLP_USERDATA));
  }

  if (!self) return DefWindowProc(hwnd, msg, wp, lp);

  switch (msg) {
    case WM_PAINT:
      self->OnPaint();
      return 0;

    case WM_LBUTTONDOWN:
      self->OnLButtonDown();
      return 0;

    case WM_LBUTTONDBLCLK:
      self->OnLButtonDblClk();
      return 0;

    case WM_RBUTTONUP:
      self->OnRButtonUp(GET_X_LPARAM(lp), GET_Y_LPARAM(lp));
      return 0;

    case WM_DESTROY:
      self->hwnd_ = nullptr;
      return 0;

    case WM_ERASEBKGND:
      return 1;
  }

  return DefWindowProc(hwnd, msg, wp, lp);
}

void StickyNotePopup::OnPaint() {
  PAINTSTRUCT ps;
  HDC hdc = BeginPaint(hwnd_, &ps);

  RECT rc;
  GetClientRect(hwnd_, &rc);
  int w = rc.right - rc.left;
  int h = rc.bottom - rc.top;

  HDC memdc = CreateCompatibleDC(hdc);
  HBITMAP membmp = CreateCompatibleBitmap(hdc, w, h);
  HBITMAP oldbmp = (HBITMAP)SelectObject(memdc, membmp);

  COLORREF bg = GetNoteColor(color_index_);
  HBRUSH bg_brush = CreateSolidBrush(bg);
  FillRect(memdc, &rc, bg_brush);
  DeleteObject(bg_brush);

  // Title bar (darker shade)
  RECT title_bar = {0, 0, w, kTitleBarHeight};
  COLORREF title_bg = RGB(
      (GetRValue(bg) * 3) / 4,
      (GetGValue(bg) * 3) / 4,
      (GetBValue(bg) * 3) / 4);
  HBRUSH title_brush = CreateSolidBrush(title_bg);
  FillRect(memdc, &title_bar, title_brush);
  DeleteObject(title_brush);

  // Bottom fade-out
  for (int i = 0; i < 20; i++) {
    int alpha = 20 - i;
    COLORREF fade = RGB(
        GetRValue(bg) + (255 - GetRValue(bg)) * alpha / 30,
        GetGValue(bg) + (255 - GetGValue(bg)) * alpha / 30,
        GetBValue(bg) + (255 - GetBValue(bg)) * alpha / 30);
    RECT line = {0, h - 20 + i, w, h - 19 + i};
    HBRUSH fade_brush = CreateSolidBrush(fade);
    FillRect(memdc, &line, fade_brush);
    DeleteObject(fade_brush);
  }

  // Title text
  SetBkMode(memdc, TRANSPARENT);
  SelectObject(memdc, hfont_title_);
  SetTextColor(memdc, RGB(30, 30, 46));

  std::wstring wtitle(title_.begin(), title_.end());
  RECT title_rc = {10, 4, w - 30, kTitleBarHeight};
  DrawText(memdc, wtitle.c_str(), -1, &title_rc,
           DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

  // Close button
  SetTextColor(memdc, RGB(80, 80, 100));
  RECT close_rc = {w - 28, 4, w - 8, kTitleBarHeight};
  DrawText(memdc, L"X", 1, &close_rc,
           DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // Content (only when expanded)
  if (expanded_ || !collapsed_ever_) {
    SetTextColor(memdc, RGB(50, 50, 70));
    SelectObject(memdc, hfont_content_);

    std::wstring wcontent(content_.begin(), content_.end());
    RECT content_rc = {10, kTitleBarHeight + 6, w - 10, h - 26};
    DrawText(memdc, wcontent.c_str(), -1, &content_rc,
             DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
  }

  BitBlt(hdc, 0, 0, w, h, memdc, 0, 0, SRCCOPY);
  SelectObject(memdc, oldbmp);
  DeleteObject(membmp);
  DeleteDC(memdc);
  EndPaint(hwnd_, &ps);
}

void StickyNotePopup::OnLButtonDown() {
  POINT pt;
  GetCursorPos(&pt);
  ScreenToClient(hwnd_, &pt);
  RECT rc;
  GetClientRect(hwnd_, &rc);
  int w = rc.right - rc.left;

  if (pt.x >= w - 30 && pt.y <= kTitleBarHeight) {
    NotifyDartDeleted();
    Destroy();
    return;
  }

  ReleaseCapture();
  SendMessage(hwnd_, WM_NCLBUTTONDOWN, HTCAPTION, 0);
}

void StickyNotePopup::OnLButtonDblClk() {
  collapsed_ever_ = true;

  if (expanded_) {
    expanded_ = false;
    SetWindowPos(hwnd_, nullptr, 0, 0,
                 kCollapsedWidth, kCollapsedHeight,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  } else {
    expanded_ = true;
    SetWindowPos(hwnd_, nullptr, 0, 0,
                 kExpandedWidth, kExpandedHeight,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
  InvalidateRect(hwnd_, nullptr, TRUE);
}

void StickyNotePopup::OnRButtonUp(int x, int y) {
  HMENU menu = CreatePopupMenu();
  AppendMenu(menu, MF_STRING, 1, L"Delete Sticky Note");

  POINT pt = {x, y};
  ClientToScreen(hwnd_, &pt);

  int cmd = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY,
      pt.x, pt.y, 0, hwnd_, nullptr);
  DestroyMenu(menu);

  if (cmd == 1) {
    NotifyDartDeleted();
    Destroy();
  }
}

void StickyNotePopup::NotifyDartDeleted() {
  if (!messenger_) return;

  std::string json = "{\"method\":\"popupDeleted\",\"id\":\"" + id_ + "\"}";
  messenger_->Send(
      "sticky_notes_events",
      reinterpret_cast<const uint8_t*>(json.c_str()),
      json.size());
}

COLORREF StickyNotePopup::GetNoteColor(int index) {
  switch (index % 6) {
    case 0: return RGB(255, 209, 102);
    case 1: return RGB(239, 71, 111);
    case 2: return RGB(6, 214, 160);
    case 3: return RGB(17, 138, 178);
    case 4: return RGB(232, 137, 189);
    case 5: return RGB(249, 199, 79);
    default: return RGB(255, 209, 102);
  }
}
