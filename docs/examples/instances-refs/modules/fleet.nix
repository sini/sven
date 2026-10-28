# The root kind. Its `report` sink collects one attrset per host and gives it to the flake.
{ sven, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
    sinks.report = { reduce = sven.lib.reduce.merge; out = { report, ... }: { inherit report; }; };
  };
  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
