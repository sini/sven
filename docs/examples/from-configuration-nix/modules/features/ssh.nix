{ sven, ... }:
{
  sven.aspects.ssh = {
    at = sven.kinds.host;
    nixos.services.openssh.enable = true;
  };
}
