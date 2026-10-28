{ sven, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.fleet.main = { };
  sven.host.web = { };
  sven.flake = { out, ... }: out;
}
