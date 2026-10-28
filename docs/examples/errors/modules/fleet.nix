{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
    sinks.warnings.out = { warnings, ... }: { inherit warnings; }; # messages that do not fail the fleet
  };
  sven.kinds.host.fields = { addr = lib.types.str; backup = sven.lib.opt lib.types.bool true; };

  sven.fleet.main = { };
  sven.host.web.addr = "10.0.0.1";
  sven.host.db.addr = "10.0.0.1";
  sven.host.scratch = { addr = "10.0.0.9"; backup = false; };
  sven.flake = { out, ... }: out;
}
