# Kinds are your nouns. `spawns` builds the tree from data. Sinks collect what aspects give.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib) same is maybe;
in
{
  sven.kinds.fleet.spawns.env = _: sven.env;
  sven.kinds.fleet.sinks.out.reduce = sven.lib.reduce.merge;
  sven.kinds.env.fields.domain = lib.types.str;
  sven.kinds.env.spawns.host = s: lib.filterAttrs (_: h: same h.env s) sven.host;
  sven.kinds.host.fields = {
    env = sven.kinds.env;
    db = maybe sven.kinds.host;
  };
  sven.kinds.host.spawns.user = s: lib.filterAttrs (_: u: lib.any (same s) u.on) sven.user;
  sven.kinds.host.sinks.os.nixos =
    { os, ... }:
    {
      imports = os;
    }; # os feeds nixos
  sven.kinds.host.sinks.nixos.out =
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };
  sven.kinds.user.fields.on = is lib.isList;
  sven.flake = { out, ... }: out;
}
