# The fleet: a root kind, and a host kind with an `admin` sink that takes one element.
{ sven, ... }:
{
  sven.kinds.fleet.spawns.host = _: sven.host;
  sven.kinds.host.sinks.admin.reduce = sven.lib.reduce.one;
  sven.fleet.main = { };
  sven.host.web = { };
}
