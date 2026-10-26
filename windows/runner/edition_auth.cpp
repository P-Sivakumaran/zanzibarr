#include "edition_auth.h"
#include <userconsentverifierinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Security.Credentials.UI.h>
#include <mutex>
#include <thread>
#include <string>
#include <vector>

namespace {
bool SetNativeAccess(bool granted) {
  auto module = GetModuleHandleW(L"rust_lib_zanzibarr.dll");
  if (!module && granted) {
    std::vector<wchar_t> path(32768);
    const DWORD size = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (!size || size >= path.size()) return false;
    std::wstring full(path.data(), size);
    const auto slash = full.find_last_of(L"\\/");
    if (slash == std::wstring::npos) return false;
    full.resize(slash + 1);
    full += L"rust_lib_zanzibarr.dll";
    module = LoadLibraryExW(full.c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  }
  if (!module) return false;
  using SetAccess = bool (*)(unsigned char);
  const auto set_access = reinterpret_cast<SetAccess>(
      GetProcAddress(module, "zanzibarr_set_restricted_access"));
  return set_access && set_access(granted ? 1 : 0);
}
}


using winrt::Windows::Security::Credentials::UI::UserConsentVerifier;
using winrt::Windows::Security::Credentials::UI::UserConsentVerificationResult;
using Verification = winrt::Windows::Foundation::IAsyncOperation<UserConsentVerificationResult>;

struct EditionAuthentication::State {
  std::mutex mutex;
  HWND window;
  unsigned generation = 0;
  bool verified = false;
  Verification operation{nullptr};
};

EditionAuthentication::EditionAuthentication(HWND window)
    : state_(std::make_shared<State>()) { state_->window = window; }

EditionAuthentication::~EditionAuthentication() {
  Cancel();
  std::lock_guard<std::mutex> lock(state_->mutex);
  state_->window = nullptr;
}

void EditionAuthentication::Cancel() {
  SetNativeAccess(false);
  Verification operation{nullptr};
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    ++state_->generation;
    operation = state_->operation;
    state_->operation = nullptr;
  }
  try { if (operation) operation.Cancel(); } catch (...) {}
  if (result_) {
    result_->Success(flutter::EncodableValue(false));
    result_.reset();
  }
}

void EditionAuthentication::Authenticate(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (result_) {
    result->Success(flutter::EncodableValue(false));
    return;
  }
  try {
    const winrt::hstring message = L"Unlock Zanzibarr Restricted";
    auto interop = winrt::get_activation_factory<UserConsentVerifier,
        ::IUserConsentVerifierInterop>();
    auto operation = winrt::capture<Verification>(interop,
        &::IUserConsentVerifierInterop::RequestVerificationForWindowAsync,
        state_->window, reinterpret_cast<HSTRING>(winrt::get_abi(message)));
    unsigned generation;
    {
      std::lock_guard<std::mutex> lock(state_->mutex);
      generation = ++state_->generation;
      state_->operation = operation;
      state_->verified = false;
    }
    result_ = std::move(result);
    auto state = state_;
    std::thread([state, operation, generation]() {
      bool verified = false;
      try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        try { verified = operation.get() == UserConsentVerificationResult::Verified; }
        catch (...) {}
        winrt::uninit_apartment();
      } catch (...) {}
      std::lock_guard<std::mutex> lock(state->mutex);
      if (!state->window || state->generation != generation) return;
      state->verified = verified;
      PostMessage(state->window, EditionAuthentication::kCompleted, generation, 0);
    }).detach();
  } catch (...) {
    if (result) result->Success(flutter::EncodableValue(false));
    else Cancel();
  }
}

void EditionAuthentication::Complete(WPARAM generation) {
  bool verified;
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    if (generation != state_->generation || !result_) return;
    verified = state_->verified;
    state_->operation = nullptr;
  }
  verified = verified && SetNativeAccess(true);
  result_->Success(flutter::EncodableValue(verified));
  result_.reset();
}
