# Configuration synthesis with krn (µKanren). The fleet states constraints; krn finds values that satisfy them.
# 1. Ports: each app on a host gets a port from the host's range, no two apps share one. The first answer is the
#    allocation. Run backward, the same relation answers "which apps can take port 8081".
# 2. Placement: each host gets the database hosts of its own environment. The relation is a join over host records
#    by unification, not a filter written by hand.
{ sven, lib, ... }:
let
  K = sven.lib.krn;
  inherit (K) run runAll fresh freshNamed eq membero neq facto;
  # all different: neq on every pair (krn has no constraint store, so it goes after the goals that choose the values)
  distinct = xs: lib.concatLists (lib.imap0 (i: x: map (y: neq x y) (lib.drop (i + 1) xs)) xs);
  portsRel = apps: range: q: freshNamed apps (vs: map (a: membero vs.${a} range) apps ++ distinct (lib.attrValues vs) ++ [ (eq q vs) ]);
  hostRows = lib.mapAttrsToList (n: h: { name = n; env = h.environment.name; db = h.dbRole; }) (lib.filterAttrs (_: h: h ? addr) sven.host);
in
{
  sven.kinds.machine.fields = {
    apps = sven.lib.opt (sven.helpers.listOf lib.types.str) [ ];
    portRange = sven.lib.opt (sven.helpers.listOf lib.types.int) [ ];
    dbRole = sven.lib.opt lib.types.bool false;
  };
  sven.host.lb = { apps = [ "grafana" "loki" "prometheus" ]; portRange = [ 8080 8081 8082 8083 ]; dbRole = true; };
  sven.host.stage.dbRole = true;

  sven.aspects.port-synthesis = {
    at = sven.lib.all [ sven.kinds.host (s: s.apps != [ ]) ];
    nixos = { host, ... }: let a = run 1 (portsRel host.apps host.portRange); in lib.optionalAttrs (a != [ ]) { environment.etc."apps/ports".text = builtins.toJSON (lib.head a); };
    errors = { host, ... }: lib.optional (run 1 (portsRel host.apps host.portRange) == [ ])
      "ports: no allocation for ${host.name}: ${toString (lib.length host.apps)} apps, ports ${toString host.portRange}";
  };
  sven.aspects.db-placement = {
    at = sven.fleet.main;
    out = { ... }: {
      dbPlacement = lib.genAttrs (map (r: r.name) hostRows) (h: runAll (q: fresh ({ env, d, own }: [
        (facto hostRows { name = h; inherit env; db = own; })
        (facto hostRows { name = d; inherit env; db = true; })
        (eq q d) ])));
      # backward: with lb's apps and range, which apps can take port 8081 in some allocation
      takes8081 = lib.unique (map (m: lib.findFirst (a: m.${a} == 8081) null (lib.attrNames m))
        (lib.filter (m: lib.elem 8081 (lib.attrValues m)) (runAll (portsRel sven.host.lb.apps sven.host.lb.portRange))));
    };
  };
}
