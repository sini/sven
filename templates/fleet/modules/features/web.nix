# The diamond: nginx is reached directly and through `status` (web-1, stage). It lands once per scope.
{ sven, lib, ... }:
{
  sven.aspects.nginx = {
    at = [
      sven.host.web-1
      sven.host.web-2
      sven.host.stage
      sven.aspects.status
    ];
    nixos.services.nginx.enable = true;
    backends = { host, ... }: host.addr; # goes up to the environment
    persist = "/var/lib/nginx";
    tags = "web";
  };
  sven.aspects.status = {
    at = [
      sven.host.web-1
      sven.host.stage
    ];
    nixos.services.nginx.virtualHosts.status.locations."/".return = "200 ok";
  };
  sven.aspects.http-port = {
    at = sven.aspects.nginx;
    nixos.networking.firewall.allowedTCPPorts = [ 80 ];
  };
  sven.aspects.haproxy = {
    at = sven.host.lb;
    nixos =
      { backends, ... }:
      {
        services.haproxy.enable = true;
        services.haproxy.config = lib.concatMapStrings (a: "  server ${a} ${a}:80 check\n") backends;
      };
  };
  sven.aspects.desktop = {
    at = sven.host.stage;
    nixos.services.xserver.enable = true;
  };
  sven.aspects.dock = {
    at = sven.kinds.mac;
    darwin.system.defaults.dock.autohide = true;
  };
  sven.aspects.docker = {
    at = sven.lib.all [
      sven.helpers.linux
      (sven.lib.has sven.user.bob)
    ];
    nixos.virtualisation.docker.enable = true;
    persist = "/var/lib/docker";
  };
}
