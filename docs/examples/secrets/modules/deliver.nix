{ sven, lib, ... }:
{
  # each host gets the secrets that name it
  sven.aspects.deliver = {
    at = sven.kinds.host;
    cycle =
      { scope, ... }:
      {
        secrets = lib.attrValues (
          lib.filterAttrs (_: s: lib.any (sven.lib.same scope) s.owners) sven.secret
        );
      };
  };
  # a secret that no host owns is an error, not a silent leftover
  sven.aspects.orphans = {
    at = sven.kinds.fleet;
    errors = map (s: "secret ${s.name} (${s.file}) has no owner") (
      lib.filter (s: s.owners == [ ]) (lib.attrValues sven.secret)
    );
  };
}
