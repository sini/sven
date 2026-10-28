{ sven, lib, ... }:
let
  inherit (sven.lib) opt is;
in
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.fields = {
    web = opt lib.types.bool false;
    maintenance = opt lib.types.bool false;
    dependsOn = opt (is lib.isList) [ ];
  };

  sven.fleet.main = { };
  sven.host.db-1 = { };
  sven.host.db-2.maintenance = true;
  sven.host.web-1 = {
    web = true;
    dependsOn = [ sven.host.db-1 ];
  };
  sven.host.web-2 = {
    web = true;
    dependsOn = [ sven.host.db-2 ];
  };
  sven.flake = { out, ... }: out;
}
