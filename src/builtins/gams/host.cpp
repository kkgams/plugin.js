#include "host.h"

#include "builtin.h"
#include "decode.h"
#include "encode.h"
#include "js/JSON.h"
#include "js_plugin.h"

#include <string>
#include <string_view>

namespace builtins::gams::host {
namespace {

DEF_ERR(HostCallTarget, JSEXN_TYPEERR, "host.{0} target must be a string", 1)
DEF_ERR(HostCallJson, JSEXN_TYPEERR, "host.{0} could not encode arguments as JSON", 1)
DEF_ERR(HostCallFailed, JSEXN_ERR, "host.{0} failed: {1}", 2)
DEF_ERR(HostCallResult, JSEXN_ERR, "host.call returned error: {0}", 1)

struct JsonCallback {
  std::u16string output;
  bool called = false;

  static bool write(const char16_t *str, uint32_t strlen, void *data) {
    auto *callback = static_cast<JsonCallback *>(data);
    callback->called = true;
    callback->output.append(str, strlen);
    return true;
  }
};

bool json_stringify(JSContext *cx, JS::HandleValue value, std::string *out) {
  JS::RootedObject replacer(cx);
  JS::RootedValue space(cx);
  JsonCallback callback;
  if (!JS::ToJSON(cx, value, replacer, space, &JsonCallback::write, &callback)) {
    return false;
  }
  if (!callback.called) {
    return api::throw_error(cx, HostCallJson, "call");
  }

  JS::RootedString json(cx, JS_NewUCStringCopyN(cx, callback.output.c_str(), callback.output.size()));
  if (!json) {
    return false;
  }
  auto encoded = core::encode(cx, json);
  if (!encoded) {
    return false;
  }
  *out = std::string(encoded.begin(), encoded.len);
  return true;
}

bool json_parse(JSContext *cx, std::string_view json, JS::MutableHandleValue out) {
  JS::RootedString text(cx, JS_NewStringCopyUTF8N(
                                cx, JS::UTF8Chars(json.data(), json.size())));
  if (!text) {
    return false;
  }
  return JS_ParseJSON(cx, text, out);
}

bool require_string_arg(JSContext *cx, JS::HandleValue value, const char *method, std::string *out) {
  if (!value.isString()) {
    return api::throw_error(cx, HostCallTarget, method);
  }
  auto encoded = core::encode(cx, value);
  if (!encoded) {
    return false;
  }
  *out = std::string(encoded.begin(), encoded.len);
  return true;
}

bool call_runtime(std::string_view target, std::string_view args_json, std::string *out,
                  std::string *err_out) {
  js_plugin_string_t target_wit{reinterpret_cast<uint8_t *>(const_cast<char *>(target.data())),
                                target.size()};
  js_plugin_string_t args_wit{reinterpret_cast<uint8_t *>(const_cast<char *>(args_json.data())),
                              args_json.size()};
  js_plugin_string_t ret{};
  js_plugin_string_t err{};
  bool ok = gams_runtime_runtime_call(&target_wit, &args_wit, &ret, &err);
  if (ok) {
    *out = std::string(reinterpret_cast<char *>(ret.ptr), ret.len);
    js_plugin_string_free(&ret);
    return true;
  }

  *err_out = std::string(reinterpret_cast<char *>(err.ptr), err.len);
  js_plugin_string_free(&err);
  return false;
}

bool raw_call(JSContext *cx, unsigned argc, JS::Value *vp) {
  CallArgs args = CallArgsFromVp(argc, vp);
  if (!args.requireAtLeast(cx, "host.rawCall", 2)) {
    return false;
  }

  std::string target;
  std::string args_json;
  if (!require_string_arg(cx, args.get(0), "rawCall", &target) ||
      !require_string_arg(cx, args.get(1), "rawCall", &args_json)) {
    return false;
  }

  std::string result;
  std::string err;
  if (!call_runtime(target, args_json, &result, &err)) {
    return api::throw_error(cx, HostCallFailed, "rawCall", err.c_str());
  }

  JS::RootedString result_str(cx, core::decode(cx, result));
  if (!result_str) {
    return false;
  }
  args.rval().setString(result_str);
  return true;
}

bool is_single_field_object(JSContext *cx, JS::HandleValue value, const char *field) {
  if (!value.isObject()) {
    return false;
  }
  JS::RootedObject object(cx, &value.toObject());
  JS::RootedIdVector ids(cx);
  if (!js::GetPropertyKeys(cx, object, JSITER_OWNONLY, &ids)) {
    return false;
  }
  if (ids.length() != 1 || !ids[0].isString()) {
    return false;
  }
  JS::RootedValue id_value(cx, js::IdToValue(ids[0]));
  auto encoded = core::encode(cx, id_value);
  return encoded && std::string_view(encoded.begin(), encoded.len) == field;
}

bool call(JSContext *cx, unsigned argc, JS::Value *vp) {
  CallArgs args = CallArgsFromVp(argc, vp);
  if (!args.requireAtLeast(cx, "host.call", 1)) {
    return false;
  }

  std::string target;
  if (!require_string_arg(cx, args.get(0), "call", &target)) {
    return false;
  }

  JS::RootedObject argv(cx, JS::NewArrayObject(cx, argc > 0 ? argc - 1 : 0));
  if (!argv) {
    return false;
  }
  for (unsigned i = 1; i < argc; i++) {
    if (!JS_DefineElement(cx, argv, i - 1, args.get(i), JSPROP_ENUMERATE)) {
      return false;
    }
  }

  JS::RootedValue argv_value(cx, JS::ObjectValue(*argv));
  std::string args_json;
  if (!json_stringify(cx, argv_value, &args_json)) {
    return false;
  }

  std::string result_json;
  std::string err;
  if (!call_runtime(target, args_json, &result_json, &err)) {
    return api::throw_error(cx, HostCallFailed, "call", err.c_str());
  }

  JS::RootedValue parsed(cx);
  if (!json_parse(cx, result_json, &parsed)) {
    return false;
  }

  if (is_single_field_object(cx, parsed, "ok")) {
    JS::RootedObject object(cx, &parsed.toObject());
    return JS_GetProperty(cx, object, "ok", args.rval());
  }

  if (is_single_field_object(cx, parsed, "err")) {
    JS::RootedObject object(cx, &parsed.toObject());
    JS::RootedValue err_value(cx);
    if (!JS_GetProperty(cx, object, "err", &err_value)) {
      return false;
    }
    JS::RootedString err_string(cx, JS::ToString(cx, err_value));
    if (!err_string) {
      return false;
    }
    auto encoded = core::encode(cx, err_string);
    if (!encoded) {
      return false;
    }
    std::string message(encoded.begin(), encoded.len);
    return api::throw_error(cx, HostCallResult, message.c_str());
  }

  args.rval().set(parsed);
  return true;
}

const JSFunctionSpec methods[] = {
    JS_FN("call", call, 1, JSPROP_ENUMERATE),
    JS_FN("rawCall", raw_call, 2, JSPROP_ENUMERATE),
    JS_FS_END,
};

} // namespace

bool install(api::Engine *engine) {
  JSContext *cx = engine->cx();
  JS::RootedObject host(cx, JS_NewPlainObject(cx));
  if (!host) {
    return false;
  }
  if (!JS_DefineProperty(cx, engine->global(), "host", host, JSPROP_ENUMERATE)) {
    return false;
  }
  return JS_DefineFunctions(cx, host, methods);
}

} // namespace builtins::gams::host
