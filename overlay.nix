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
    name,
    version,
    src,
    entrypoint,
    lockfile,
    importmap ? null,
  }:
    stdenv.mkDerivation {
      inherit name version entrypoint importmap;

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

        if [ -n "$importmap" ]; then
          deno bundle --import-map=$importmap $entrypoint bundled.js
        else
          deno bundle $entrypoint bundled.js
        fi
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

  mkDenoCompiled = {
    name,
    version,
    src,
    entrypoint,
    lockfile,
    importmap ? null,
  }:
    stdenv.mkDerivation {
      inherit name version entrypoint importmap lockfile;

      src = cleanSourceWith {
        inherit src;
        filter = path: type: (baseNameOf path != name);
      };
      buildInputs = with prev; [
        deno
        jq
      ];
      fixupPhase = ":";

      buildPhase = ''
        export DENO_DIR=`mktemp -d`
        ln -s "${mkDepsLink lockfile}" $(deno info --json | jq -r .modulesCache)

        if [ -n "$importmap" ]; then
          deno compile $denoFlags --import-map="$importmap" --lock="$lockfile" --cached-only --output="$name" "$entrypoint"
        else
          deno compile $denoFlags --lock="$lockfile" --output="$name" "$entrypoint"
        fi
      '';
      installPhase = ''
        mkdir -p $out/bin
        mv "$name" "$out/bin/"
      '';
    };
}
