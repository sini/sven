{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.fields.dependsOn = sven.lib.opt (sven.lib.is lib.isList) [ ]; # host refs

  sven.fleet.main = { };
  sven.host.db = { };
  sven.host.cache = { };
  sven.host.api = {
    dependsOn = [
      sven.host.db
      sven.host.cache
    ];
  };
  sven.host.web = {
    dependsOn = [ sven.host.api ];
  };
  sven.host.lb = {
    dependsOn = [ sven.host.web ];
  };
  sven.flake = { out, ... }: out;
}
