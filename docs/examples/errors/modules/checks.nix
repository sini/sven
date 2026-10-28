# An aspect key `errors` gives error records, or plain messages. Nothing throws. `from` is always the giving scope.
{ sven, lib, ... }:
let
  byAddr = lib.groupBy (h: h.addr) (lib.attrValues sven.host);
in
{
  sven.aspects.unique-addr = {
    at = sven.kinds.fleet;
    errors = lib.concatLists (lib.mapAttrsToList (a: hs: lib.optional (lib.length hs > 1) {
      code = "duplicate-addr";
      error = "${a} is the address of ${lib.concatMapStringsSep " and " (h: h.name) hs}";
      fix = "give each host its own addr";
      path = [ "addr" ];
      got = a;
    }) byAddr);
  };
  sven.aspects.no-backup = {
    at = sven.lib.all [ sven.kinds.host (s: !s.backup) ];
    warnings = { host, ... }: "${host.name} has no backup";
  };
}
