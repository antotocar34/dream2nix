{
  pkgs,
  config,
  lib,
  ...
}: let
  l = pkgs.lib // builtins;
  t = l.types;
  mkOption = l.options.mkOption;

  # Defining submodule type for precise typechecking.
  project = {
    name = mkOption {
      # TODO more specific?
      description = "name of the project";
      type = t.str;
    };

    # TODO Is this a path object or a string object
    relPath = mkOption {
      description = "relative path to project tree";
      type = t.path;
    };

    translators = mkOption {
      description = "translators to use";
      example = ["yarn-lock" "package-json"];
      type = t.listOf t.str;
    };

    subsystem = mkOption {
      description = ''name of subsystem to use. Examples: rust, python, nodejs'';
      type = t.str;
    };
  };
  sourceAttrs = {
    options = {
      url = mkOption {type = t.str;};
      flake = mkOption {
        type = t.bool;
        default = true;
      };
    };
  };
in {
  options.makeOutputArgs = {
    # source is the input in the flake,
    # so can be an attrset { url = str;  flake = bool; }
    # TODO can it be anything else? (can it be a local path?)
    source = mkOption {
      type = t.either t.path (t.submodule sourceAttrs);
      description = "the source of the package to build with dream2nix.";
    };

    projects = mkOption {
      type = t.listOf (t.submodule project);
      description = "projects that dream2nix will build";
    };

    discoveredProjects = mkOption {
      type = t.listOf (t.submodule project);
      description = "the projects found by the discoverer";
    };

    pname = mkOption {
      type = t.NullOr t.str;
      description = "Package Name";
    };

    settings = mkOption {
      type = t.listOf t.attrs;
      example = [
        # prefer aggregated source fetching (large FODs)
        {
          aggregate = true;
        }
        # for all impure nodejs projects with just a `package.json`,
        # add arguments for the `package-json` translator
        {
          filter = project: project.translator == "package-json";
          subsystemInfo.npmArgs = "--legacy-peer-deps";
          subsystemInfo.nodejs = 18;
        }
      ];
    };

    packageOverrides = mkOption {
      type = t.lazyAttrsOf t.attrs;
      description = "";
      example = {
        # name the override
        add-pre-build-steps = {
          # override attributes
          preBuild = "...";
          # update attributes
          buildInputs = old: old ++ [pkgs.hello];
        };
      };

      # name the override
      add-pre-build-steps = {
        # override attributes
        preBuild = "...";
        # update attributes
        buildInputs = old: old ++ [pkgs.hello];
      };
    };
  };

  sourceOverrides = mkOption {
    type = t.functionTo (t.lazyAttsOf (t.listOf t.package));
    example = oldSources: {
      bar."13.2.0" = builtins.fetchTarball {
        url = "";
        sha256 = "";
      };
      baz."1.0.0" = builtins.fetchTarball {
        url = "";
        sha256 = "";
      };
    };
  };

  inject = mkOption {
    type = t.lazyAttrsOf (t.listOf (t.listOf t.str));
    example = {
      # Make foo depend on bar and baz
      # from
      foo."6.4.1" = [
        # to
        ["bar" "13.2.0"]
        ["baz" "1.0.0"]
      ];
      # dependencies with @ and slash require quoting
      # the format is the one that is in the lockfile
      "@tiptap/extension-code"."2.0.0-beta.26" = [
        ["@tiptap/core" "2.0.0-beta.174"]
      ];
    };
  };
}
