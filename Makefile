.DEFAULT_GOAL := build

BUILD_TYPE ?= Release
BUILD_DIR := build.nosync/cmake
CMAKE_CONFIGURE_FLAGS ?=
CMAKE_BUILD_FLAGS ?=
NCPUS ?= 4
PYTHON ?= python3
CURL ?= curl

ARTIFACT := build.nosync/plugin.js.wasm
NATIVE_ARTIFACT := $(BUILD_DIR)/plugin.js.wasm
CMAKE_CACHE := $(BUILD_DIR)/CMakeCache.txt
SOURCE_DIRS := src wit cmake scripts nix
BUILD_INPUTS := . CMakeLists.txt scripts/componentize.sh.in rust-toolchain.toml Cargo.lock flake.nix flake.lock $(shell find $(SOURCE_DIRS) -type f ! -name '*.pyc' ! -name .DS_Store) $(shell find $(SOURCE_DIRS) -type d)
CMAKE_INPUTS := CMakeLists.txt Makefile flake.nix flake.lock Cargo.lock rust-toolchain.toml scripts/componentize.sh.in $(shell find cmake -name '*.cmake' -type f) $(shell find cmake -type d) $(wildcard src/crates/*/Cargo.toml cmake/rust-staticlib/*)
NOTICE_INPUTS := . NOTICE LICENSE $(shell find licenses -type f ! -name .DS_Store) $(shell find licenses -type d) src/crates/rust-hooks/Cargo.toml src/crates/rust-hooks/src/lib.rs src/crates/rust-hooks/src/wrappers.cpp

export BUILD_TYPE CMAKE_CONFIGURE_FLAGS CMAKE_BUILD_FLAGS
export TMPDIR := $(CURDIR)/build.nosync/tmp
export CARGO_HOME := $(CURDIR)/build.nosync/cargo
export CARGO_TARGET_DIR := $(CURDIR)/build.nosync/cargo-target
export CPM_SOURCE_CACHE := $(CURDIR)/build.nosync/cpm

.PHONY: build package configure clean open docs serve-docs validate-docs FORCE
build: $(ARTIFACT)
package: $(ARTIFACT) build.nosync/SHA256SUMS
configure: $(CMAKE_CACHE)

build.nosync/tmp:
	@mkdir -p "$@"

# Compare configuration at Make evaluation; unchanged packages have no recipes.
CONFIGURE_OPTIONS_CODE = import json, os, pathlib, shutil; p = pathlib.Path("build.nosync/configure-options"); names = ["BUILD_TYPE", "CMAKE_CONFIGURE_FLAGS", "CMAKE_BUILD_FLAGS", "WASI_SDK_PATH", "CC", "CXX", "CFLAGS", "CXXFLAGS", "LDFLAGS"]; value = json.dumps({"environment": {n: os.environ.get(n) for n in names}, "tools": {n: shutil.which(n) for n in ["cmake", "rustc", "cargo", "wasm-tools", "wasm-opt", "wasmtime", "weval"]}}, sort_keys=True) + "\n"
CONFIGURE_OPTIONS_CHANGED := $(shell $(PYTHON) -c '$(CONFIGURE_OPTIONS_CODE); print("changed" if not p.exists() or p.read_text() != value else "")')
build.nosync/configure-options: $(if $(CONFIGURE_OPTIONS_CHANGED),FORCE) | build.nosync/tmp
	@$(PYTHON) -c '$(CONFIGURE_OPTIONS_CODE); p.write_text(value) if not p.exists() or p.read_text() != value else None'

$(CMAKE_CACHE): $(CMAKE_INPUTS) build.nosync/configure-options
	cmake --fresh -S . -B $(BUILD_DIR) -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) $(CMAKE_CONFIGURE_FLAGS)

$(NATIVE_ARTIFACT): $(CMAKE_CACHE) $(BUILD_INPUTS) Makefile
	cmake --build $(BUILD_DIR) --parallel $(NCPUS) --target plugin-js $(CMAKE_BUILD_FLAGS)
	@touch "$@"

$(ARTIFACT): $(NATIVE_ARTIFACT) $(NOTICE_INPUTS) scripts/notices.py
	$(PYTHON) scripts/notices.py "$<" "$@"

build.nosync/SHA256SUMS: $(ARTIFACT)
	cd build.nosync && shasum -a 256 plugin.js.wasm > SHA256SUMS

clean:
	$(PYTHON) scripts/clean.py

GAMS_VERSION := v3.1.1
GAMS_URL := https://github.com/kkgams/gams/releases/download/$(GAMS_VERSION)/GAMS-macos-aarch64.zip

tools/gams.app:
	@test "$$(uname -s):$$(uname -m)" = Darwin:arm64 || { echo 'Host download requires macOS Apple Silicon' >&2; exit 1; }
	@test ! -L tools && test ! -e tools/gams-release-notices && test ! -e tools/.gams-download-owned
	@mkdir -p tools build.nosync/tmp
	@set -eu; stage=$$(mktemp -d "build.nosync/tmp/gams-download.XXXXXX"); \
		trap 'rm -rf "$$stage"' EXIT; \
		$(CURL) --fail --location --retry 3 "$(GAMS_URL)" --output "$$stage/gams.zip"; \
		unzip -q "$$stage/gams.zip" -d "$$stage/unpacked"; \
		test -x "$$stage/unpacked/GAMS.app/Contents/MacOS/gams"; \
		mv "$$stage/unpacked/GAMS.app" "$@"; \
		mv "$$stage/unpacked" tools/gams-release-notices; \
		touch tools/.gams-download-owned

open: build tools/gams.app
	GAMS_APP_CWD="$(CURDIR)" GAMS_CONFIG=gams.json ./tools/gams.app/Contents/MacOS/gams

DOCS_PORT ?= 8080
WIKI_VERSION := v1.4.0
WIKI_REPOSITORY := https://github.com/justgook/wiki
WIKI_MAKEFILE := build.nosync/wiki-$(WIKI_VERSION).mk
WIKI_ENGINE := $(abspath build.nosync/wiki-$(WIKI_VERSION))

$(WIKI_MAKEFILE): | build.nosync/tmp
	@mkdir -p "$(@D)"
	@set -eu; trap 'rm -f "$@.tmp"' EXIT; \
		$(CURL) --fail --location --retry 3 "$(WIKI_REPOSITORY)/raw/$(WIKI_VERSION)/Makefile" -o "$@.tmp"; \
		mv "$@.tmp" "$@"

docs serve-docs validate-docs: $(WIKI_MAKEFILE)
	$(MAKE) -f "$(WIKI_MAKEFILE)" "$(if $(filter docs,$@),build,$(patsubst %-docs,%,$@))" WIKI_REPOSITORY="$(WIKI_REPOSITORY)" WIKI_VERSION="$(WIKI_VERSION)" WIKI_ENGINE="$(WIKI_ENGINE)" WIKI_SOURCE="$(abspath docs)" WIKI_OUTPUT="$(abspath build.nosync/site)" PORT="$(DOCS_PORT)"
