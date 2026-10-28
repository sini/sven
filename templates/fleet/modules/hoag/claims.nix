# den-hoag productions: claim / provide with the reverse read (who claims me). Apps claim databases; the database host
# reads every claim aimed at it and provides them; each app reads its provider's answer. Data that points both ways is two
# facts, not a cycle: laziness, no strata.
{ sven, lib, ... }:
let
  inherit (sven.lib) same;
in
{
  sven.kinds.machine.fields.dbOn = sven.lib.maybe sven.kinds.host;
  sven.host.web-1.dbOn = sven.host.lb;
  sven.host.web-2.dbOn = sven.host.lb;
  sven.host.stage.dbOn = sven.host.stage;
  sven.kinds.fleet.sinks.db-claims.reduce = sven.lib.reduce.entries;
  sven.aspects.db-claim = {
    at = sven.lib.all [
      sven.kinds.host
      (s: s.dbOn != null && !s.minimal)
    ];
    db-claims =
      { host, ... }:
      {
        db = "app_${lib.replaceStrings [ "-" ] [ "_" ] host.name}";
        on = host.dbOn;
      };
  };
  sven.aspects.db-provide = {
    at = sven.lib.all [
      sven.kinds.host
      (s: !s.minimal)
    ];
    nixos =
      { host, db-claims, ... }:
      let
        mine = lib.filter (e: same e.value.on host) db-claims;
      in
      # the reverse read: who claims me
      lib.optionalAttrs (mine != [ ]) {
        services.postgresql = {
          enable = true;
          ensureDatabases = map (e: e.value.db) mine;
        };
      };
  };
  sven.aspects.db-client = {
    at = sven.lib.all [
      sven.kinds.host
      (s: s.dbOn != null && !s.minimal)
    ];
    nixos =
      { host, ... }:
      {
        environment.etc."app/database-url".text = "postgres://${host.dbOn.addr}/app_${
          lib.replaceStrings [ "-" ] [ "_" ] host.name
        }";
      };
  };
}
