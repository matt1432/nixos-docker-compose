self: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types;
  inherit (lib.attrsets) attrNames attrValues filterAttrs hasAttr mapAttrs mapAttrs' nameValuePair removeAttrs;
  inherit (lib.lists) elem filter;
  inherit (lib.modules) mkIf mkOverride;
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatMapStringsSep concatStringsSep isString optionalString;

  cfg = config.virtualisation.docker;

  settingsFormat = pkgs.formats.yaml {};

  getImageNameFromDerivation = drv: let
    attrNamesOf = attrNames drv;
  in
    if elem "destNameTag" attrNamesOf
    then
      # image coming from dockerTools.pullImage
      drv.destNameTag
    else
      # image coming from dockerTools.buildImage
      if elem "imageName" attrNamesOf && elem "imageTag" attrNamesOf
      then "${drv.imageName}:${drv.imageTag}"
      else
        throw
        "Image '${drv}' is missing the attribute 'destNameTag'. Available attributes: ${
          concatStringsSep "," attrNamesOf
        }";

  getImageName = image:
    if isString image
    then image
    else getImageNameFromDerivation image;

  /*
  * modifications: an attribute set of attribute names and a function to apply on that attribute.
  * attrs:         an attribute set on which we will apply the functions from `mods`.
  *
  * returns `attrs` with the functions of `mods` applied to it.
  */
  modifyAttrs = modifications: attrs:
    mapAttrs (n: v:
      if hasAttr n modifications
      then modifications.${n} v
      else v)
    attrs;

  mkComposeSystemdUnit = name: settings: let
    # Get rid of options that we don't want in the compose.yaml file
    composeSettings = removeAttrs settings ["enable" "systemdDependencies"];

    modifiedSettings =
      modifyAttrs
      {
        services = mapAttrs (_: service:
          modifyAttrs
          {
            image = getImageName;
          }
          service);
      }
      composeSettings;

    composeFile = settingsFormat.generate "compose.yaml" modifiedSettings;
  in
    nameValuePair "compose-${name}" rec {
      path = [cfg.package];

      preStart = let
        services = attrValues composeSettings.services;
        images = map (x: x.image) services;
        imageDerivations = filter (image: !(isString image)) images;
      in
        optionalString (imageDerivations != []) (concatMapStringsSep "\n"
          (image: "docker load -i ${toString image}")
          imageDerivations);

      script = ''
        docker compose -f ${composeFile} -p ${name} up \
            --remove-orphans \
            --force-recreate \
            --always-recreate-deps \
            -y
      '';

      preStop = ''
        docker compose -f ${composeFile} -p ${name} down --remove-orphans
      '';

      serviceConfig = {
        Restart = mkOverride 500 "always";
        RestartMaxDelaySec = mkOverride 500 "1m";
        RestartSec = mkOverride 500 "100ms";
        RestartSteps = mkOverride 500 9;
      };

      after = ["docker.service" "docker.socket"] ++ settings.systemdDependencies;
      requires = after;
      wantedBy = ["multi-user.target"];
    };
in {
  # TODO: figure out how to also accept camelCase options
  options.virtualisation.docker.compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      freeformType = settingsFormat.type;

      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enables the systemd unit for ${name}.";
        };

        systemdDependencies = mkOption {
          type = with types; listOf str;
          default = [];
          description = ''
            A list of Systemd units that this composition needs before starting.
          '';
        };

        services = mkOption {
          type = types.attrsOf (types.submodule ({name, ...}: {
            freeformType = settingsFormat.type;

            options = {
              container_name = mkOption {
                type = types.str;
                default = name;
                defaultText = "The name of the attribute set.";
              };

              hostname = mkOption {
                type = types.str;
                default = name;
                defaultText = "The name of the attribute set.";
              };

              image = mkOption {
                type = with types; either str package;
              };
            };
          }));
        };
      };
    }));
  };

  config = mkIf (cfg.enable) {
    systemd.services = mapAttrs' mkComposeSystemdUnit (filterAttrs (_: v: v.enable) cfg.compose);
  };

  # For accurate stack trace
  _file = ./default.nix;
}
