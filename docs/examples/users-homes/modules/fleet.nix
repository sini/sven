# Hosts build NixOS and hold their users. Homes are standalone home-manager configurations.
{ sven, lib, inputs, ... }:
let
  inherit (sven.lib) same is;
in
{
  sven.kinds.fleet = {
    spawns = { host = _: sven.host; home = _: sven.home; };
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host = {
    spawns.user = s: lib.filterAttrs (_: u: lib.any (same s) u.hosts) sven.user;
    sinks.nixos.out = { host, nixos, ... }: {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };
  };
  sven.kinds.user = {
    fields.hosts = is lib.isList;
    sinks.homeManager.nixos = { user, homeManager, ... }: { home-manager.users.${user.name}.imports = homeManager; };
  };
  sven.kinds.home = {
    fields = { user = sven.kinds.user; system = lib.types.str; };
    sinks.homeManager.out = { home, homeManager, ... }: {
      homeConfigurations.${home.name} = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${home.system};
        modules = homeManager;
      };
    };
  };
  sven.aspects.home-manager = {
    at = sven.lib.has sven.kinds.user;
    nixos = { imports = [ inputs.home-manager.nixosModules.home-manager ]; home-manager.useGlobalPkgs = true; };
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
