{ sven, ... }:
{
  sven.kinds.top = { spawns.host = _: sven.host; sinks.peers = { }; };
  sven.kinds.host = { sinks.nixos = { }; };
  sven.top.t = { };
  sven.host.web = { };
  sven.aspects.peer = { at = sven.kinds.host; peers = { host, ... }: host.name; };
}
