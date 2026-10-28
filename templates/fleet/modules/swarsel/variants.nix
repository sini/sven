# swarsel: one machine, two builds. lb-minimal is a host scope under lb: same data, its own nixosConfiguration.
# Identity is the nesting (fleet:main/…/host:lb/host:lb-minimal), so one name can live in two branches.
# Aspects at `sven.host.lb` (haproxy, monitoring) do not hold at lb-minimal: an instance ref names one instance.
{ sven, lib, ... }:
{
  sven.kinds.machine.fields.minimal = sven.lib.opt lib.types.bool false;
  sven.kinds.host.spawns.host = s: lib.optionalAttrs (s.name == "lb") {
    lb-minimal = removeAttrs s [ "kind" "name" "key" "parent" "path" "id" "up" ] // { minimal = true; };
  };
}
