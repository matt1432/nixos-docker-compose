self: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types;
  inherit (lib.lists) filter;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkOverride;
  inherit
    (lib.strings)
    concatMapStringsSep
    isString
    optionalString
    ;
  inherit
    (lib.attrsets)
    attrValues
    filterAttrs
    mapAttrs
    mapAttrs'
    nameValuePair
    removeAttrs
    ;

  inherit (import ./lib.nix lib) attrsToSnakeCase getImageName modifyAttrs;

  cfg = config.virtualisation.docker;

  settingsFormat = pkgs.formats.yaml {};
in {
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
          type = types.attrsOf (types.submodule ({
            config,
            name,
            ...
          }: {
            freeformType = settingsFormat.type;

            options = {
              containerName = mkOption {
                type = types.str;
                default = name;
                defaultText = ''
                  The name of the attribute set.
                '';
                description = ''
                  Only this or container_name need to be set.
                '';
              };

              container_name = mkOption {
                type = types.str;
                default = config.containerName;
                defaultText = ''
                  The name of the attribute set.
                '';
                description = ''
                  Only this or containerName need to be set.
                '';
              };

              hostname = mkOption {
                type = types.str;
                default =
                  if config.containerName != name
                  then config.containerName
                  else config.container_name;
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
    systemd.services = let
      mkComposeSystemdUnit = name: settings: let
        # Get rid of options that we don't want in the compose.yaml file
        filteredSettings = removeAttrs settings ["enable" "systemdDependencies"];

        # Transform all known compose option names from camelCase to snake_case
        composeSettings = attrsToSnakeCase filteredSettings;

        modifiedSettings =
          modifyAttrs
          {
            services = mapAttrs (_: service:
              modifyAttrs
              {
                image = getImageName;
              }
              (removeAttrs service ["containerName"]));
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
    in
      mapAttrs' mkComposeSystemdUnit (filterAttrs (_: v: v.enable) cfg.compose);
  };

  # For accurate stack trace
  _file = ./default.nix;
}
