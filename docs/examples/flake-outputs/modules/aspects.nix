{ sven, lib, ... }:
{
  sven.aspects.nginx = {
    at = sven.host.web;
    services = "nginx";
  };
  sven.aspects.postgres = {
    at = sven.host.db;
    services = "postgres";
  };
  # the `out` arg: an element reads the flake outputs, lazily. No `inputs.self`.
  sven.aspects.inventory = {
    at = sven.kinds.fleet;
    out =
      { out, ... }:
      {
        inventory = lib.concatLists (lib.attrValues out.services);
      };
  };
}
