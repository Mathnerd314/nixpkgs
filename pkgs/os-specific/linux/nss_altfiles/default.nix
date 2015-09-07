{stdenv, fetchurl, datadir ? "/var/lib/nss_altfiles", modulename ? "altfiles", types ? "all" }:


stdenv.mkDerivation rec  {
  name = "nss_altfiles";
  version = "v2.19.1";

  src = fetchurl {
    url = "https://github.com/aperezdc/nss-altfiles/archive/${version}.tar.gz";
    sha256 = "0jicyddak1kh4gzz30hd457wq7ysym0x96jq27vqx3f7rxz0xqz1";
  };

  configureFlags = "--datadir=${datadir} --with-module-name=${modulename} --with-types=${types}";

  meta = {
    description = "This NSS module allows looking up users and other NSS databases in an alternate location.";
    homepage = "https://github.com/aperezdc/nss-altfiles";
    license = stdenv.lib.licenses.lgpl2Plus;
  };
}