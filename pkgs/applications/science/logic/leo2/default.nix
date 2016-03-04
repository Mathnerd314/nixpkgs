{stdenv, fetchurl, lib, perl, ocamlPackages, eprover, zlib}:
let 
  version = "1.7.0";
in
stdenv.mkDerivation {
  src = fetchurl {
    url = "http://page.mi.fu-berlin.de/cbenzmueller/leo/leo2_v${version}.tgz";
    sha256 = "1b2q7vsz6s9ighypsigqjm1mzjiq3xgnz5id5ssb4rh9zm190r82";
  };

  name = "leo2-${version}";
  buildInputs = with ocamlPackages; [perl ocaml findlib camlp4 eprover zlib];
  postUnpack = "sourceRoot=\${sourceRoot}/src";
  preConfigure = ''
    patchShebangs .
  '';
  postInstall = ''
    mkdir -p "$out/bin"
    echo -e "#! /bin/sh\\n$PWD/../bin/leo --atprc $out/etc/leoatprc \"\$@\"\\n" > "$out/bin/leo"
    chmod a+x "$out/bin/leo"
    mkdir -p "$out/etc"
    echo -e "e = ${eprover}/bin/eprover\\nepclextract = ${eprover}/bin/epclextract" > "$out/etc/leoatprc"
  '';

  meta = {
    description = "A high-performance typed higher order prover";
    maintainers = with lib.maintainers; [ raskin ];
    platforms = lib.platforms.linux;
    license = lib.licenses.bsd3;
    homepage = "http://page.mi.fu-berlin.de/cbenzmueller/leo/";
    downloadPage = "http://page.mi.fu-berlin.de/cbenzmueller/leo/download.html";
  };
}
