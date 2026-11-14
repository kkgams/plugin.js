find_program(WASM_OPT wasm-opt REQUIRED)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/cxx-wrapper.in ${CMAKE_BINARY_DIR}/cxx-wrapper)
set(CMAKE_CXX_COMPILER "${CMAKE_BINARY_DIR}/cxx-wrapper")
