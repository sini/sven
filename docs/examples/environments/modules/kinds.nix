# fleet > environment > host > user. Groups are data: an environment grants groups, a user is in groups.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib)
    same
    maybe
    opt
    is
    ;
  listOf = t: is (v: lib.isList v && lib.all t.check v);
  meets = xs: ys: lib.any (x: lib.any (same x) ys) xs;
in
{
  sven.kinds.fleet = {
    spawns.environment = _: sven.environment;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.group = { };
  sven.kinds.environment = {
    fields = {
      domain = lib.types.str;
      base = maybe sven.kinds.environment; # settings it does not set come from here
      grants = opt (listOf sven.kinds.group) [ ];
      settings.timeZone = maybe lib.types.str;
    };
    spawns.host = s: lib.filterAttrs (_: h: same h.environment s) sven.host;
  };
  sven.kinds.host = {
    fields = {
      environment = sven.kinds.environment;
      settings.timeZone = maybe lib.types.str;
    };
    spawns.user = s: lib.filterAttrs (_: u: meets u.groups s.environment.grants) sven.user; # access from data
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  sven.kinds.user.fields.groups = listOf sven.kinds.group;

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
