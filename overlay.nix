final: prev: let
  inherit (builtins) readFile hashString split elemAt fetchurl toJSON;
  inherit (prev) linkFarm writeText stdenv;
  inherit (prev.lib) flatten mapAttrsToList importJSON;

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
in {
  mkDenoBundled = {lockfile, ...} @ args:
    stdenv.mkDerivation {
      inherit (args) name version src importmap entrypoint;
      buildInputs = with prev; [
        deno
        jq
      ];

      buildPhase = ''
        export DENO_DIR=`mktemp -d`
        ln -s "${mkDepsLink lockfile}" $(deno info --json | jq -r .modulesCache)

        deno bundle --import-map=$importmap $entrypoint ./mod.min.js
      '';
      installPhase = ''
        mkdir -p $out/dist
        install -t $out/dist ./mod.min.js
      '';
    };
  mkDenoCompiled = {pkgs}: {};
}
