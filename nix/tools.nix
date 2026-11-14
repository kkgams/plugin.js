{ pkgs, system }:
let
  artifacts = {
    aarch64-darwin = {
      wasm-tools = { url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v1.235.0/wasm-tools-1.235.0-aarch64-macos.tar.gz"; hash = "sha256:17035deade9d351df6183d87ad9283ce4ae7d3e8e93724ae70126c87188e96b2"; };
      binaryen = { url = "https://github.com/WebAssembly/binaryen/releases/download/version_123/binaryen-version_123-arm64-macos.tar.gz"; hash = "sha256:74428be348c1a09863e7b642a1fa948cabf8ec9561052233d8288e941951725b"; };
      wasmtime = { url = "https://github.com/bytecodealliance/wasmtime/releases/download/v42.0.1/wasmtime-v42.0.1-aarch64-macos.tar.xz"; hash = "sha256:69c56932453483f31cac7636f850bbd3bf884eaa7315b2c3b92857a2b0c6762e"; };
      weval = { url = "https://github.com/bytecodealliance/weval/releases/download/v0.4.1/weval-v0.4.1-aarch64-macos.tar.xz"; hash = "sha256:acc74d6f02e0e28513f80f803b115e9ec042c2221a90b27201839ec37806e03e"; };
    };
    x86_64-darwin = {
      wasm-tools = { url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v1.235.0/wasm-tools-1.235.0-x86_64-macos.tar.gz"; hash = "sha256:154e9ea5f5477aa57466cfb10e44bc62ef537e32bf13d1c35ceb4fedd9921510"; };
      binaryen = { url = "https://github.com/WebAssembly/binaryen/releases/download/version_123/binaryen-version_123-x86_64-macos.tar.gz"; hash = "sha256:cc18b14d2b673d9c66bf54f31ff2b0ceb23ba5132455b893965ae2792f9e00dd"; };
      wasmtime = { url = "https://github.com/bytecodealliance/wasmtime/releases/download/v42.0.1/wasmtime-v42.0.1-x86_64-macos.tar.xz"; hash = "sha256:13465d6c3f35b2872f9168df19b74af6140b4f1a3a11d8a397950777ecfae858"; };
      weval = { url = "https://github.com/bytecodealliance/weval/releases/download/v0.4.1/weval-v0.4.1-x86_64-macos.tar.xz"; hash = "sha256:0dc53da50e18a61097a1806ba1fa5fb6acf194da4d127e0f7d6e236defb470fd"; };
    };
    aarch64-linux = {
      wasm-tools = { url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v1.235.0/wasm-tools-1.235.0-aarch64-linux.tar.gz"; hash = "sha256:384ca3691502116fb6f48951ad42bd0f01f9bf799111014913ce15f4f4dde5a2"; };
      binaryen = { url = "https://github.com/WebAssembly/binaryen/releases/download/version_123/binaryen-version_123-aarch64-linux.tar.gz"; hash = "sha256:4b6bd61ba6cd3b18c993b4657d93426c782f9b91b74be0d38018cd8be1319376"; };
      wasmtime = { url = "https://github.com/bytecodealliance/wasmtime/releases/download/v42.0.1/wasmtime-v42.0.1-aarch64-linux.tar.xz"; hash = "sha256:fa9b7e09f49f75c17acf2c018a4286cdbeffb4c1f3ee9e72c48b6a42c1deceda"; };
      weval = { url = "https://github.com/bytecodealliance/weval/releases/download/v0.4.1/weval-v0.4.1-aarch64-linux.tar.xz"; hash = "sha256:df0a910ba1de595f0900f552f8a9d5008a9234dc6a87bf727331e09908126fa0"; };
    };
    x86_64-linux = {
      wasm-tools = { url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v1.235.0/wasm-tools-1.235.0-x86_64-linux.tar.gz"; hash = "sha256:4c44bc776aadbbce4eedc90c6a07c966a54b375f8f36a26fd178cea9b419f584"; };
      binaryen = { url = "https://github.com/WebAssembly/binaryen/releases/download/version_123/binaryen-version_123-x86_64-linux.tar.gz"; hash = "sha256:e959f2170af4c20c552e9de3a0253704d6a9d2766e8fdb88e4d6ac4bae9388fe"; };
      wasmtime = { url = "https://github.com/bytecodealliance/wasmtime/releases/download/v42.0.1/wasmtime-v42.0.1-x86_64-linux.tar.xz"; hash = "sha256:dd5253f3cb521bb094f9951c3d2c45c746b31e5723b07ce56f162ec9bab44d59"; };
      weval = { url = "https://github.com/bytecodealliance/weval/releases/download/v0.4.1/weval-v0.4.1-x86_64-linux.tar.xz"; hash = "sha256:4406312b3bee1d89e1c78c83dd3781a41fc6d04c248dc02f4d3e3ba731881022"; };
    };
  };
  unpack = name: artifact: pkgs.stdenv.mkDerivation {
    pname = name;
    version = "pinned";
    src = pkgs.fetchurl artifact;
    nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
    buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out"
      cp -R . "$out/"
      if ! test -d "$out/bin"; then
        mkdir -p "$out/bin"
        find "$out" -maxdepth 1 -type f -perm -0100 -exec mv {} "$out/bin/" \;
      fi
    '';
    dontStrip = true;
  };
in pkgs.lib.mapAttrs unpack artifacts.${system}
