{config, ...}: let
  l = config.lib // builtins;
  inherit (config) pkgs externalSources;
in {
  config = {
    externals = {
      devshell = {
        makeShell = import "${externalSources.devshell}/modules" pkgs;
        imports.c = "${externalSources.devshell}/extra/language/c.nix";
      };
      crane = let
        importLibFile = name: import "${externalSources.crane}/lib/${name}.nix";

        makeHook = attrs: name:
          pkgs.makeSetupHook
          ({inherit name;} // attrs)
          "${externalSources.crane}/pkgs/${name}.sh";
        genHooks = names: attrs: l.genAttrs names (makeHook attrs);
      in
        {
          cargoHostTarget,
          cargoBuildBuild,
        }: rec {
          otherHooks =
            genHooks [
              "cargoHelperFunctions"
              "configureCargoCommonVarsHook"
              "configureCargoVendoredDepsHook"
            ]
            {};
          installHooks =
            genHooks [
              "inheritCargoArtifactsHook"
              "installCargoArtifactsHook"
            ]
            {
              substitutions = {
                zstd = "${pkgs.pkgsBuildBuild.zstd}/bin/zstd";
              };
            };
          installLogHook = genHooks ["installFromCargoBuildLogHook"] {
            substitutions = {
              cargo = "${cargoBuildBuild}/bin/cargo";
              jq = "${pkgs.pkgsBuildBuild.jq}/bin/jq";
            };
          };

          # These aren't used by dream2nix
          crateNameFromCargoToml = null;
          vendorCargoDeps = null;

          writeTOML = importLibFile "writeTOML" {
            inherit (pkgs) runCommand pkgsBuildBuild;
          };
          cleanCargoToml = importLibFile "cleanCargoToml" {};
          findCargoFiles = importLibFile "findCargoFiles" {
            inherit (pkgs) lib;
          };
          mkDummySrc = importLibFile "mkDummySrc" {
            inherit (pkgs) writeText runCommandLocal lib;
            inherit writeTOML cleanCargoToml findCargoFiles;
          };

          mkCargoDerivation = importLibFile "mkCargoDerivation" {
            cargo = cargoHostTarget;
            inherit (pkgs) stdenv lib;
            inherit
              (installHooks)
              inheritCargoArtifactsHook
              installCargoArtifactsHook
              ;
            inherit
              (otherHooks)
              configureCargoCommonVarsHook
              configureCargoVendoredDepsHook
              ;
            cargoHelperFunctionsHook = otherHooks.cargoHelperFunctions;
          };
          buildDepsOnly = importLibFile "buildDepsOnly" {
            inherit
              mkCargoDerivation
              crateNameFromCargoToml
              vendorCargoDeps
              mkDummySrc
              ;
          };
          cargoBuild = importLibFile "cargoBuild" {
            inherit
              mkCargoDerivation
              buildDepsOnly
              crateNameFromCargoToml
              vendorCargoDeps
              ;
          };
          buildPackage = importLibFile "buildPackage" {
            inherit (pkgs) removeReferencesTo lib;
            inherit (installLogHook) installFromCargoBuildLogHook;
            inherit cargoBuild;
          };
        };
    };
  };
}
