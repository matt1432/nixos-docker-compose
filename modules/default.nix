self: {
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.virtualisation.docker-compose;
in {
  options.virtualisation.docker-compose = {
    enable = mkEnableOption ''
      This option enables docker-compose declaration in nix code.
    '';

    compositions = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        freeformType = types.yaml.type;

        options = {
          enabled = mkEnableOption "Enables the systemd unit for ${name}.";
        };
      }));
    };
  };

  config = mkIf (cfg.enable) {};

  # For accurate stack trace
  _file = ./default.nix;
}
