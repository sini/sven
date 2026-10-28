# fleet > environment > host. The fleet says which day it is: pure evaluation has no clock.
{ sven, lib, ... }:
let
  inherit (sven.lib) same maybe;
in
{
  sven.kinds.fleet = {
    fields.today = lib.types.str;
    spawns.environment = _: sven.environment;
    sinks.out.reduce = sven.lib.reduce.merge;
    sinks.dns.out = { dns, ... }: { inherit dns; };
  };
  sven.kinds.environment = {
    spawns.host = s: lib.filterAttrs (_: h: same h.environment s && sven.lib.validAt sven.fleet.main.today h) sven.host;
    sinks.backends.dns = { environment, backends, ... }: { ${environment.name} = backends; };
  };
  sven.kinds.host.fields = {
    environment = sven.kinds.environment;
    validFrom = maybe lib.types.str; # null: open, valid since always
    validTo = maybe lib.types.str; # null: open, valid until always
  };

  sven.fleet.main.today = "2026-11-15";
  sven.environment.prod = { };
  sven.host.web-old = { environment = sven.environment.prod; validTo = "2026-10-31"; }; # retired
  sven.host.web = { environment = sven.environment.prod; validFrom = "2026-10-01"; };
  sven.host.web-next = { environment = sven.environment.prod; validFrom = "2026-12-01"; }; # not yet
  sven.flake = { out, ... }: out;
}
