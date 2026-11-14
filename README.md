# JavaScript plugin

A SpiderMonkey-based JavaScript runner for [GAMS](https://github.com/kkgams/gams).

| Unit | Source / output | License / original work |
| --- | --- | --- |
| `gams:js/js@1.0.0` | `runtime/`, `host-apis/my-minimal/` → `build.nosync/gams-js.wasm` | [Apache-2.0](LICENSE), [third-party terms and source availability](NOTICE); [StarlingMonkey](https://github.com/bytecodealliance/StarlingMonkey) / Bytecode Alliance and [SpiderMonkey](https://spidermonkey.dev/) / Mozilla contributors |

Exports `run(source: string) -> result<string, string>`; imports only
`gams:runtime/runtime@1.0.0`. No UI or standalone JavaScript application is shipped.
Original licenses and the modified MPL source travel inside the OCI component:
`python3 scripts/notices.py --extract gams-js.wasm`.

## Development

Use `nix develop` for pinned Rust 1.88.0/WASIp1, WASI SDK 30 and native build
tools. The first build downloads pinned SpiderMonkey artifacts and CMake inputs.
Cargo.lock fixes the generated Rust static library's dependency resolution.

| Command | Purpose |
| --- | --- |
| `make build` | Compile and embed recipient notices in `build.nosync/gams-js.wasm`. |
| `make package` | Build the component and `build.nosync/SHA256SUMS`; no publication. |
| `make open` | Build and open local `gams.json` in released GAMS v3.1.1 (macOS Apple Silicon). |
| `make serve-docs` | Serve the pinned wiki; `DOCS_PORT` defaults to 8080. |
| `make docs` | Build the wiki in `build.nosync/site/`. |
| `make validate-docs` | Validate wiki content. |
| `make clean` | Remove `build.nosync/` and this Makefile's marked Host download/notices; preserve supplied tools and legacy output. |

Set `NCPUS` to control compile parallelism (default 4). Build, download and cache
output, including TMPDIR, Cargo and CPM caches, stays in `build.nosync/`.
Changed compiler/options inputs force fresh CMake configuration. An existing
`tools/gams.app` is never updated implicitly; launch explicitly selects this
Project's `GAMS_APP_CWD` and `GAMS_CONFIG=gams.json`. The Files View in the local
Project browses files; it is not a JavaScript editor or runtime test.

## OCI installation

The distribution remains a single component at `ghcr.io/kkgams/gams/js`:

```sh
wkg oci pull ghcr.io/kkgams/gams/js:1.0.0 -o build.nosync/gams-js.wasm
```

Select an explicitly published numeric version. New numeric `vX.Y.Z` tags map to
OCI `X.Y.Z`; existing versions are not replaced and new builds do not update
`latest`. WIT `@1.0.0` is the interface version, not the distribution version.
