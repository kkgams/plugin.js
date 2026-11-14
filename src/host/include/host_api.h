#pragma once

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "js/Utility.h"
#include "rust-url.h"

using std::optional;
using std::string_view;
using std::tuple;
using std::unique_ptr;
using std::vector;

namespace host_api {

using APIError = uint8_t;

struct Void final {};

template <typename T> class Result final {
  bool err_ = false;
  APIError error_ = 0;
  T value_{};

public:
  static Result ok(T value) {
    Result res;
    res.value_ = std::move(value);
    return res;
  }
  static Result err(APIError err) {
    Result res;
    res.err_ = true;
    res.error_ = err;
    return res;
  }
  bool is_err() const { return err_; }
  const APIError *to_err() const { return err_ ? &error_ : nullptr; }
  T &unwrap() { return value_; }
  const T &unwrap() const { return value_; }
};

struct HostString final {
  JS::UniqueChars ptr;
  size_t len = 0;

  HostString() = default;
  HostString(std::nullptr_t) : HostString() {}
  HostString(const char *c_str) {
    len = strlen(c_str);
    ptr = JS::UniqueChars(static_cast<char *>(malloc(len + 1)));
    std::memcpy(ptr.get(), c_str, len);
    ptr[len] = '\0';
  }
  HostString(const std::string_view &str) {
    ptr = JS::UniqueChars(static_cast<char *>(malloc(str.size())));
    std::memcpy(ptr.get(), str.data(), str.size());
    len = str.size();
  }
  HostString(JS::UniqueChars ptr, size_t len) : ptr{std::move(ptr)}, len{len} {}

  HostString(const HostString &) = delete;
  HostString &operator=(const HostString &) = delete;
  HostString(HostString &&other) : ptr{std::move(other.ptr)}, len{other.len} {}
  HostString &operator=(HostString &&other) {
    ptr.reset(other.ptr.release());
    len = other.len;
    return *this;
  }

  using iterator = char *;
  using const_iterator = const char *;
  size_t size() const { return len; }
  iterator begin() { return ptr.get(); }
  iterator end() { return begin() + len; }
  const_iterator begin() const { return ptr.get(); }
  const_iterator end() const { return begin() + len; }
  operator bool() const { return ptr != nullptr; }
  bool operator==(std::nullptr_t) { return ptr == nullptr; }
  bool operator!=(std::nullptr_t) { return ptr != nullptr; }
  operator std::string_view() const { return std::string_view(ptr.get(), len); }
  operator jsurl::SpecString() {
    return jsurl::SpecString(reinterpret_cast<uint8_t *>(ptr.release()), len, len);
  }
  operator const jsurl::SpecString() const {
    return jsurl::SpecString(reinterpret_cast<uint8_t *>(ptr.get()), len, len);
  }
};

struct Random {
  static Result<uint32_t> get_u32();
};

void log(std::string_view msg);

std::vector<std::string> environment_get_arguments();
std::optional<std::string> environment_get_variable(std::string_view name);

} // namespace host_api
