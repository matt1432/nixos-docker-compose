self: {
  config,
  lib,
  ...
}: let
  inherit (lib) attrNames concatStringsSep elem mkIf mkEnableOption mkOption isString types;

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

  config = mkIf (cfg.enable) {};

  # For accurate stack trace
  _file = ./default.nix;
}
