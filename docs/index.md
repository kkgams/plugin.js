---
title: JavaScript plugin
description: Build and use the GAMS JavaScript component.
status: reference
---

# JavaScript plugin

A GAMS-specific JavaScript runtime built on SpiderMonkey. Maintained
independently for [GAMS](https://github.com/kkgams/gams), not as a browser, Node.js
or general-purpose WASI JavaScript runtime.

| Unit | Source / output |
| --- | --- |
| `gams:js/js@1.0.0` | `src/`, `wit/` → `build.nosync/plugin.js.wasm` |

Exports `run(source: string) -> result<string, string>`; imports only
`gams:runtime/runtime@1.0.0`. No UI or standalone JavaScript application is shipped.

## Execution

`run` evaluates a classic JavaScript script and returns its completion value
converted to a string, not JSON. Evaluation errors return the error string.
Calls on the same component instance share globals and state, with no per-call
reset. Promise microtasks run after successful evaluation; returned Promises
are not awaited or unwrapped.

Use `host.call(target, ...args)` for synchronous JSON calls to GAMS. It unwraps
single-field `ok` results and throws on single-field `err` results.
`host.rawCall(target, argsJson)` exchanges JSON strings without unwrapping.
Available Host operations determine what scripts can access; do not run
untrusted scripts.

Standard JavaScript globals, `host` and `log` are available. Browser APIs such
as fetch, URL, timers, WebCrypto and Web Streams are not installed. Random
numbers are deterministic, clocks are synthetic, and the plugin implements no
per-call timeout or memory quota.

## Development

| Path | Contents |
| --- | --- |
| `src/` | Runtime, GAMS Host bridge/bindings, builtins and Rust support. |
| `wit/` | Component interface and GAMS runtime import. |
| `cmake/`, `scripts/`, `nix/` | Build definitions, packaging and tool provisioning. |
| `build.nosync/` | Disposable build, package, docs and cache output. |

Use `nix develop` for pinned Rust 1.88.0/WASIp1, WASI SDK 30 and native build
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
