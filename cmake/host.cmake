add_library(host_api STATIC
  ${HOST_API}/host_api.cpp
  ${HOST_API}/bindings/js_plugin.c
  ${HOST_API}/bindings/js_plugin_component_type.o
)

target_link_libraries(host_api PRIVATE spidermonkey)

target_include_directories(host_api PUBLIC
  ${HOST_API}/include
  ${HOST_API}/bindings
  ${CMAKE_CURRENT_SOURCE_DIR}/src/include
  ${CMAKE_CURRENT_SOURCE_DIR}/src/runtime
  ${CMAKE_CURRENT_SOURCE_DIR}/src/crates/rust-url
)

# gams-js intentionally imports only gams:runtime/runtime@1.0.0.
# No WASI CLI, preview1 adapter, wasi:http, sockets, filesystem, or random APIs yet.
