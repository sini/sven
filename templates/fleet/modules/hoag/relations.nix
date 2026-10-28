# den-hoag relations + query calculus: a relation is a ref field; queries are sven.lib.graphs over it.
# `deployWaves`: a host deploys after what it depends on (layers). `dependents`: the reverse read (transpose).
# `impact`: everything that breaks, transitively, when a host goes down (reachers). A dependency cycle is an error.
{ sven, lib, ... }:
let
  G = sven.lib.graphs;
  hosts = lib.filterAttrs (_: h: h ? addr) sven.host;
  dependsOn = lib.mapAttrs (_: h: map (d: d.name) (h.dependsOn or [ ])) hosts;
in
{
  sven.kinds.machine.fields.dependsOn = sven.lib.opt (sven.helpers.listOf sven.kinds.host) [ ];
  sven.host.web-1.dependsOn = [ sven.host.lb ];
  sven.host.web-2.dependsOn = [ sven.host.lb ];
  sven.host.stage.dependsOn = [ sven.host.web-1 ];
  sven.aspects.deploy-waves = {
    at = sven.fleet.main;
    out = { ... }: {
      deployWaves = G.layers dependsOn;
      dependents = G.transpose dependsOn;
      impact = lib.genAttrs (lib.attrNames hosts) (G.reachers dependsOn);
    };
    errors = { ... }: map (c: "deploy: hosts depend on each other in a cycle: ${lib.concatStringsSep " -> " c}") (G.sccs dependsOn);
  };
}
