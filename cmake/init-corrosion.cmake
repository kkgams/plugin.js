# Ensure that corrosion-rs is initialized, so we can use it or depend on variables it sets.
# NOTE: This file must not be called `corrosion.cmake`, because otherwise it'll be called recursively instead of the
# same-named one coming with Corrosion.

set(Rust_CARGO_TARGET wasm32-wasip1)
# Necessary to make cross-compiling to wasm32-wasi work for crates with -sys dependencies.
set(Rust_CARGO_TARGET_LINK_NATIVE_LIBS "")

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/rust-toolchain.toml" REQUIRED_RUST_VERSION REGEX "^channel ?=")
string(REGEX MATCH "[0-9.]+" REQUIRED_RUST_VERSION "${REQUIRED_RUST_VERSION}")
find_program(RUSTC rustc REQUIRED)
execute_process(COMMAND ${RUSTC} --version OUTPUT_VARIABLE RUSTC_VERSION OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
if(NOT RUSTC_VERSION MATCHES "^rustc ${REQUIRED_RUST_VERSION} ")
    message(FATAL_ERROR "Expected Rust ${REQUIRED_RUST_VERSION}; use nix develop")
endif()

CPMAddPackage("gh:corrosion-rs/corrosion@0.5.1")
string(TOLOWER ${Rust_CARGO_HOST_ARCH} HOST_ARCH)
