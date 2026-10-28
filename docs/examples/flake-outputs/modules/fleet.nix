# The `out` sink of the root is the flake: `sven.flake` gives it.
{ sven, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.sinks.services.out =
    { host, services, ... }:
    {
      services.${host.name} = services;
    };
  sven.fleet.main = { };
  sven.host.web = { };
  sven.host.db = { };
  sven.flake = { out, ... }: out;
}
