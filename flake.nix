{
  description = "GAMS JavaScript plugin development environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay/5b87ee0513c29127a01ad06e9cb362ea5ce91e78";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, rust-overlay, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      sdkArtifacts = {
        aarch64-darwin = { name = "arm64-macos"; hash = "sha256:2c2ed99296857e60fd14c3f40fe226231f296409502491094704089c31a16740"; };
        x86_64-darwin = { name = "x86_64-macos"; hash = "sha256:1594a0791309781bf0d0224431c3556ec4a2326b205687b659f6550d08d8b13e"; };
        x86_64-linux = { name = "x86_64-linux"; hash = "sha256:0507679dff16814b74516cd969a9b16d2ced1347388024bc7966264648c78bfb"; };
        aarch64-linux = { name = "arm64-linux"; hash = "sha256:6f2977942308d91b0123978da3c6a0d6fce780994b3b020008c617e26764ea40"; };
      };
    in {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ rust-overlay.overlays.default ]; };
          sdk = sdkArtifacts.${system};
          tools = import ./nix/tools.nix { inherit pkgs system; };
          wasiSdk = pkgs.stdenv.mkDerivation {
            pname = "wasi-sdk";
            version = "30.0";
            src = pkgs.fetchurl {
              url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-30/wasi-sdk-30.0-${sdk.name}.tar.gz";
              hash = sdk.hash;
            };
            nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
            buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''mkdir -p "$out"; cp -R . "$out/"'';
            dontStrip = true;
          };
          rust = pkgs.rust-bin.stable."1.88.0".minimal.override { targets = [ "wasm32-wasip1" ]; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ cmake ninja gnumake clang llvm lld pkg-config git curl cacert python3 perl nodejs gnutar gzip xz unzip rust wkg ] ++ builtins.attrValues tools;
            WASI_SDK_PATH = "${wasiSdk}";
            shellHook = ''
              export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
              export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
              export PYTHONDONTWRITEBYTECODE=1
              export CARGO_HOME="$PWD/build.nosync/cargo"
              export CARGO_TARGET_DIR="$PWD/build.nosync/cargo-target"
              export CPM_SOURCE_CACHE="$PWD/build.nosync/cpm"
              export TMPDIR="$PWD/build.nosync/tmp"
              mkdir -p "$CARGO_HOME" "$TMPDIR"
            '';
          };
        });
    };
}
