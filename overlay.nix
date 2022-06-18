final: prev: let
  inherit (builtins) readFile hashString split elemAt fetchurl toJSON baseNameOf;
  inherit (prev) linkFarm writeText stdenv writeShellScriptBin;
  inherit (prev.lib) flatten mapAttrsToList importJSON cleanSourceWith;

  urlPart = url: elemAt (flatten (split "://([a-z0-9\.]*)" url));
  artifactPath = url: "${urlPart url 0}/${urlPart url 1}/${hashString "sha256" (urlPart url 2)}";

  mkDepsLink = lockfile:
    linkFarm "deps" (flatten (
      mapAttrsToList
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
      (importJSON lockfile)
    ));
in rec {
  mkDenoBundled = {
    lockfile,
    src,
    ...
  } @ args:
    stdenv.mkDerivation {
      inherit (args) name version importmap entrypoint;

      src = cleanSourceWith {
        inherit src;
        filter = path: type: (baseNameOf path != "bundled.js");
      };
      buildInputs = with prev; [
        deno
        jq
      ];

      buildPhase = ''
        export DENO_DIR=`mktemp -d`
        ln -s "${mkDepsLink lockfile}" $(deno info --json | jq -r .modulesCache)

        deno bundle --import-map=$importmap $entrypoint bundled.js
      '';
      installPhase = ''
        mkdir -p $out/dist
        install -t $out/dist bundled.js
      '';
    };
  mkDenoBundledWrapper = {
    name,
    entrypoint,
    ...
  } @ args: let
    bundled = mkDenoBundled args;
  in
    writeShellScriptBin
    "${name}"
    "${prev.deno}/bin/deno run ${bundled}/dist/bundled.js";

  mkDenoCompiled = {pkgs}: {};
}
