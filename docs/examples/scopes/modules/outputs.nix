# The flake gives the scope ids: `sven.lib.graph` is readable inside the fleet.
{ sven, ... }:
{
  sven.kinds.fleet.sinks.out.reduce = sven.lib.reduce.merge;
  sven.flake = { out, ... }: out;
  sven.aspects.tree = {
    at = sven.kinds.fleet;
    out.scopes = map (s: s.id) sven.lib.graph.scopes;
  };
}
