# A sink collects elements and reduces them. `of` checks each element.
{ sven, lib, ... }:
let
  inherit (sven.lib.reduce)
    list
    set
    one
    merge
    entries
    ;
  sorted = es: {
    value = lib.sort (a: b: a < b) (map (e: e.value) es);
    errors = [ ];
  }; # your own reduce
in
{
  sven.kinds.host.sinks = {
    motd = {
      reduce = list;
      of = lib.types.str;
    };
    ports = {
      reduce = set;
      of = lib.types.port;
    };
    admin.reduce = one;
    nginx.reduce = merge;
    owners.reduce = entries;
    groups.reduce = sorted;
  };
  # every sink of a host, read as args, to one flake output
  sven.aspects.report = {
    at = sven.kinds.host;
    out =
      {
        host,
        motd,
        ports,
        admin,
        nginx,
        owners,
        groups,
        ...
      }:
      {
        ${host.name} = {
          inherit
            motd
            ports
            admin
            nginx
            groups
            ;
          owners = map (e: e.from.kind) owners;
        };
      };
  };
}
