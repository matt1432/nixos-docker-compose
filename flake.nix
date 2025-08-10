{
  inputs = {};

  outputs = {self, ...}: {
    nixosModules = {
      docker-compose = import ./modules;
      default = self.nixosModules.docker-compose;
    };
  };
}
