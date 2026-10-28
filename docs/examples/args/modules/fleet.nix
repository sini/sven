{ sven, lib, ... }:
let
  under = s: lib.filterAttrs (_: h: sven.lib.same h.environment s) sven.host;
in
{
  sven.kinds.fleet = {
    spawns.environment = _: sven.environment;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.environment = {
    spawns.host = under;
    sinks.backends = { }; # hosts give their address; a wall: it stays at the environment
  };
  sven.kinds.host = {
    fields = {
      environment = sven.kinds.environment;
      addr = lib.types.str;
    };
    sinks.proxy.out =
      { host, proxy, ... }:
      {
        proxy.${host.name} = proxy;
      };
  };

  sven.kinds.cluster.fields = { }; # a kind that no scope here is under

  sven.fleet.main = { };
  sven.environment.prod = { };
  sven.host.lb = {
    environment = sven.environment.prod;
    addr = "10.0.0.1";
  };
  sven.host.web-1 = {
    environment = sven.environment.prod;
    addr = "10.0.0.2";
  };
  sven.host.web-2 = {
    environment = sven.environment.prod;
    addr = "10.0.0.3";
  };
  sven.flake = { out, ... }: out;
}
