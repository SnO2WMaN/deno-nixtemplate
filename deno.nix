{pkgs ? import <nixpkgs> {}}: let
  inherit (pkgs) lib;
  inherit (builtins) readFile hashString split elemAt fetchurl toJSON;
  inherit (pkgs) writeText linkFarm;
  inherit (lib.lists) flatten;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.trivial) importJSON;

  urlPart = url: elemAt (flatten (split "://([a-z0-9\.]*)" url));
  artifactPath = url: "${urlPart url 0}/${urlPart url 1}/${hashString "sha256" (urlPart url 2)}";
in
  # mapAttrsToList (url: sha256: []) (importJSON ./lock.json)
  {
    inherit urlPart artifactPath;
    deps = linkFarm "deps" (flatten (mapAttrsToList
      (
        url: sha256: [
          {
            name = artifactPath url;
            path = fetchurl {inherit url sha256;};
          }
          {
            name = (artifactPath url) + ".metadata.json";
            path = writeText "metadata.json" (toJSON {
              inherit url;
              headers = {};
            });
          }
        ]
      )
      (importJSON ./lock.json)));
  }
