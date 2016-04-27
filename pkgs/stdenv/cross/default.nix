{ allPackages, crossSystem, config, ... } @ args:

rec {
  vanillaStdenv = import ../. (args // {
    crossSystem = null;
    # No custom stdenvs when cross-compiling.
    # Not sure this is necessary, but this is how it worked before.
    config = builtins.removeAttrs config [ "replaceStdenv" ];
  }) // {
    cross = crossSystem;
  };

  buildPackages = allPackages {
    # Partially applied `allPackages` has `crossSystem = null` by default
    inherit crossSystem;
    # It's OK to change the built-time dependencies
    allowCustomOverrides = true;
    stdenv = vanillaStdenv;
  };

  stdenvCross = with buildPackages;
    makeStdenvCross stdenv crossSystem binutilsCross gccCrossStageFinal;
}
