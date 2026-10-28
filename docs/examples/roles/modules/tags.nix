# Tags from active roles: `sven.lib.holds` asks an aspect at a scope. A deploy tool can read them.
{ sven, lib, ... }:
{
  sven.aspects.tags = {
    at = sven.kinds.host;
    out = { host, scope, ... }: {
      tags.${host.name} = lib.filter (r: sven.lib.holds sven.aspects.${r} scope) [ "server" "workstation" "laptop" "nvidia" "ci-runner" "gaming" "backups" ];
    };
  };
}
