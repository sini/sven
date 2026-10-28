{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.environment.fields.domain = lib.types.str;
  sven.kinds.host = {
    fields.environment = sven.kinds.environment;
    sinks.services = { };
  };
  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
