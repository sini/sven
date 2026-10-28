# Per-feature settings: two files declare types at two paths of one field. Cascade with delegation.
{ sven, lib, ... }:
let
  inherit (sven.lib) maybe opt;
  setting = path: h: sven.lib.cascade path ([ h ] ++ h.environment.delegates ++ [ h.environment ]); # local > delegated > parent
in
{
  sven.kinds.machine.fields.settings.zfs.arcMax = maybe lib.types.int;
  sven.kinds.environment.fields.settings.zfs.arcMax = maybe lib.types.int;
  sven.kinds.environment.fields.delegates = opt (sven.helpers.listOf sven.kinds.environment) [ ];
  sven.environment.prod.settings.zfs.arcMax = 4294967296;
  sven.environment.staging.delegates = [ sven.environment.prod ];
  sven.host.web-1.settings.zfs.arcMax = 8589934592;
  sven.aspects.zfs = {
    at = sven.kinds.host;
    nixos =
      { host, ... }:
      let
        m = setting [ "settings" "zfs" "arcMax" ] host;
      in
      {
        boot.kernelParams = lib.optional (m != null) "zfs.zfs_arc_max=${toString m}";
      };
  };
}
