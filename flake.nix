{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    devshell,
    ...
  } @ inputs:
    flake-utils.lib.eachSystem
    [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ]
    (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlay
          ];
        };
      in rec {
        packages.default = pkgs.stdenv.mkDerivation rec {
          pname = "example";
          version = "0.1.0";
          src = self;

          buildInputs = [pkgs.deno];

          buildPhase = ''
            export DENO_DIR=$TMP
            # deno cache --reload --lock=./lock.json $sourceRoot/mod.ts
            deno task compile:${system}
          '';
          installPhase = ''
            mkdir -p $out/bin
            install -t $out/bin dist/out
          '';
        };
        defaultPackage = packages.default;

        devShell = pkgs.devshell.mkShell {
          imports = [
            (pkgs.devshell.importTOML ./devshell.toml)
          ];
        };
      }
    );
}
