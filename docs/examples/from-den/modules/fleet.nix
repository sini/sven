# What Den gives you built in, declared: hosts build NixOS, users live on hosts, a user's home goes into its host.
{
  sven,
  lib,
  inputs,
  ...
}:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host = {
    fields.system = lib.types.str;
    spawns.user = s: lib.filterAttrs (_: u: lib.any (sven.lib.same s) u.hosts) sven.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules = nixos;
        };
      };
  };
  sven.kinds.user = {
    fields.hosts = sven.lib.is lib.isList;
    sinks.homeManager.nixos =
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };
  sven.aspects.home-manager = {
    at = sven.lib.has sven.kinds.user;
    nixos.imports = [ inputs.home-manager.nixosModules.home-manager ];
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
