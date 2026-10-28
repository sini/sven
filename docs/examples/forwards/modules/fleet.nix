{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.spawns.guest = s: lib.filterAttrs (_: g: sven.lib.same g.on s) sven.guest;
  sven.kinds.guest.fields.on = sven.kinds.host;

  sven.fleet.main = { };
  sven.host.server = { };
  sven.guest.ci.on = sven.host.server;
  sven.flake = { out, ... }: out;
}
