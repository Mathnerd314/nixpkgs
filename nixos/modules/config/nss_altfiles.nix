# NSS Altfiles
{ config, lib, pkgs, ... }:

with lib;

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.nss_altfiles;

  inherit (pkgs) nss_altfiles { datadir = cfg.datadir, types = cfg.types };

  setupScript =
    ''
      if ! test -d ${cfg.datadir} ; then
        mkdir -p ${cfg.datadir}
      fi
    '';

  # This may include nss_ldap, needed for samba if it has to use ldap.
  nssModulesPath = config.system.nssModules.path;

in

{

  ###### interface

  options = {

    nss_altfiles = {

      enable = mkOption {
        default = false;
        description = ''
          Build nss_altfiles and include it in the NSS search path
        '';
      };

      datadir = mkOption {
        type = types.str;
        description = ''
          Path where the altfiles data will be located.
        '';
      };

      types = mkOption {
        default = [ "pwd" "grp" ];
        description = ''
          List of NSS databases to enable. Possible values are:
          rpc, proto, hosts, network, service, pwd, grp, spwd, sgrp
        '';
      };
    };

  };


  ###### implementation

  config = mkIf cfg.enable {
    system.nssModules = optional cfg.enable nss_altfiles;
    # see nsswith.nix for config file
  };

}
