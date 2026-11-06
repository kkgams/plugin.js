---
title: plugin.js
description: Local development and Project launch.
status: reference
---

# plugin.js

Builds a SpiderMonkey-based JavaScript runner for the GAMS component
runtime. The component exports
`gams:js/js.run(source: string) -> result<string, string>` and imports
`gams:runtime/runtime@1.0.0`.

Build with `make build` or `nix develop --command make build`. The component is
`cmake-build-release/gams-js.wasm`; `make open` copies the selected build's
artifact to `build/gams-js.wasm` for the local Project. The Files View browses
Project files; it does not execute JavaScript or provide a script editor.

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

The component API and release safeguards remain documented in the repository README.
