# swarsel exports: aspects used outside sven. An export scope never builds a machine;
# what lands on it becomes `nixosModules.<name>` for other flakes (Den: `moduleOf`, "change needed").
{ sven, ... }:
{
  sven.kinds.fleet.spawns.export = _: sven.export;
  sven.kinds.export.sinks.os.out = { export, os, ... }: { nixosModules.${export.name}.imports = os; };
  sven.export.base = { };
  sven.aspects.motd.at = [ sven.export.base ];
  sven.aspects.dev.at = [ sven.export.base ];
}
