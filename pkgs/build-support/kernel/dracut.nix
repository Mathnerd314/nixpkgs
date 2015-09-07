# Create an initial ramdisk containing the closure of the specified
# file system objects.  An initial ramdisk is used during the initial
# stages of booting a Linux system.  It is loaded by the boot loader
# along with the kernel image.  It's supposed to contain everything
# (such as kernel modules) necessary to allow us to mount the root
# file system.  Once the root file system is mounted, the `real' boot
# script can be called.
#
# An initrd is really just a gzipped cpio archive.
#
# Symlinks are created for each top-level file system object.  E.g.,
# `contents = {object = ...; symlink = /init;}' is a typical
# argument.

/* 
bash-completion
docbook-dtds
pkgconfig
rpmlib(CompressedFileNames) <= 3.0.4-1
rpmlib(FileDigests) <= 4.6.0-1
*/
# { asciidoc, xmlto, dbus, docbook_xsl, docbook_xml_dtd_45, libxslt, libxml2 }:

{stdenv, fetchurl, asciidoc, git, systemd, libxslt, docbook_xsl, docbook_xml_dtd_45, coreutils }:
stdenv.mkDerivation {
  name = "dracut";
  src = fetchurl {
      url = https://www.kernel.org/pub/linux/utils/boot/dracut/dracut-038.tar.xz;
      sha256 = "0jxnz9ahfic79rp93l5wxcbgh4pkv85mwnjlbv1gz3jawv5cvwp1";
  };

  buildInputs = [ asciidoc git systemd libxslt docbook_xsl docbook_xml_dtd_45 coreutils ];

  meta = {
    homepage = "https://dracut.wiki.kernel.org/index.php/Main_Page";
    description = "Initramfs generator using udev";
  };
}
