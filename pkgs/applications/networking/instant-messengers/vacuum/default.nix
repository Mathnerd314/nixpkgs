{stdenv, fetchurl, lib, cmake, qt4, openssl, xproto, libX11, libXScrnSaver, scrnsaverproto, xz}:
let
  version="1.2.5";
  baseName="vacuum-im";
  name="${baseName}-${version}";
  url="https://googledrive.com/host/0B_VbYEyCFxENfl9mdF9UbkZXOUswUERiNlZ2U2VDdV9SSG83WXRCOTFOcE1rb3hCTDJyYms/vacuum-im-1.2.5.tar.gz";
  sha256="1np5zycrbh106yi0bhfqx6mafh1v12bzrl1a8arvakw8d0zr6drj";
in
stdenv.mkDerivation {
  src = fetchurl {
    inherit url sha256;
  };

  inherit name version;
  buildInputs = [ cmake qt4 openssl xproto libX11 libXScrnSaver scrnsaverproto xz ];
  meta = with lib; {
    description = "An XMPP client fully composed of plugins";
    maintainers = with maintainers; [ raskin ];
    platforms = platforms.linux;
    license = licenses.gpl3;
    homepage = http://www.vacuum-im.org/;
  };
}
