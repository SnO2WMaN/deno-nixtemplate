{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    deno2nix.url = "github:SnO2WMaN/deno2nix";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
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
          overlays = with inputs; [
            devshell.overlay
            deno2nix.overlays.default
          ];
        };
      in {
        packages.default = pkgs.deno2nix.mkExecutable {
          pname = "example";
          version = "0.1.0";

          src = ./.;
          lockfile = ./lock.json;

          output = "example";
          entrypoint = "./mod.ts";
          importMap = "./import_map.json";
        };
        defaultPackage = self.packages.${system}.default;

        apps.default = flake-utils.lib.mkApp {
          name = "example";
          drv = self.packages.${system}.default;
        };

        checks = self.packages.${system};

        devShells.default = pkgs.devshell.mkShell {
          packages = with pkgs; [
            alejandra
            deno
            treefmt
            taplo-cli
          ];
          commands = [
            {
              package = "treefmt";
              category = "formatters";
            }
          ];
        };
      }
    );
}
