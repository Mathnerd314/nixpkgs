/* This file composes a the Nix Packages collection. It:

     1. Infers an appropriate `platform` based on the `system` if none is
        provided

     2. Infers an appropriate `stdenv` based on the `system` if none is
        provided

     3. Defaults to no non-standard config and no cross-compilation target

     3. Builds the final phase --- a fully booted package set with the chosen
        `stdenv`

   Use `impure.nix` to also infer the `system` based on the one on which
   evaluation is taking place, and the configuration from environment variables
   or dot-files. */

{ # The system (e.g., `i686-linux') for which to build the packages.
  system

, # The configuration attribute set
  config ? {}

, crossSystem ? null
, platform ? null
} @ args:

let
  platform_ = platform;

in let
  lib = import ../lib;

  # Allow setting the platform in the config file. Otherwise, let's use a reasonable default (pc)

  platformAuto = let
      platforms = (import ./top-level/platforms.nix);
    in
      if system == "armv6l-linux" then platforms.raspberrypi
      else if system == "armv7l-linux" then platforms.armv7l-hf-multiplatform
      else if system == "armv5tel-linux" then platforms.sheevaplug
      else if system == "mips64el-linux" then platforms.fuloong2f_n32
      else if system == "x86_64-linux" then platforms.pc64
      else if system == "i686-linux" then platforms.pc32
      else platforms.pcBase;

  platform = if platform_ != null then platform_
    else config.platform or platformAuto;

  # A few packages make make a new package set to draw their dependencies from.
  # (Currently to get a cross tool chain, or forced-i686 package.) Rather than
  # give `all-packages.nix` all the arguments to this function, even ones that
  # don't concern it, we give it this function to "re-call" nixpkgs, inheriting
  # whatever arguments it doesn't explicitly provide. This way, `all-packages.nix`
  # doesn't know more than it needs too.
  #
  # It's OK that `args` doesn't include the defaults: they'll be
  # deterministically inferred the same way.
  mkPackages = newArgs: import ./. (args // newArgs);

  # Partially apply some args for building phase pkgs sets
  allPackages = args: import ./top-level ({
    inherit lib mkPackages;
  } // args);

  stdenv = import ./stdenv {
    inherit system allPackages platform config crossSystem lib;
  };

in allPackages { inherit system stdenv config crossSystem platform; }
