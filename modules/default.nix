self: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types;
  inherit (lib.attrsets) attrNames attrValues filterAttrs mapAttrs mapAttrs' nameValuePair removeAttrs;
  inherit (lib.lists) elem filter;
  inherit (lib.modules) mkIf mkOverride;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.strings) concatMapStringsSep concatStringsSep isString optionalString;

  cfg = config.virtualisation.docker-compose;

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

  enabledCompositions =
    mapAttrs
    (_: v: removeAttrs v ["enable"])
    (filterAttrs (_: v: v.enable) cfg.compositions);

  mkSystemdUnit = name: settings:
    nameValuePair "compose-${name}" {
      path = attrValues {
        inherit
          (pkgs)
          docker
          ;
      };

      preStart = let
        imageDerivations =
          filter
          (image: !(isString image))
          (map (x: x.image) (attrValues settings.services));
      in
        optionalString (imageDerivations != []) (concatMapStringsSep "\n"
          (image: "docker load -i ${toString image}")
          imageDerivations);

      serviceConfig = {
        Restart = mkOverride 500 "always";
        RestartMaxDelaySec = mkOverride 500 "1m";
        RestartSec = mkOverride 500 "100ms";
        RestartSteps = mkOverride 500 9;
      };

      after = ["docker.service" "docker.socket"];
      requires = ["docker.service" "docker.socket"];
      wantedBy = ["multi-user.target"];
    };
in {
  options.virtualisation.docker-compose = {
    enable = mkEnableOption ''
      This option enables docker-compose declaration in nix code.
    '';

    compositions = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        freeformType = types.yaml.type;

        options = {
          enable = mkEnableOption "Enables the systemd unit for ${name}.";

          services = mkOption {
            type = types.attrsOf (types.submodule ({...}: {
              freeformType = types.yaml.type;

              options = {
                image = mkOption {
                  type = with types; either str package;
                };
              };
            }));
          };
        };
      }));
    };
  };

  config = mkIf (cfg.enable) {
    systemd.services = mapAttrs' mkSystemdUnit enabledCompositions;
  };

  # For accurate stack trace
  _file = ./default.nix;
}
