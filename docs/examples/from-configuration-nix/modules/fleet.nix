# The fleet spawns hosts and the users that log in to them.
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
    spawns.user = s: lib.filterAttrs (_: u: lib.any (sven.lib.same s) u.hosts) sven.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  sven.kinds.user.fields = {
    hosts = sven.lib.is lib.isList;
    groups = sven.lib.opt (sven.lib.is lib.isList) [ ];
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
