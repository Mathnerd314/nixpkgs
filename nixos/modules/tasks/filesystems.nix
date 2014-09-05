{ config, lib, pkgs, utils, ... }:

with lib;
with utils;
with import ../system/boot/systemd-unit-options.nix { inherit config lib; };

let

  fileSystems = attrValues config.fileSystems;

  prioOption = prio: optionalString (prio !=null) " pri=${toString prio}";

  unitConfig = { config, ... }: {
    config = {
      unitConfig =
        optionalAttrs (config.requires != [])
          { Requires = toString config.requires; }
        // optionalAttrs (config.wants != [])
          { Wants = toString config.wants; }
        // optionalAttrs (config.after != [])
          { After = toString config.after; }
        // optionalAttrs (config.before != [])
          { Before = toString config.before; }
        // optionalAttrs (config.bindsTo != [])
          { BindsTo = toString config.bindsTo; }
        // optionalAttrs (config.partOf != [])
          { PartOf = toString config.partOf; }
        // optionalAttrs (config.conflicts != [])
          { Conflicts = toString config.conflicts; }
        // optionalAttrs (config.restartTriggers != [])
          { X-Restart-Triggers = toString config.restartTriggers; }
        // optionalAttrs (config.description != "") {
          Description = config.description;
        };
    };
  };

  mountConfig = { name, config, ... }: {
    config = {
      mountConfig =
        { What = config.what;
          Where = config.where;
        } // optionalAttrs (config.type != "") {
          Type = config.type;
        } // optionalAttrs (config.options != "") {
          Options = config.options;
        };
    };
  };

  fileSystemOpts = { name, config, ... }: {

    options = {

      mountPoint = mkOption {
        example = "/mnt/usb";
        type = types.str;
        description = "Location of the mounted the file system.";
      };

      device = mkOption {
        default = null;
        example = "/dev/sda";
        type = types.uniq (types.nullOr types.string);
        description = "Location of the device.";
      };

      label = mkOption {
        default = null;
        example = "root-partition";
        type = types.uniq (types.nullOr types.string);
        description = "Label of the device (if any).";
      };

      fsType = mkOption {
        default = "auto";
        example = "ext3";
        type = types.str;
        description = "Type of the file system.";
      };

      options = mkOption {
        default = "defaults,relatime";
        example = "data=journal";
        type = types.commas;
        description = "Options used to mount the file system.";
      };

      autoFormat = mkOption {
        default = false;
        type = types.bool;
        description = ''
          If the device does not currently contain a filesystem (as
          determined by <command>blkid</command>, then automatically
          format it with the filesystem type specified in
          <option>fsType</option>.  Use with caution.
        '';
      };

      noCheck = mkOption {
        default = false;
        type = types.bool;
        description = "Disable running fsck on this filesystem.";
      };

      mountBefore = mkOption {
        default = [];
        type = types.listOf types.str;
        description = "Mount this file system before the listed file systems.";
      };

      mountAfter = mkOption {
        default = [];
        type = types.listOf types.str;
        description = "Mount this file system after the listed file systems.";
      };

      systemdConfig = mkOption {
        default = {};
        type = types.optionSet;
        options = [ mountOptions ];
        description = "Additional configuration for systemd.";
      };

      systemdInitrdConfig = mkOption {
        internal = true;
        default = {};
        type = types.optionSet;
        options = [ mountOptions ];
        description = "Additional configuration for the initrd.";
      };

    };

    config = {
      mountPoint = mkDefault name;
      device = mkIf (config.fsType == "tmpfs") (mkDefault config.fsType);

      systemdConfig = {
        wantedBy = mkDefault (map (x: "${escapeSystemdPath x}.mount") config.mountBefore);
        before = mkDefault (map (x: "${escapeSystemdPath x}.mount") config.mountBefore);

        wants = mkDefault (map (x: "${escapeSystemdPath x}.mount") config.mountAfter);
        after = mkDefault (map (x: "${escapeSystemdPath x}.mount") config.mountAfter);

        what = config.device;
        where = config.mountPoint;
        type = config.fsType;
        options = config.options;
      };

      systemdInitrdConfig = {
        wantedBy = mkDefault (map (x: escapeSystemdPath "/sysroot/${x}.mount") config.mountBefore);
        before = mkDefault (
          (map (x: escapeSystemdPath "/sysroot/${x}.mount") config.mountBefore)
          ++ (if config.mountPoint == "/" then [ "initrd-root-fs.target" ] else [ "initrd-fs.target" ]));

        wants = mkDefault (map (x: "sysroot-${escapeSystemdPath x}.mount") config.mountAfter);
        after = mkDefault (map (x: "sysroot-${escapeSystemdPath x}.mount") config.mountAfter);
        
        requiredBy = mkDefault (if config.mountPoint == "/" then [ "initrd-root-fs.target" ] else [ "initrd-fs.target" ]);

        where = if config.mountPoint == "/" then "/sysroot" else "/sysroot" + config.mountPoint;
        what = if hasPrefix "/" config.device && !(hasPrefix "/dev" config.device) then "/sysroot/${config.device}" # for bind mounts
               else config.device;
        type = config.fsType;
        options = config.options;
      };
      
    };

  };

in

{

  ###### interface

  options = {

    fileSystems = mkOption {
      default = {};
      example = {
        "/".device = "/dev/hda1";
        "/data" = {
          device = "/dev/hda2";
          fsType = "ext3";
          options = "data=journal";
        };
        "/bigdisk".label = "bigdisk";
      };
      type = types.loaOf types.optionSet;
      options = [ fileSystemOpts ];
      description = ''
        The file systems to be mounted.  It must include an entry for
        the root directory (<literal>mountPoint = "/"</literal>).  Each
        entry in the list is an attribute set with the following fields:
        <literal>mountPoint</literal>, <literal>device</literal>,
        <literal>fsType</literal> (a file system type recognised by
        <command>mount</command>; defaults to
        <literal>"auto"</literal>), and <literal>options</literal>
        (the mount options passed to <command>mount</command> using the
        <option>-o</option> flag; defaults to <literal>"defaults"</literal>).

        Instead of specifying <literal>device</literal>, you can also
        specify a volume label (<literal>label</literal>) for file
        systems that support it, such as ext2/ext3 (see <command>mke2fs
        -L</command>).
      '';
    };

    system.fsPackages = mkOption {
      internal = true;
      default = [ ];
      description = "Packages supplying file system mounters and checkers.";
    };

    boot.supportedFilesystems = mkOption {
      default = [ ];
      example = [ "btrfs" ];
      type = types.listOf types.string;
      description = "Names of supported filesystem types.";
    };

  };


  ###### implementation

  config = {

    boot.supportedFilesystems = map (fs: fs.fsType) fileSystems;

    # Add the mount helpers to the system path so that `mount' can find them.
    system.fsPackages = [ pkgs.dosfstools ];

    environment.systemPackages =
      [ pkgs.ntfs3g pkgs.fuse ]
      ++ config.system.fsPackages;

    environment.etc.fstab.text =
      ''
        # This is a generated file.  Do not edit!

        # Filesystems.
        ${flip concatMapStrings fileSystems (fs:
            (if fs.device != null then fs.device
             else if fs.label != null then "/dev/disk/by-label/${fs.label}"
             else throw "No device specified for mount point ‘${fs.mountPoint}’.")
            + " " + fs.mountPoint
            + " " + fs.fsType
            + " " + fs.options
            + " 0"
            + " " + (if fs.fsType == "none" || fs.device == "none" || fs.fsType == "btrfs" || fs.fsType == "tmpfs" || fs.noCheck then "0" else
                     if fs.mountPoint == "/" then "1" else "2")
            + "\n"
        )}

        # Swap devices.
        ${flip concatMapStrings config.swapDevices (sw:
            "${sw.device} none swap${prioOption sw.priority}\n"
        )}
      '';

    # Provide a target that pulls in all filesystems.
    systemd.targets.fs =
      { description = "All File Systems";
        wants = [ "local-fs.target" "remote-fs.target" ];
      };

    # Emit systemd services to format requested filesystems.
    systemd.services =
      let

        formatDevice = fs:
          let
            mountPoint' = escapeSystemdPath fs.mountPoint;
            device' = escapeSystemdPath fs.device;
            # -F needed to allow bare block device without partitions
            mkfsOpts = optional ((builtins.substring 0 3 fs.fsType) == "ext") "-F";
          in nameValuePair "mkfs-${device'}"
          { description = "Initialisation of Filesystem ${fs.device}";
            wantedBy = [ "${mountPoint'}.mount" ];
            before = [ "${mountPoint'}.mount" "systemd-fsck@${device'}.service" ];
            requires = [ "${device'}.device" ];
            after = [ "${device'}.device" ];
            path = [ pkgs.utillinux ] ++ config.system.fsPackages;
            script =
              ''
                if ! [ -e "${fs.device}" ]; then exit 1; fi
                # FIXME: this is scary.  The test could be more robust.
                type=$(blkid -p -s TYPE -o value "${fs.device}" || true)
                if [ -z "$type" ]; then
                  echo "creating ${fs.fsType} filesystem on ${fs.device}..."
                  mkfs.${fs.fsType} ${concatStringsSep " " mkfsOpts} "${fs.device}"
                fi
              '';
            unitConfig.RequiresMountsFor = [ "${dirOf fs.device}" ];
            unitConfig.DefaultDependencies = false; # needed to prevent a cycle
            serviceConfig.Type = "oneshot";
          };

      in listToAttrs (map formatDevice (filter (fs: fs.autoFormat) fileSystems));

    # Emit a .mount for each mount point
    systemd.mounts = map (x: x.systemdConfig) fileSystems;

  };

}
