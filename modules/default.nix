self: {
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption types;

  cfg = config.virtualisation.docker-compose;
in {
  options.virtualisation.docker-compose = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        This option enables docker-compose declaration in nix code.
      '';
    };
  };

  config = mkIf (cfg.enable) {};

  # For accurate stack trace
  _file = ./default.nix;
}
