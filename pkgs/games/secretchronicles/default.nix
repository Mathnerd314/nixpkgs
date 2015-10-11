{ stdenv, lib, fetchurl, ruby, gperf, pkgconfig, bison, glew, freeglut, gettext, libpng, SDL, SDL_ttf, SDL_mixer, SDL_image, pcre, libxmlxx, freetype, libdevil, boost, cmake, xlibs, glibmm }:
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

  meta = with lib; {
    description = "The Secret Chronicles of Dr. M, a two-dimensional sidecrolling platform game";
    license = licenses.gpl3;
    homepage = http://www.secretchronicles.de/en/;
    maintainers = [ maintainers.mathnerd314 ];
    platforms = platforms.linux;
  };
}
