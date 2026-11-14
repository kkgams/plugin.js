cmake_minimum_required(VERSION 3.27)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)

# This repository builds one artifact: the GAMS JavaScript plugin component.
set(HOST_API ${CMAKE_CURRENT_SOURCE_DIR}/host-apis/my-minimal)
message(STATUS "Using host API: ${HOST_API}")

# Keep CPM downloads outside individual build directories.
if(NOT DEFINED ENV{CPM_SOURCE_CACHE})
    set(ENV{CPM_SOURCE_CACHE} ${CMAKE_CURRENT_SOURCE_DIR}/build.nosync/cpm)
endif()

include("CPM")
include("toolchain")

project(gams-js-plugin)

include("init-corrosion")
include("wasm-tools")
include("binaryen")
include("weval")
include("wasmtime")
include("spidermonkey")
include("${HOST_API}/host_api.cmake")
include("build-crates")

add_library(extension_api INTERFACE include/extension-api.h runtime/encode.h runtime/decode.h)
target_link_libraries(extension_api INTERFACE rust-url spidermonkey)
target_include_directories(extension_api INTERFACE include deps/include runtime)

include("builtins")

set(SOURCES
    runtime/js.cpp
    host-apis/my-minimal/wasi_shim.cpp
    runtime/allocator.cpp
    runtime/encode.cpp
    runtime/decode.cpp
    runtime/engine.cpp
    runtime/event_loop.cpp
    runtime/builtin.cpp
    runtime/script_loader.cpp
    runtime/debugger.cpp
)

add_executable(starling-raw.wasm ${SOURCES})
target_link_libraries(starling-raw.wasm PRIVATE host_api extension_api builtins spidermonkey rust-crates)
target_link_options(starling-raw.wasm PRIVATE -Wl,--allow-multiple-definition)

option(USE_WASM_OPT "use wasm-opt to optimize the raw wasm binary" ON)

if (USE_WASM_OPT)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
        add_custom_command(
            TARGET starling-raw.wasm
            POST_BUILD
            COMMAND ${WASM_OPT} --strip-debug -O3 -o starling-raw.wasm starling-raw.wasm
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )
    elseif (CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
        add_custom_command(
            TARGET starling-raw.wasm
            POST_BUILD
            COMMAND ${WASM_OPT} -O3 -g -o starling-raw.wasm starling-raw.wasm
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )
    endif()
else()
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
        add_custom_command(
            TARGET starling-raw.wasm
            POST_BUILD
            COMMAND ${WASM_OPT} --strip-debug -O0 -o starling-raw.wasm starling-raw.wasm
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )
    endif()
endif()

# Optional AOT compilation cache for `cmake -DWEVAL=ON` builds.
if(WEVAL)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/null.js "function main() {}")
    add_custom_target(
        starling-ics.wevalcache
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND rm -f starling-ics.wevalcache
        COMMAND echo ./null.js | ${WEVAL_BIN} weval --dir . --show-stats --cache starling-ics.wevalcache -w -i starling-raw.wasm -o /dev/null
        DEPENDS starling-raw.wasm
        VERBATIM
    )
    set(AOT 1)
else()
    set(AOT 0)
endif()

set(ADAPTER_FILE "gams-js-preview1-fd-write-adapter.wasm")
set(ADAPTER_WAT "${CMAKE_CURRENT_BINARY_DIR}/gams-js-preview1-fd-write-adapter.wat")
set(ADAPTER "${CMAKE_CURRENT_BINARY_DIR}/${ADAPTER_FILE}")
file(WRITE ${ADAPTER_WAT} "(module\n  ;; Satisfy wasi-libc's residual fd_write import without exposing preview1 fd_write to the host.\n  (func (export \"fd_write\") (param i32 i32 i32 i32) (result i32)\n    i32.const 0)\n)\n")
execute_process(
    COMMAND ${WASM_TOOLS_BIN} parse ${ADAPTER_WAT} -o ${ADAPTER}
    RESULT_VARIABLE ADAPTER_BUILD_RESULT
)
if(NOT ADAPTER_BUILD_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to build minimal preview1 fd_write adapter")
endif()

configure_file("componentize.sh.in" "${CMAKE_CURRENT_BINARY_DIR}/componentize.sh" @ONLY)

add_custom_command(
    OUTPUT gams-js.wasm
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/componentize.sh -o gams-js.wasm
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/componentize.sh starling-raw.wasm
    VERBATIM
)
add_custom_target(gams-js ALL DEPENDS gams-js.wasm)
