# machine is data only (nothing spawns it): host, guest and mac copy its fields.
{ sven, lib, ... }:
let
  inherit (sven.lib) maybe;
in
{
  sven.kinds.machine.fields = {
    environment = sven.kinds.environment;
    channel = sven.kinds.channel;
    system = sven.kinds.system;
    addr = lib.types.str;
    buildHost = maybe lib.types.str;
    settings.kernel.channel = maybe (sven.helpers.enum [ "lts" "latest" ]);
  };
}
