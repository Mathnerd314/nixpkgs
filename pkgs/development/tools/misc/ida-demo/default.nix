{ stdenv, fetchurl, lib, makeDesktopItemScript, makeWrapper, file
, glib, xorg, fontconfig, freetype, dbus, xkeyboard_config
}:

stdenv.mkDerivation rec {
  name = "ida-demo-6.9";

  src =
    if stdenv.system == "i686-linux" then
      fetchurl {
	url = https://out7.hex-rays.com/files/idademo69_linux.tgz;
	sha256 = "0bxd5qijxqcj3ck5q43kd6jv03f6nf9f4wkim368wx3la5y5v1vj";
      }
    else
      abort "IDA Pro Demo is not packaged for ${stdenv.system}";

  rpath = stdenv.lib.makeSearchPath "lib" [
      stdenv.cc.cc
      glib
      xorg.libX11
      xorg.libXext
      xorg.libXi
      xorg.libSM
      xorg.libICE
      xorg.libXcursor
      fontconfig
      freetype
      dbus
  ];

  buildInputs = [ makeWrapper ];

  installPhase = ''
    # Copy prebuilt app to $out
    mkdir "$out"
    cp -r * "$out"

    # Allow using keyboard
    makeWrapper $out/idaq $out/bin/idaq \
      --set QT_XKB_CONFIG_ROOT ${xkeyboard_config}/share/X11/xkb

    # Install a .desktop file
    ${makeDesktopItemScript {
      name="ida-demo";
      exec="$out/bin/idaq";
      desktopName="IDA Demo";
      genericName="Interactive disassembler";
      categories="Development;Debugger;Profiling;";
    }}
  '';

  postFixup = ''
    # Patch binaries
    find $out -type f -executable -execdir sh -c \
      '${file}/bin/file -i "$@" | grep -q "application/x-executable; charset=binary" \
      && patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$@" \
      && patchelf --set-rpath "$rpath:\$ORIGIN" "$@" \
      && echo patched "$@"
      ' sh '{}' \;

    # Patch libraries
    find $out -type f -executable -execdir sh -c \
      '${file}/bin/file -i "$@" | grep -q "application/x-sharedlib; charset=binary" \
      && patchelf --set-rpath "$rpath:\$ORIGIN:$out" "$@" \
      && echo patched "$@"
      ' sh '{}' \;
  '';

  meta = with lib; {
    description = "Interactive multi-processor disassembler, debugger, and programming environment (demo version)";
    homepage    = https://www.hex-rays.com/products/ida/index.shtml;
    license     = licenses.unfree;
    platforms   = platforms.linux;
    maintainers = with maintainers; [ Mathnerd314 ];
  };
}
