# den-hoag relations + query calculus: a relation is a ref field; queries are plain Nix over it.
# `deployWaves` is the BFS-layers query over dependsOn (a host deploys after what it depends on); `dependents` is the
# reverse read (transpose). Both use genericClosure: no recursion depth limit.
{ sven, lib, ... }:
let
  hosts = lib.filterAttrs (_: h: h ? addr) sven.host;
  deps = h: map (d: d.name) (h.dependsOn or [ ]);
  depth = n: lib.foldl' lib.max 0 (map (x: x.d) (builtins.genericClosure {
    startSet = [ { key = n; d = 0; } ];
    operator = x: map (m: { key = "${m}@${toString (x.d + 1)}"; name = m; d = x.d + 1; }) (deps hosts.${x.name or x.key});
  }));
  waves = let ds = lib.mapAttrs (n: _: depth n) hosts; in lib.genList (i: lib.attrNames (lib.filterAttrs (_: d: d == i) ds)) (lib.foldl' lib.max 0 (lib.attrValues ds) + 1);
in
{
  sven.kinds.machine.fields.dependsOn = sven.lib.opt (sven.helpers.listOf sven.kinds.host) [ ];
  sven.host.web-1.dependsOn = [ sven.host.lb ];
  sven.host.web-2.dependsOn = [ sven.host.lb ];
  sven.host.stage.dependsOn = [ sven.host.web-1 ];
  sven.aspects.deploy-waves = { at = sven.fleet.main; out = { ... }: { deployWaves = waves; dependents = lib.mapAttrs (n: _: lib.attrNames (lib.filterAttrs (_: h: lib.elem n (deps h)) hosts)) hosts; }; };
}
