# gams-js plugin

Minimal SpiderMonkey-based JavaScript runner for the GAMS component-model runtime.

This repo builds one artifact:

```text
cmake-build-release/gams-js.wasm
```

The component exports `gams:js/js.run(source: string) -> result<string, string>` and imports only `gams:runtime/runtime@1.0.0`.

## Build

```sh
cmake -S . -B cmake-build-release -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build-release --parallel $(sysctl -n hw.ncpu) --target gams-js
```

Or use the Makefile wrapper:

```sh
make build
```

## Install from GHCR with `wkg`

Configure `wkg` to resolve the `gams` namespace from GHCR:

```toml
# ~/.config/wasm-pkg/config.toml

default_registry = "ghcr.io"

[namespace_registries]
gams = { registry = "gams-ghcr", metadata = { preferredProtocol = "oci", oci = { registry = "ghcr.io", namespacePrefix = "kkgams/" } } }
```

Then install the published component with the WIT package name:

```sh
wkg get gams:js@1.0.0 --output build.nosync/plugins/js.comp.wasm
```

This resolves to the canonical OCI package path `ghcr.io/kkgams/gams/js:1.0.0`.

The release workflow publishes only the canonical OCI package path, tagged as `1.0.0`, `latest`, and a UTC timestamp, for example:

```sh
wkg oci pull ghcr.io/kkgams/gams/js:<timestamp> -o build.nosync/plugins/js.comp.wasm
wkg oci pull ghcr.io/kkgams/gams/js:latest -o build.nosync/plugins/js.comp.wasm
```

## Local Project and documentation

```sh
nix develop --command make open
make serve-docs                 # http://localhost:8080; override DOCS_PORT
make validate-docs
make docs                       # portable site under build/site/
```

`make open` builds the component and opens this repository's `gams.json` with
explicit `GAMS_APP_CWD`. If absent, `tools/gams.app` is downloaded from the latest
GAMS macOS Apple Silicon release, with its accompanying notices retained.
An existing download is never updated implicitly; Gatekeeper is not bypassed.
No neighboring checkout is required. First launch needs network access for the
Project's pinned published dependencies.

The local Project loads the built plugin and the published Files View to browse
Project files. It is not a plugin-specific editor or an API/runtime test.
The wiki uses pinned `justgook/wiki` v1.4.0, cached under ignored `build/`.
GitHub Pages builds with `make docs` on every push to `release`, independently of
component releases. Set Pages source to **GitHub Actions** in repository settings.
