# Aspects at guests. None of this reaches the host's own system: an element goes to its nearest `nixos` sink.
{ sven, ... }:
{
  sven.aspects.guest-base = {
    at = sven.kinds.guest;
    nixos =
      { guest, ... }:
      {
        networking.hostName = guest.name;
        system.stateVersion = "25.05";
      };
  };
  sven.aspects.nginx = {
    at = sven.guest.web;
    nixos.services.nginx.enable = true;
  };
  sven.aspects.postgres = {
    at = sven.guest.db;
    nixos.services.postgresql.enable = true;
  };
}
