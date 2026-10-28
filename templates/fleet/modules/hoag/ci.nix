# den-hoag CI capabilities, each as plain data and plain Nix: merge strategies with provenance, setting refs,
# claim dedup, negation over claims, a composite claim split by a sink stage, a demand cascade as spawns,
# a shadowing query, and a suppression chain as `at` predicates.
{ sven, lib, ... }:
let
  inherit (sven.lib) all not same opt;
  inherit (sven.lib.reduce) entries;
  hosts = lib.filterAttrs (_: h: h ? addr) sven.host;

  # a discipline is a reduce: per key, the first layer that names a strategy decides it ("replace" when none);
  # a value { ref = k; } reads the final value of key k. Provenance lists every layer that set the key.
  strategies = es:
    let
      sorted = lib.sort (a: b: a.value.rank < b.value.rank) es;
      keys = lib.unique (lib.concatMap (e: lib.attrNames e.value.set) sorted);
      layersOf = k: lib.filter (e: e.value.set ? ${k}) sorted;
      strategy = k: lib.findFirst (s: s != null) "replace" (map (e: e.value.strategy.${k} or null) sorted);
      raw = lib.genAttrs keys (k: if strategy k == "append" then lib.concatMap (e: e.value.set.${k}) (layersOf k) else (lib.last (layersOf k)).value.set.${k});
    in {
      value = {
        value = lib.mapAttrs (_: v: if lib.isAttrs v && v ? ref then raw.${v.ref} else v) raw;
        provenance = lib.genAttrs keys (k: map (e: { from = e.from.id; inherit (e.value) rank; }) (layersOf k));
      };
      errors = [ ];
    };

  # the nearest host along `via` that has a motd; equal distance: the first in `order`
  visible = order: start:
    let
      reach = builtins.genericClosure { startSet = [ { key = start; d = 0; } ]; operator = x: map (m: { key = m.name; d = x.d + 1; }) (hosts.${x.key}.via or [ ]); };
      found = lib.filter (x: hosts.${x.key}.motd != null) reach;
      rank = n: lib.lists.findFirstIndex (o: o == n) (lib.length order) order;
      best = lib.foldl' (a: x: if a == null || x.d < a.d || x.d == a.d && rank x.key < rank a.key then x else a) null found;
    in if best == null then null else hosts.${best.key}.motd;
in
{
  # H18 + H19: strategies, provenance, ref
  sven.kinds.host.sinks.tuning.reduce = strategies;
  sven.aspects.tuning-base = { at = sven.kinds.host; tuning = { rank = 0; set = { ports = [ 22 ]; color = "grey"; accent.ref = "color"; }; strategy.ports = "append"; }; };
  sven.aspects.tuning-env = { at = all [ sven.kinds.host (sven.lib.within sven.environment.prod) ]; tuning = { rank = 1; set.ports = [ 80 ]; }; };
  sven.aspects.tuning-lb = { at = sven.host.lb; tuning = { rank = 2; set = { ports = [ 443 ]; color = "blue"; }; }; };

  # H71: two claimants of one token give one node with sorted sharers
  sven.kinds.machine.fields.tokens = opt (sven.helpers.listOf lib.types.str) [ ];
  sven.host.web-2.tokens = [ "apitoken" ];
  sven.host.web-1.tokens = [ "apitoken" "metrics" ];
  sven.kinds.fleet.sinks.token-claims.reduce = es: {
    value = lib.mapAttrs (_: xs: { sharers = lib.sort (a: b: a < b) (map (x: x.from.name) xs); })
      (lib.groupBy (x: x.token) (lib.concatMap (e: map (t: { token = t; inherit (e) from; }) e.value) es));
    errors = [ ];
  };
  sven.aspects.token-claim = { at = all [ sven.kinds.host (s: s.tokens != [ ]) ]; token-claims = { host, ... }: host.tokens; };

  # H72: lockdown keeps root claimants (nobody depends on them) and drops self-claims
  sven.aspects.db-lockdown = {
    at = all [ sven.kinds.host (s: !s.minimal) ];
    nixos = { host, db-claims, ... }: {
      environment.etc."db/lockdown".text = toString (map (e: e.from.name) (lib.filter (e: same e.value.on host && !same e.from host
        && !lib.any (h: lib.any (same e.from) h.dependsOn) (lib.attrValues hosts)) db-claims));
    };
  };

  # H73: a route claim is split into a secret claim and a connect claim by sink stages
  sven.kinds.fleet.sinks = {
    route-claims = {
      reduce = entries;
      secret-claims = { route-claims, ... }: lib.listToAttrs (map (e: lib.nameValuePair e.value { by = e.from.name; }) route-claims);
      connect-claims = { route-claims, ... }: lib.listToAttrs (map (e: lib.nameValuePair e.value { by = e.from.name; }) route-claims);
    };
    secret-claims.reduce = sven.lib.reduce.merge;
    connect-claims.reduce = sven.lib.reduce.merge;
  };
  sven.aspects.api-route = { at = sven.host.web-1; route-claims = "api"; };

  # H74: a demand cascades into structure: one database per demand, each with a secret and a connect below it
  sven.kinds.machine.fields.demands = opt (sven.helpers.listOf lib.types.str) [ ];
  sven.host.web-1.demands = [ "orders" "users" ];
  sven.host.web-2.demands = [ "orders" "audit" ];
  sven.kinds.fleet.spawns.database = _: lib.genAttrs (lib.concatMap (h: h.demands) (lib.attrValues hosts)) (n: { by = map (h: h.name) (lib.filter (h: lib.elem n h.demands) (lib.attrValues hosts)); });
  sven.kinds.database.spawns = { secret = s: { "${s.name}-pw" = { }; }; connect = s: { "${s.name}-url" = { }; }; };

  # H76: a query with shadowing: the nearer path wins, the label order breaks ties
  sven.kinds.machine.fields = { via = opt (sven.helpers.listOf sven.kinds.host) [ ]; motd = sven.lib.maybe lib.types.str; };
  sven.host.stage.via = [ sven.host.web-1 sven.host.web-2 ];
  sven.host.web-1 = { via = [ sven.host.lb ]; motd = "w1"; };
  sven.host.web-2.motd = "w2";
  sven.host.lb.motd = "lb";
  sven.aspects.visible-motd = { at = sven.fleet.main; out = { ... }: { visibleMotd = { a = visible [ "lb" "web-1" "web-2" ] "stage"; b = visible [ "web-2" "web-1" ] "stage"; w = visible [ ] "web-1"; }; }; };

  # H99: suppression chain: a suppresses b, b suppresses c, c suppresses d
  sven.aspects.sup-a.at = sven.host.lb;
  sven.aspects.sup-b.at = all [ sven.host.lb (not sven.aspects.sup-a) ];
  sven.aspects.sup-c.at = all [ sven.host.lb (not sven.aspects.sup-b) ];
  sven.aspects.sup-d.at = all [ sven.host.lb (not sven.aspects.sup-c) ];
}
