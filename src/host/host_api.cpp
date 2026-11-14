#include "host_api.h"
#include "extension-api.h"
#include <algorithm>
#include <cstdio>

size_t api::AsyncTask::select(std::vector<RefPtr<AsyncTask>> &tasks) {
  std::erase_if(
      tasks, [](const RefPtr<AsyncTask> &task) { return task->id() == INVALID_POLLABLE_HANDLE; });
  MOZ_RELEASE_ASSERT(!tasks.empty());
  return 0;
}

namespace host_api {

Result<uint32_t> Random::get_u32() {
  // Keep starling-lite self-contained as a GAMS plugin: do not require a custom
  // host random import. This is only used by the local preview1 shim until the
  // runtime grows real WASI random wiring.
  static uint32_t state = 0x853c49e6u;
  state = (state * 1664525u) + 1013904223u;
  return Result<uint32_t>::ok(state);
}

void log(std::string_view msg) {
  // Avoid a custom logging import; GAMS should be able to instantiate this
  // component with only gams:runtime/runtime@1.0.0.
  if (!msg.empty()) {
    (void)fwrite(msg.data(), 1, msg.size(), stderr);
  }
}

std::vector<std::string> environment_get_arguments() { return {}; }

std::optional<std::string> environment_get_variable(std::string_view) { return std::nullopt; }

} // namespace host_api
