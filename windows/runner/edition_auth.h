#ifndef RUNNER_EDITION_AUTH_H_
#define RUNNER_EDITION_AUTH_H_
#include <flutter/encodable_value.h>
#include <flutter/method_result.h>
#include <windows.h>
#include <memory>

// Callbacks are delivered on the platform window thread, never from the worker.
class EditionAuthentication {
 public:
  static constexpr UINT kCompleted = WM_APP + 42;
  explicit EditionAuthentication(HWND window);
  ~EditionAuthentication();
  void Authenticate(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Cancel();
  void Complete(WPARAM generation);
 private:
  struct State;
  std::shared_ptr<State> state_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result_;
};
#endif
