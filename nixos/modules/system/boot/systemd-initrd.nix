{ config, lib, pkgs, utils, ... }:

with lib;
with utils;
with import ./systemd-unit-options.nix { inherit config lib; };

let

  cfg = config.boot.initrd.systemd;

  systemd = cfg.package;

  makeUnit = name: unit:
    if unit.enable then
      pkgs.runCommand "unit" { preferLocalBuild = true; inherit (unit) text; }
        ''
          mkdir -p $out
          echo -n "$text" > $out/${shellEscape name}
        ''
    else
      pkgs.runCommand "unit" { preferLocalBuild = true; }
        ''
          mkdir -p $out
          ln -s /dev/null $out/${shellEscape name}
        '';

  upstreamInitrdUnits =
    [ # Targets.
      "basic.target"
      "sysinit.target"
      "sockets.target"
      "initrd.target"
      "timers.target"
      "slices.target"
      "paths.target"

      # Initrd units.
      "initrd-root-fs.target"
      "initrd-fs.target"
      "initrd-parse-etc.service"
      
      # Rescue mode.
      "rescue.target"
      "rescue.service"
      "emergency.target"
      "emergency.service"
    ]

    ++ cfg.additionalUpstreamInitrdUnits;

  upstreamInitrdWants =
    [ #"basic.target.wants"
      "sysinit.target.wants"
    ];

  shellEscape = s: (replaceChars [ "\\" ] [ "\\\\" ] s);

  makeJobScript = name: text:
    let x = pkgs.writeTextFile { name = "unit-script"; executable = true; destination = "/bin/${shellEscape name}"; inherit text; };
    in "${x}/bin/${shellEscape name}";

  unitConfig = { name, config, ... }: {
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

  serviceConfig = { name, config, ... }: {
    config = mkMerge
      [ { # Default path for systemd services.  Should be quite minimal.
          path =
            [ pkgs.coreutils
              pkgs.findutils
              pkgs.gnugrep
              pkgs.gnused
              systemd
            ];
          environment.PATH = config.path;
        }
        (mkIf (config.preStart != "")
          { serviceConfig.ExecStartPre = makeJobScript "${name}-pre-start" ''
              #! ${pkgs.stdenv.shell} -e
              ${config.preStart}
            '';
          })
        (mkIf (config.script != "")
          { serviceConfig.ExecStart = makeJobScript "${name}-start" ''
              #! ${pkgs.stdenv.shell} -e
              ${config.script}
            '' + " " + config.scriptArgs;
          })
        (mkIf (config.postStart != "")
          { serviceConfig.ExecStartPost = makeJobScript "${name}-post-start" ''
              #! ${pkgs.stdenv.shell} -e
              ${config.postStart}
            '';
          })
        (mkIf (config.preStop != "")
          { serviceConfig.ExecStop = makeJobScript "${name}-pre-stop" ''
              #! ${pkgs.stdenv.shell} -e
              ${config.preStop}
            '';
          })
        (mkIf (config.postStop != "")
          { serviceConfig.ExecStopPost = makeJobScript "${name}-post-stop" ''
              #! ${pkgs.stdenv.shell} -e
              ${config.postStop}
            '';
          })
      ];
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

  automountConfig = { name, config, ... }: {
    config = {
      automountConfig =
        { Where = config.where;
        };
    };
  };

  toOption = x:
    if x == true then "true"
    else if x == false then "false"
    else toString x;

  attrsToSection = as:
    concatStrings (concatLists (mapAttrsToList (name: value:
      map (x: ''
          ${name}=${toOption x}
        '')
        (if isList value then value else [value]))
        as));

  commonUnitText = def: ''
      [Unit]
      ${attrsToSection def.unitConfig}
    '';

  targetToUnit = name: def:
    { inherit (def) wantedBy requiredBy enable;
      text =
        ''
          [Unit]
          ${attrsToSection def.unitConfig}
        '';
    };

  serviceToUnit = name: def:
    { inherit (def) wantedBy requiredBy enable;
      text = commonUnitText def +
        ''
          [Service]
          ${let env = cfg.globalEnvironment // def.environment;
            in concatMapStrings (n:
              let s = "Environment=\"${n}=${getAttr n env}\"\n";
              in if stringLength s >= 2048 then throw "The value of the environment variable ‘${n}’ in systemd service ‘${name}.service’ is too long." else s) (attrNames env)}
          ${if def.reloadIfChanged then ''
            X-ReloadIfChanged=true
          '' else if !def.restartIfChanged then ''
            X-RestartIfChanged=false
          '' else ""}
          ${optionalString (!def.stopIfChanged) "X-StopIfChanged=false"}
          ${attrsToSection def.serviceConfig}
        '';
    };

  socketToUnit = name: def:
    { inherit (def) wantedBy requiredBy enable;
      text = commonUnitText def +
        ''
          [Socket]
          ${attrsToSection def.socketConfig}
          ${concatStringsSep "\n" (map (s: "ListenStream=${s}") def.listenStreams)}
        '';
    };

  timerToUnit = name: def:
    { inherit (def) wantedBy requiredBy enable;
      text = commonUnitText def +
        ''
          [Timer]
          ${attrsToSection def.timerConfig}
        '';
    };

  pathToUnit = name: def:
    { inherit (def) wantedBy requiredBy enable;
      text = commonUnitText def +
        ''
          [Path]
          ${attrsToSection def.pathConfig}
        '';
    };

  mountToUnit = name: def:
    { inherit (def) wantedBy requiredBy enable;
      text = commonUnitText def +
        ''
          [Mount]
          ${attrsToSection def.mountConfig}
        '';
    };

  automountToUnit = name: def:
    { inherit (def) wantedBy requiredBy enable;
      text = commonUnitText def +
        ''
          [Automount]
          ${attrsToSection def.automountConfig}
        '';
    };

  generateUnits = units: upstreamUnits: upstreamWants:
    pkgs.runCommand "initrd-units" {
      buildInputs = [ pkgs.nukeReferences ];
      allowedReferences = [ "out" config.system.build.extraUtils ];
    } ''
      mkdir -p $out

      # Copy the upstream systemd units we're interested in.
      for i in ${toString upstreamUnits}; do
        fn=${systemd}/example/systemd/system/$i
        if ! [ -e $fn ]; then echo "missing $fn"; false; fi
        if [ -L $fn ]; then
          target="$(readlink "$fn")"
          if [ ''${target:0:3} = ../ ]; then
            cp -v "$(readlink -f "$fn")" $out/
          else
            cp -pd $fn $out/
          fi
        else
          cp -v $fn $out/
        fi
      done

      # Copy .wants links, but only those that point to units that
      # we're interested in.
      for i in ${toString upstreamWants}; do
        fn=${systemd}/example/systemd/system/$i
        if ! [ -e $fn ]; then echo "missing $fn"; false; fi
        x=$out/$(basename $fn)
        mkdir $x
        for i in $fn/*; do
          y=$x/$(basename $i)
          cp -pd $i $y
          if ! [ -e $y ]; then rm $y; fi
        done
      done

      # Symlink all units provided listed in systemd.packages.
      for i in ${toString cfg.packages}; do
        for fn in $i/etc/systemd/system/* $i/lib/systemd/system/*; do
          if ! [[ "$fn" =~ .wants$ ]]; then
            cp -v $fn $out/
          fi
        done
      done

      # Symlink all units defined by systemd.units. If these are also
      # provided by systemd or systemd.packages, then add them as
      # <unit-name>.d/overrides.conf, which makes them extend the
      # upstream unit.
      for i in ${toString (mapAttrsToList (n: v: v.unit) units)}; do
        fn=$(basename $i/*)
        if [ -e $out/$fn ]; then
          if [ "$(readlink -f $i/$fn)" = /dev/null ]; then
            ln -sfn /dev/null $out/$fn
          else
            mkdir $out/$fn.d
            cp -v $i/$fn $out/$fn.d/overrides.conf
          fi
       else
          cp -v $i/$fn $out/
        fi
      done

      # Created .wants and .requires symlinks from the wantedBy and
      # requiredBy options.
      ${concatStrings (mapAttrsToList (name: unit:
          concatMapStrings (name2: ''
            mkdir -p $out/'${name2}.wants'
            ln -sfn '../${name}' $out/'${name2}.wants'/
          '') unit.wantedBy) units)}

      ${concatStrings (mapAttrsToList (name: unit:
          concatMapStrings (name2: ''
            mkdir -p $out/'${name2}.requires'
            ln -sfn '../${name}' $out/'${name2}.requires'/
          '') unit.requiredBy) units)}

      # Default target
      ln -sfn ${cfg.defaultUnit} $out/default.target
      
      echo "patching units..."
      find $out -type f -exec nuke-refs -p ${config.system.build.extraUtils} '{}' \;
    '';

in

{

  ###### interface

  options.boot.initrd = {

    systemd.package = mkOption {
      default = pkgs.systemd.override { pamSupport = false; };
      type = types.package;
      description = "The systemd package.";
    };

    systemd.units = mkOption {
      description = "Definition of systemd units.";
      default = {};
      type = types.attrsOf types.optionSet;
      options = { name, config, ... }:
        { options = concreteUnitOptions;
          config = {
            unit = mkDefault (makeUnit name config);
          };
        };
    };

    systemd.packages = mkOption {
      default = [];
      type = types.listOf types.package;
      description = "Packages providing systemd units.";
    };

    systemd.targets = mkOption {
      default = {};
      type = types.attrsOf types.optionSet;
      options = [ targetOptions unitConfig ];
      description = "Definition of systemd target units.";
    };

    systemd.services = mkOption {
      default = {};
      type = types.attrsOf types.optionSet;
      options = [ serviceOptions unitConfig serviceConfig ];
      description = "Definition of systemd service units.";
    };

    systemd.sockets = mkOption {
      default = {};
      type = types.attrsOf types.optionSet;
      options = [ socketOptions unitConfig ];
      description = "Definition of systemd socket units.";
    };

    systemd.timers = mkOption {
      default = {};
      type = types.attrsOf types.optionSet;
      options = [ timerOptions unitConfig ];
      description = "Definition of systemd timer units.";
    };

    systemd.paths = mkOption {
      default = {};
      type = types.attrsOf types.optionSet;
      options = [ pathOptions unitConfig ];
      description = "Definition of systemd path units.";
    };

    systemd.mounts = mkOption {
      default = [];
      type = types.listOf types.optionSet;
      options = [ mountOptions unitConfig mountConfig ];
      description = ''
        Definition of systemd mount units.
        This is a list instead of an attrSet, because systemd mandates the names to be derived from
        the 'where' attribute.
      '';
    };

    systemd.automounts = mkOption {
      default = [];
      type = types.listOf types.optionSet;
      options = [ automountOptions unitConfig automountConfig ];
      description = ''
        Definition of systemd automount units.
        This is a list instead of an attrSet, because systemd mandates the names to be derived from
        the 'where' attribute.
      '';
    };

    systemd.defaultUnit = mkOption {
      default = "initrd.target";
      type = types.str;
      description = "Default unit started when the initrd boots.";
    };

    systemd.globalEnvironment = mkOption {
      type = types.attrs;
      default = {};
      example = { TZ = "CET"; };
      description = ''
        Environment variables passed to <emphasis>all</emphasis> systemd units.
      '';
    };

    systemd.extraConfig = mkOption {
      default = "";
      type = types.lines;
      example = "DefaultLimitCORE=infinity";
      description = ''
        Extra config options for systemd. See man systemd-system.conf for
        available options.
      '';
    };

    systemd.additionalUpstreamInitrdUnits = mkOption {
      default = [ ];
      type = types.listOf types.str;
      description = ''
        Additional units shipped with systemd that shall be enabled.
      '';
    };

  };


  ###### implementation

  config = {

    boot.initrd.systemd.units =
      mapAttrs' (n: v: nameValuePair "${n}.target" (targetToUnit n v)) cfg.targets
      // mapAttrs' (n: v: nameValuePair "${n}.service" (serviceToUnit n v)) cfg.services
      // mapAttrs' (n: v: nameValuePair "${n}.socket" (socketToUnit n v)) cfg.sockets
      // mapAttrs' (n: v: nameValuePair "${n}.timer" (timerToUnit n v)) cfg.timers
      // mapAttrs' (n: v: nameValuePair "${n}.path" (pathToUnit n v)) cfg.paths
      // listToAttrs (map
                   (v: let n = escapeSystemdPath v.where;
                       in nameValuePair "${n}.mount" (mountToUnit n v)) cfg.mounts)
      // listToAttrs (map
                   (v: let n = escapeSystemdPath v.where;
                       in nameValuePair "${n}.automount" (automountToUnit n v)) cfg.automounts);

    boot.initrd.extraUtilsCommands = ''
      cp -v ${systemd}/lib/systemd/systemd $out/bin
      cp -v ${systemd}/bin/systemctl $out/bin
      cp -v ${pkgs.libcap}/lib/libcap.so.* $out/lib

    '';

    boot.initrd.extraUtilsCommandsPatch = ''
      for i in $out/lib/libcap.so.*; do
          if ! test -L $i; then
              echo "patching $i..."
              patchelf --set-rpath $out/lib $i || true
          fi
      done
    '';

    boot.initrd.extraUtilsCommandsTest = ''
      $out/bin/systemd --version
    '';

    boot.initrd.extraContents = [
      { object = generateUnits cfg.units upstreamInitrdUnits upstreamInitrdWants;
        symlink = "/etc/systemd/system";
      }
    ];
      
  };
}
