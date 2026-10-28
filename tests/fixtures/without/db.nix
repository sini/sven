{ sven, ... }:
{
  sven.host.db = { };
  sven.aspects.postgres = { at = sven.host.db; nixos.services.postgresql.enable = true; };
}
