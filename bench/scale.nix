# Scale probe: N modules. Each module declares one aspect; aspects target hosts by a field and give two sinks.
# 1 fleet, 10 environments, N/10 hosts, 2 users per host. Run:
#   nix-instantiate --eval --strict bench/scale.nix --arg n 1000 -A probe
{
  n ? 100,
  hostCount ? null,
}:
let
  b = builtins;
  sven = (import ../default.nix).lib;
  hosts = if hostCount == null then n / 10 else hostCount;
  base =
    { sven, ... }:
    {
      sven.kinds.fleet = {
        spawns.env = _: sven.env;
        sinks.out.reduce = sven.lib.reduce.merge;
      };
      sven.kinds.env.spawns.host =
        s:
        b.listToAttrs (
          b.filter (x: x.value.env == s.name) (
            b.attrValues (
              b.mapAttrs (k: v: {
                name = k;
                value = v;
              }) sven.host
            )
          )
        );
      sven.kinds.host = {
        fields = {
          env = sven.lib.is b.isString;
          tier = sven.lib.is b.isInt;
        };
        spawns.user = _: {
          u1 = { };
          u2 = { };
        };
        sinks = {
          nixos = { };
          persist.reduce = sven.lib.reduce.set;
        };
      };
      sven.kinds.user = { };
      sven.fleet.main = { };
      sven.env = b.listToAttrs (
        b.genList (i: {
          name = "e${toString i}";
          value = { };
        }) 10
      );
      sven.host = b.listToAttrs (
        b.genList (i: {
          name = "h${toString i}";
          value = {
            env = "e${toString (i - i / 10 * 10)}";
            tier = i - i / 7 * 7;
          };
        }) hosts
      );
    };
  aspect =
    i:
    { sven, ... }:
    {
      sven.aspects."a${toString i}" = {
        at = s: s.kind == "host" && s.tier == i - i / 7 * 7;
        nixos =
          { host, ... }:
          {
            environment.etc."a${toString i}".text = host.name;
          };
        persist = "/var/lib/a${toString (i - i / 50 * 50)}";
      };
    };
  r = sven.eval { imports = [ base ] ++ b.genList aspect n; };
in
{
  inherit r;
  probe = {
    scopes = b.length r.scopes;
    errors = b.length r.errors;
    nixosElems = b.foldl' (a: x: a + b.length x) 0 (b.attrValues r.reduced.nixos);
    persist = b.length (r.reduced.persist."fleet:main/env:e0/host:h0");
  };
}
