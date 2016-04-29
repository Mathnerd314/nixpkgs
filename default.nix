let requiredVersion = import ./lib/minver.nix; in

if ! builtins ? nixVersion || builtins.compareVersions requiredVersion builtins.nixVersion == 1 then

  abort "This version of Nixpkgs requires Nix >= ${requiredVersion}, please upgrade! See https://nixos.org/wiki/How_to_update_when_Nix_is_too_old_to_evaluate_Nixpkgs"

else
  /* Impure default arguments for `pkgs/top-level/default.nix`. See that file
    for the meaning of each argument. */
  args @ { system ? builtins.currentSystem
         , config ?
            # The contents of the configuration file found at $NIXPKGS_CONFIG or
            # $HOME/.nixpkgs/config.nix.
            # for NIXOS (nixos-rebuild): use nixpkgs.config option to set
            let
              toPath = builtins.toPath;
              getEnv = x: if builtins ? getEnv then builtins.getEnv x else "";
              pathExists = name:
                builtins ? pathExists && builtins.pathExists (toPath name);

              configFile = getEnv "NIXPKGS_CONFIG";
              homeDir = getEnv "HOME";
              configFile2 = homeDir + "/.nixpkgs/config.nix";
            in
              if configFile != "" && pathExists configFile then import (toPath configFile)
              else if homeDir != "" && pathExists configFile2 then import (toPath configFile2)
              else {}
          , ... }:
    let configExpr = config; in # rename the function arguments
    let
      # allow both:
      # { /* the config */ } and
      # { pkgs, ... } : { /* the config */ }
      config =
          if builtins.isFunction configExpr
            then configExpr { inherit pkgs; }
            else configExpr;

      pkgs = import ./pkgs/top-level (args // { inherit system config; });

    in pkgs
