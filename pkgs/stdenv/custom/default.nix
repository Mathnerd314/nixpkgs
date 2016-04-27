{ system, allPackages, platform, crossSystem, config, ... } @ args:

rec {
  vanillaStdenv = import ../. (args // {
    # Remove config.replaceStdenv to ensure termination.
    config = builtins.removeAttrs config [ "replaceStdenv" ];
  });

  buildPackages = allPackages {
    # It's OK to change the built-time dependencies
    allowCustomOverrides = true;
    bootStdenv = vanillaStdenv;
    inherit system platform crossSystem config;
  };

  stdenvCustom = changer { pkgs = buildPackages; };
}
