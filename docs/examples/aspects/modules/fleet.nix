# Hosts with users. A host collects `packages`; a user has no such sink, so its packages go up to its host.
{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host = {
    spawns.user = s: lib.filterAttrs (_: u: lib.any (sven.lib.same s) u.hosts) sven.user;
    sinks.packages.out = { host, packages, ... }: { packages.${host.name} = packages; };
  };
  sven.kinds.user.fields.hosts = sven.lib.is lib.isList;

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
  sven.host.web = { };
  sven.host.db = { };
  sven.user.alice.hosts = [ sven.host.web ];
  sven.user.bob.hosts = [ sven.host.web sven.host.db ];
}
