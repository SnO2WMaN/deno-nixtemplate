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
      "x86_64-linux"
    ]
    (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlay
            (import ./overlay.nix)
          ];
        };
      in rec {
        # packages.default = pkgs.stdenv.mkDerivation (
        #   let
        #     deps = ((import ./deno.nix) {inherit pkgs;}).deps;
        #   in rec {
        #     pname = "example";
        #     version = "0.1.0";
        #     src = pkgs.lib.cleanSourceWith {
        #       src = self;
        #       filter = path: type: (
        #         (baseNameOf path != ".direnv")
        #         && (baseNameOf path != ".vscode")
        #         && (baseNameOf path != "dist")
        #       );
        #     };
        #
        #     buildInputs = with pkgs; [
        #       deno
        #       jq
        #     ];
        #
        #     buildPhase = ''
        #       export DENO_DIR=`mktemp -d`
        #       ln -s "${deps}" $(deno info --json | jq -r .modulesCache)
        #       # deno task compile
        #       deno compile --import-map=./import_map.json --output=dist/out ./mod.ts
        #     '';
        #     installPhase = ''
        #       mkdir -p $out/bin
        #       install -t $out/bin dist/out
        #     '';
        #   }
        # );
        packages.bundled = pkgs.mkDenoBundled {
          name = "example-bundle";
          version = "0.1.0";
          src = self;
          lockfile = ./lock.json;
          importmap = ./import_map.json;
          entrypoint = ./mod.ts;
        };
        packages.bundled-wrapper =
          pkgs.writeShellScriptBin "wrapper"
          "${pkgs.deno}/bin/deno run ${packages.bundled}/dist/mod.min.js";
        packages.default = packages.bundled-wrapper;

        defaultPackage = packages.default;

        apps.default = {
          type = "app";
          program = "${packages.bundled-wrapper}/bin/wrapper";
        };

        devShell = pkgs.devshell.mkShell {
          imports = [
            (pkgs.devshell.importTOML ./devshell.toml)
          ];
        };
      }
    );
}
