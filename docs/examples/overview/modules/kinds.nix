# Kinds: typed data. `office` is the root: nothing spawns it.
{ sven, lib, ... }:
{
  sven.kinds.office = {
    spawns.machine = _: sven.machine; # scopes: every machine lives in the office
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.machine = {
    fields.owner = lib.types.str;
    sinks.packages.reduce = sven.lib.reduce.set; # sinks: where elements go
    sinks.packages.out = { machine, packages, ... }: { inventory.${machine.name} = packages; };
  };

  sven.office.main = { };
  sven.machine.reception.owner = "ana";
  sven.machine.studio.owner = "bo";
  sven.flake = { out, ... }: out;
}
