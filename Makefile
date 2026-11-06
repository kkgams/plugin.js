.DEFAULT_GOAL := build

BUILD_TYPE ?= Release
BUILD_DIR ?= cmake-build-$(shell printf '%s' '$(BUILD_TYPE)' | tr '[:upper:]' '[:lower:]')
CMAKE_CONFIGURE_FLAGS ?=
CMAKE_BUILD_FLAGS ?=
NCPUS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

ARTIFACT := $(BUILD_DIR)/gams-js.wasm
CMAKE_CACHE := $(BUILD_DIR)/CMakeCache.txt

PROJECT_INPUTS := \
	CMakeLists.txt \
	componentize.sh.in \
	rust-toolchain.toml \
	version.txt \
	$(shell find builtins cmake crates host-apis include runtime scripts -type f 2>/dev/null)

.PHONY: build configure clean reconfigure

# Build the single GAMS JS plugin component.
build: $(ARTIFACT)

# Configure the CMake build directory.
configure: $(CMAKE_CACHE)

$(CMAKE_CACHE): CMakeLists.txt $(shell find cmake host-apis -name '*.cmake' -type f 2>/dev/null)
	cmake -S . -B $(BUILD_DIR) -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) $(CMAKE_CONFIGURE_FLAGS)

$(ARTIFACT): $(CMAKE_CACHE) $(PROJECT_INPUTS)
	cmake --build $(BUILD_DIR) --parallel $(NCPUS) --target gams-js $(CMAKE_BUILD_FLAGS)

# Force a fresh CMake configure step without deleting downloaded dependencies.
reconfigure:
	rm -f $(CMAKE_CACHE)
	$(MAKE) configure

# Remove generated build output.
clean:
	rm -rf $(BUILD_DIR)

PYTHON ?= python3
CURL ?= curl
GAMS_RELEASE_API ?= https://api.github.com/repos/kkgams/gams/releases/latest
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
DOCS_PORT ?= 8080
WIKI_VERSION := v1.4.0
WIKI_REPOSITORY := https://github.com/justgook/wiki
WIKI_MAKEFILE := build/wiki-$(WIKI_VERSION).mk
WIKI_ENGINE := $(abspath build/wiki-$(WIKI_VERSION))

.PHONY: open docs serve-docs validate-docs build-docs

# Retain an existing app; never update it implicitly.
tools/gams.app:
	@test "$(UNAME_S)" = Darwin && test "$(UNAME_M)" = arm64 || \
		{ echo 'GAMS release download requires macOS Apple Silicon' >&2; exit 1; }
	@test ! -e tools/gams-release-notices || \
		{ echo 'tools/gams-release-notices already exists; move it aside before reinstalling GAMS' >&2; exit 1; }
	@mkdir -p tools
	@set -eu; stage=$$(mktemp -d "tools/.gams-download.XXXXXX"); \
		trap 'rm -rf "$$stage"' EXIT; \
		$(CURL) --fail --location --silent --show-error "$(GAMS_RELEASE_API)" --output "$$stage/release.json"; \
		url=$$($(PYTHON) -c 'import json, sys; release = json.load(open(sys.argv[1])); assets = [a for a in release["assets"] if a["name"].startswith("GAMS-") and a["name"].endswith("-macos-aarch64.zip")]; assert len(assets) == 1, "Expected exactly one GAMS macOS Apple Silicon ZIP asset"; print(assets[0]["browser_download_url"])' "$$stage/release.json"); \
		$(CURL) --fail --location --silent --show-error "$$url" --output "$$stage/gams.zip"; \
		unzip -q "$$stage/gams.zip" -d "$$stage/unpacked"; \
		test -f "$$stage/unpacked/GAMS.app/Contents/Info.plist"; \
		test -x "$$stage/unpacked/GAMS.app/Contents/MacOS/gams"; \
		mv "$$stage/unpacked/GAMS.app" "$$stage/GAMS.app"; \
		mv "$$stage/unpacked" tools/gams-release-notices; \
		mv "$$stage/GAMS.app" "$@"

open: build tools/gams.app
	@mkdir -p build
	cp "$(ARTIFACT)" build/gams-js.wasm
	GAMS_APP_CWD="$(CURDIR)" ./tools/gams.app/Contents/MacOS/gams

$(WIKI_MAKEFILE):
	@mkdir -p "$(@D)"
	@set -eu; trap 'rm -f "$@.tmp"' EXIT; \
		$(CURL) --fail --location --retry 3 "$(WIKI_REPOSITORY)/raw/$(WIKI_VERSION)/Makefile" -o "$@.tmp"; \
		mv "$@.tmp" "$@"

docs: build-docs

serve-docs validate-docs build-docs: $(WIKI_MAKEFILE)
	$(MAKE) -f "$(WIKI_MAKEFILE)" "$(patsubst %-docs,%,$@)" WIKI_REPOSITORY="$(WIKI_REPOSITORY)" WIKI_VERSION="$(WIKI_VERSION)" WIKI_ENGINE="$(WIKI_ENGINE)" WIKI_SOURCE="$(abspath docs)" WIKI_OUTPUT="$(abspath build/site)" PORT="$(DOCS_PORT)"
