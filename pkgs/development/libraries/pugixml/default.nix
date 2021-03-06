{ stdenv, fetchurl, cmake }:

stdenv.mkDerivation rec {
  name = "pugixml-${version}";
  version = "1.6";

  src = fetchurl {
    url = "https://github.com/zeux/pugixml/releases/download/v${version}/${name}.tar.gz";
    sha256 = "1pnrdi8n9fdclmhxri3jwc6xwpgvblbjnqkk9ykycpnljv20ads7";
  };

  nativeBuildInputs = [ cmake ];

  sourceRoot = "${name}/scripts";

  preConfigure = ''
    # Enable long long support (required for filezilla)
    sed -ire '/PUGIXML_HAS_LONG_LONG/ s/^\/\///' ../src/pugiconfig.hpp
  '';

  meta = with stdenv.lib; {
    description = "Light-weight, simple and fast XML parser for C++ with XPath support";
    homepage = http://pugixml.org/;
    license = licenses.mit;
    maintainers = with maintainers; [ pSub ];
    platforms = platforms.linux;
  };
}
