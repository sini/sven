{ sven, ... }:
{
  sven.kinds.top = {
    spawns.host = _: sven.host;
  };
  sven.kinds.host.sinks.nixos = { };
  sven.top.t = { };
  sven.host.h = { };
  sven.aspects.web = {
    at = sven.kinds.host;
    nixos.services.nginx.enable = true;
  };
  sven.labels = {
    "modules/" = {
      trust = 3;
    };
    "agent/" = {
      trust = 1;
    };
  };
}
