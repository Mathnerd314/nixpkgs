{ fetchurl, stdenv, guile, libgcrypt, sqlite, bzip2, pkgconfig, gettext, autoconf, automake, lib }:

let
  # Getting the bootstrap Guile binary.  This is normally performed by Guix's build system.
  base_url = arch:
    "http://alpha.gnu.org/gnu/guix/bootstrap/${arch}-linux/20131110/guile-2.0.9.tar.xz";
  boot_guile = {
    i686 = fetchurl {
      url = base_url "i686";
      sha256 = "0im800m30abgh7msh331pcbjvb4n02smz5cfzf1srv0kpx3csmxp";
    };
    x86_64 = fetchurl {
      url = base_url "x86_64";
      sha256 = "1w2p5zyrglzzniqgvyn1b55vprfzhgk8vzbzkkbdgl5248si0yq3";
    };
  };
in stdenv.mkDerivation rec {
  name = "guix-0.8.3";

  src = fetchurl {
    url = "http://alpha.gnu.org/gnu/guix/${name}.tar.gz";
    sha256 = "14n0nkj0ckhdwhghx1pml99hbjr1xdkn8x145j0xp1357vqlisnz";
  };

  configureFlags =
     [ "--with-libgcrypt-prefix=${libgcrypt}"
     ];

  preBuild =
    # Copy the bootstrap Guile tarballs like Guix's makefile normally does.
    '' cp -v "${boot_guile.i686}" gnu/packages/bootstrap/i686-linux/guile-2.0.9.tar.xz
       cp -v "${boot_guile.x86_64}" gnu/packages/bootstrap/x86_64-linux/guile-2.0.9.tar.xz
    '';

  buildInputs = [ autoconf automake pkgconfig guile libgcrypt sqlite bzip2 gettext ];

  doCheck = true;
  enableParallelBuilding = true;

  meta = with lib; {
    description = "Functional package manager with a Scheme interface";

    longDescription = ''
      GNU Guix is a purely functional package manager for the GNU system, and a distribution thereof.

      In addition to standard package management features, Guix supports
      transactional upgrades and roll-backs, unprivileged package management,
      per-user profiles, and garbage collection.

      It provides Guile Scheme APIs, including high-level embedded
      domain-specific languages (EDSLs), to describe how packages are built
      and composed.

      A user-land free software distribution for GNU/Linux comes as part of
      Guix.

      Guix is based on the Nix package manager.
    '';

    license = licenses.gpl3Plus;

    maintainers = with maintainers; [ mathnerd314 ];
    platforms = platforms.linux;

    homepage = http://www.gnu.org/software/guix;
  };
}
