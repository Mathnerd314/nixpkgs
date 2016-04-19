{stdenv}:
rec {
  # Use like so in installPhase or postInstall:
  #
  # postInstall =
  #   ''
  #     ...
  #     ${makeDesktopItemScript {
  #        name = "firefox";
  #        exec = "firefox %U";
  #        desktopName = "Mozilla Firefox";
  #        genericName = "Web Browser";
  #     }}
  #     ...
  #   ''
  #
  # Generated desktop files can be validated with desktop-file-validate from desktop_file_utils
  makeDesktopItemScript =
    { name
    , type ? "Application"
    , exec
    , icon ? ""
    , comment ? ""
    , terminal ? "false"
    , desktopName
    , genericName
    , mimeType ? ""
    , categories ? "Application;Other;"
    , startupNotify ? null
    , extraEntries ? ""
    }:
      ''
        mkdir -p $out/share/applications
        cat > $out/share/applications/${name}.desktop <<EOF
        [Desktop Entry]
        Type=${type}
        Exec=${exec}
        Icon=${icon}
        Comment=${comment}
        Terminal=${terminal}
        Name=${desktopName}
        GenericName=${genericName}
        MimeType=${mimeType}
        Categories=${categories}
        ${extraEntries}
        ${if startupNotify == null then ''EOF'' else ''
        StartupNotify=${startupNotify}
        EOF''}
      '';

  # Derivation version, for standalone desktop files and backwards compatibility
  makeDesktopItem = args @ { name, ... }: stdenv.mkDerivation {
    name = "${name}.desktop";
    buildCommand = makeDesktopItemScript args;
  };
}
