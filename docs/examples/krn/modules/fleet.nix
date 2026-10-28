{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.fields.apps = sven.lib.is (v: lib.isList v && lib.all lib.isString v);

  sven.fleet.main = { };
  sven.host.lb.apps = [
    "grafana"
    "loki"
    "prometheus"
  ];
  sven.flake = { out, ... }: out;
}
