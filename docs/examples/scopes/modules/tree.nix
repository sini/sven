# `spawns.<kind>` gives the children of a scope: a function of the parent scope.
{ sven, lib, ... }:
let
  inherit (sven.lib) same is;
in
{
  sven.kinds.fleet.spawns.environment = _: sven.environment;
  sven.kinds.environment.spawns.host = s: lib.filterAttrs (_: h: same h.environment s) sven.host;
  sven.kinds.host = {
    fields.environment = sven.kinds.environment;
    spawns.user = s: lib.filterAttrs (_: u: lib.any (same s) u.hosts) sven.user;
  };
  sven.kinds.user.fields.hosts = is lib.isList; # refs to the hosts the user logs in to

  sven.fleet.main = { };
}
