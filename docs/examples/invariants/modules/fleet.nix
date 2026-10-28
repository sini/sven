{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.fields = {
    addr = lib.types.str;
    form = lib.types.enum [ "server" "laptop" ];
  };

  sven.fleet.main = { };
  sven.host.web = { addr = "10.0.0.1"; form = "server"; };
  sven.host.db = { addr = "10.0.0.2"; form = "server"; };
  sven.host.thinkpad = { addr = "10.0.0.50"; form = "laptop"; };
  sven.aspects.desktop.at = s: (s.form or null) == "laptop";
  sven.aspects.postgres.at = sven.host.db;
  sven.flake = { out, ... }: out;
}
