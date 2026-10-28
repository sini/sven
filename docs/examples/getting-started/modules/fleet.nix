# The root of the tree. Nothing spawns it. Its `out` sink is the flake.
{ sven, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host; # every host lives under the fleet
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
