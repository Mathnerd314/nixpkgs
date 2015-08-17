{ stdenv, fetchFromGitLab, kernel }:

stdenv.mkDerivation {
  name = "ddci-driver-0.1-${kernel.version}";

  src = fetchFromGitLab {
    sha256 = "02qgwxzcbanq0y6px84sp2mzd6wx9rzvq6fk6zp9g0ffl13glprj";
    rev = "39127aabce3d54deb6fb59c8193b6c0fff35420d";
    repo = "ddcci-driver-linux";
    owner = "ddcci-driver-linux";
  };

  prePatch = ''
    sed -e 's@/lib/modules/\$(.*)\(.*\)@${kernel.dev}/lib/modules/${kernel.modDirVersion}\1@' -e 's@depmod@true@' -i */Makefile
    unset src
  '';

  installPhase = ''
    make install KERNEL_MODLIB=$out/lib/modules/${kernel.modDirVersion} INCLUDEDIR=$out/include
  '';

  meta = with stdenv.lib; {
    homepage = https://gitlab.com/ddcci-driver-linux/ddcci-driver-linux;
    description = "Linux kernel drivers for DDC/CI monitors";
    platforms = platforms.linux;
    maintainers = with maintainers; [ mathnerd314 ];
  };
}
