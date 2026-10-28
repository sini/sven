# `succ` is an attrset from a node to its successors. Here: a host to the hosts it depends on.
{ sven, lib, ... }:
let
  G = sven.lib.graphs;
  dependsOn = lib.mapAttrs (_: h: map (d: d.name) h.dependsOn) sven.host;
in
{
  sven.aspects.deploy-plan = {
    at = sven.kinds.fleet;
    out.deploy = {
      waves = G.layers dependsOn; # dependencies first: each wave after the waves it depends on
      impact = lib.genAttrs (lib.attrNames sven.host) (G.reachers dependsOn); # who breaks if this host is down
      path = G.shortest dependsOn "lb" "db";
    };
    errors = map (c: "deploy: a dependency cycle: ${lib.concatStringsSep " -> " c}") (lib.filter (c: lib.length c > 1) (G.sccs dependsOn));
  };
}
