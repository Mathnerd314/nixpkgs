{ stdenv, fetchurl, ruby, gperf, pkgconfig, bison, glew, freeglut, gettext, libpng, SDL, SDL_ttf, SDL_mixer, SDL_image, pcre, libxmlxx, freetype, libdevil, boost, cmake, xlibs, glibmm }:
let
  version = "2.0.0";
in
stdenv.mkDerivation {
  name = "secretchronicles-${version}";

  src = fetchurl {
    url = "ftp://ftp.secretchronicles.de/releases/TSC-${version}.tar.xz";
    sha256 = "0yj03digri1j6r9l0b3cniiijm1w9j3agcpsb6m1dpprflwwmaf8";
  };

  buildInputs = [ ruby gperf pkgconfig bison glew freeglut gettext libpng SDL SDL_ttf SDL_mixer SDL_image pcre libxmlxx freetype libdevil boost cmake xlibs.libX11 glibmm ];
  


  configurePhase = ''
    cmake -DCMAKE_INSTALL_PREFIX=$out
  '';

  meta = {
    description = "The Secret Chronicles of Dr. M is a 2D jump n' run platformer.";
    license = stdenv.lib.licenses.gpl3;
    homepage = "http://secretchronicles.de/";
    maintainers = [ stdenv.lib.maintainers.mathnerd314 ];
    platforms = stdenv.lib.platforms.linux;
  };
}
