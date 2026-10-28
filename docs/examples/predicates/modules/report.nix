# Each aspect says where it is active. `entries` keeps the giving scope with each value.
{ sven, lib, ... }:
{
  sven.kinds.fleet.sinks.seen = {
    reduce = sven.lib.reduce.entries;
    out = { seen, ... }: { active = lib.mapAttrs (_: es: map (e: e.from.name) es) (lib.groupBy (e: e.value) seen); };
  };
  sven.flake = { out, ... }: out;
  sven.kinds.fleet.sinks.out.reduce = sven.lib.reduce.merge;
  sven.aspects = lib.genAttrs [ "builder" "cuda" "tiny" "vm-tools" "vm-host" "monitored" ] (a: { seen = { scope, ... }: a; }); # a function: one element per scope
}
