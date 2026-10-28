{ sven, ... }:
{
  sven.aspects.web.nixos.networking.firewall.allowedTCPPorts = [ 80 ];   # the agent touches the same aspect
  sven.aspects.cache = { at = sven.kinds.host; nixos.services.redis.servers.a.enable = true; };
}
