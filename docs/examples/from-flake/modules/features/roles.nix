{ sven, ... }:
{
  sven.aspects.nginx = {
    at = sven.host.web;
    nixos = {
      services.nginx.enable = true;
      networking.firewall.allowedTCPPorts = [ 80 ];
    };
  };
  sven.aspects.printing = {
    at = sven.host.desk;
    nixos.services.printing.enable = true;
  };
}
