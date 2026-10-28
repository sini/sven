# Den specialisations: a variant scope under a host; its nixos forwards into the host's specialisation.
{ sven, lib, ... }:
{
  sven.kinds.host.spawns.variant = s: lib.filterAttrs (_: v: sven.lib.same v.of s) sven.variant;
  sven.kinds.variant = {
    fields.of = sven.kinds.host;
    sinks.nixos.nixos =
      { variant, nixos, ... }:
      {
        specialisation.${variant.name}.configuration.imports = nixos;
      };
  };
  sven.variant.debug.of = sven.host.lb;
  sven.aspects.debug-kernel = {
    at = sven.kinds.variant;
    nixos.boot.kernelParams = [ "debug" ];
  };
}
