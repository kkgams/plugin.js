# JavaScript plugin

A GAMS-specific JavaScript runtime built on SpiderMonkey, derived from
[StarlingMonkey](https://github.com/bytecodealliance/StarlingMonkey). Maintained
independently for [GAMS](https://github.com/kkgams/gams), not as a browser, Node.js
or general-purpose WASI JavaScript runtime.

| Unit | Source / output | Screenshot | License / original work |
| --- | --- | --- | --- |
| `gams:js/js@1.0.0` | `src/`, `wit/` → `build.nosync/plugin.js.wasm` | Not applicable | [Apache-2.0](LICENSE), [third-party terms and source availability](NOTICE); [StarlingMonkey](https://github.com/bytecodealliance/StarlingMonkey) / Bytecode Alliance and [SpiderMonkey](https://spidermonkey.dev/) / Mozilla contributors |

Exports `run(source: string) -> result<string, string>`; imports only
`gams:runtime/runtime@1.0.0`. No UI or standalone JavaScript application is shipped.
Original licenses and the modified MPL source travel inside the OCI component:
`python3 scripts/notices.py --extract plugin.js.wasm`.

## Execution contract

`run` evaluates a classic JavaScript script and returns its completion value
converted to a string, not JSON. Evaluation errors return the error string.
The engine is created lazily; successive calls on the same component instance
share globals and state. There is no per-call reset.

Promise microtasks run after successful evaluation, before the result is
converted to a string. A returned Promise is not awaited or unwrapped.

`host.call(target, ...args)` sends a JSON argument array to GAMS and parses the
JSON response. A single-field `ok` result is unwrapped; a single-field `err`
result throws. `host.rawCall(target, argsJson)` exchanges JSON strings without
unwrapping. Both calls are synchronous and expose the operations available to
the Host; this is not a sandbox for untrusted scripts.

Standard JavaScript globals are available, plus `host` and `log`. Browser APIs
such as fetch, URL, timers, WebCrypto and Web Streams are not installed. The
current shims provide deterministic random numbers and synthetic clock values,
not secure entropy or real elapsed time. The plugin does not implement a
per-call execution timeout or memory quota.

## Development

| Path | Contents |
| --- | --- |
| `src/` | C++ runtime, GAMS Host bridge/bindings, builtins and supporting Rust crates. |
| `wit/` | Component interface and GAMS runtime import. |
| `cmake/`, `scripts/`, `nix/` | Native build definitions, packaging tools and pinned tool provisioning. |
| `docs/`, `licenses/` | Wiki source and original third-party terms. |
| `build.nosync/` | Disposable build, package, docs and cache output. |

Run `direnv allow` once with your shell's direnv hook enabled; `.envrc` loads
the pinned Nix toolchain automatically. Alternatively, use `nix develop`.
The environment supplies CMake, Rust 1.88.0/WASIp1, WASI SDK 30 and native build
tools. The first build downloads pinned SpiderMonkey artifacts and CMake inputs.
Cargo.lock fixes the generated Rust static library's dependency resolution.

| Command | Purpose |
| --- | --- |
| `make build` | Compile and embed recipient notices in `build.nosync/plugin.js.wasm`. |
| `make package` | Build the component and `build.nosync/SHA256SUMS`; no publication. |
| `make open` | Build and open local `gams.json` in released GAMS v3.2.0 (macOS Apple Silicon). |
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
wkg oci pull ghcr.io/kkgams/gams/js:1.0.1 -o build.nosync/plugin.js.wasm
```

Select an explicitly published numeric version. New numeric `vX.Y.Z` tags map to
OCI `X.Y.Z`; existing versions are not replaced and new builds do not update
`latest`. WIT `@1.0.0` is the interface version, not the distribution version.
