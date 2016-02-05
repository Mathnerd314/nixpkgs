{stdenv, lib, fetchurl, buildFHSUserEnv, xorg, freetype, fontconfig}:

let
  version = "3.4.3"; # newer versions seem corrupt
  antconc-pkg = stdenv.mkDerivation {
    name = "antconc-${version}"; 
    src = fetchurl {
      url = "http://www.laurenceanthony.net/software/antconc/releases/AntConc343/AntConc.tar.gz";
      sha256 = "1ry9qd0g9ig50xkn3wyrzxa288kqsl1j9slj2gndrfy9anz12niq";
    };
    installPhase = ''
      mkdir -p $out/bin $out/share/antconc
      cp AntConc $out/bin/AntConc
      cp antconc_icon.png $out/share/antconc
    '';

    dontPatchELF = true;
    dontStrip = true;

    meta = with lib; {
      description = "Corpus analysis toolkit for concordancing and text analysis.";
      homepage = http://www.laurenceanthony.net/software/antconc/;
      maintainers = [ maintainers.mathnerd314 ];
      platforms = [ "i686-linux" "x86_64-linux" ];
      license = licenses.unfreeRedistributable; # "Freeware", vague plans to release source code in 4.0
    };
  };
in
buildFHSUserEnv {
  name = "antconc";

  targetPkgs = pkgs: [
      antconc-pkg
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXrender
      xorg.libXext
      xorg.libXft
      freetype fontconfig
    ];

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/antconc.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=AntConc
    Exec=$out/bin/antconc
    Icon=${antconc-pkg}/share/applications/antconc_icon.png
    Terminal=false
    Categories=Education;Science;History;Literature;
    EOF
  '';
  runScript = "AntConc";
}
