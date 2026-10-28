# sven oracles. Run: nix-instantiate --eval --strict vic/tests -A failed   (expect [ ])
let
  sven = (import ../default.nix).lib;
  b = builtins;
  msgs = r: map (e: e.error) r.errors;
  has = r: m: b.elem m (msgs r);

  # the design §1 fleet; nixosSystem replaced by the module list
  fleet = extra: { sven, ... }: {
    sven.kinds.fleet = { spawns.host = _: sven.host; sinks.out.reduce = sven.lib.reduce.merge; };
    sven.kinds.host = {
      fields.addr = sven.lib.is b.isString;
      sinks.persist.reduce = sven.lib.reduce.set;
      sinks.nixos.out = { host, nixos, ... }: { nixosConfigurations.${host.name} = nixos; };
    };
    sven.fleet.main = { };
    sven.host.lb = extra;
    sven.aspects.motd = {
      at = sven.kinds.host;
      persist = "/var/lib/motd";
      nixos = { persist, ... }: { environment.etc.motd.text = b.concatStringsSep "\n" persist; };
    };
    sven.flake = { out, ... }: out;
  };
  good = sven.eval (fleet { addr = "10.0.1.1"; });
  noAddr = sven.eval (fleet { });

  # §4: two feature files, types at two paths of one field; no merge
  settings = [
    ({ sven, ... }: { sven.kinds.host.fields.settings.zfs.arcMax = sven.lib.maybe (sven.lib.is b.isInt); })
    ({ sven, ... }: { sven.kinds.host.fields.settings.k3s.role = sven.lib.opt (sven.lib.is b.isString) "agent"; })
  ];
  feat = data: sven.eval { imports = [ (fleet ({ addr = "a"; } // data)) ] ++ settings; };
  featLazy = sven.eval { imports = [ (fleet { addr = "a"; }) ({ sven, ... }: { sven.kinds.host.fields.settings.lazy = sven.lib.opt (sven.lib.is b.isString) (throw "touched"); }) ] ++ settings; };
  hostOf = r: b.head (b.filter (s: s.kind == "host") r.scopes);

  # §5: order is a sink; siblings by (order, key), parent first
  ordered = o: sven.eval ({ sven, ... }: {
    sven.kinds.fleet.spawns.host = _: sven.host;
    sven.kinds.host = { };
    sven.fleet.main = { };
    sven.host = { a = { }; b = { }; c = { }; };
    sven.aspects.c-first = { at = sven.host.c; order = o; };
  });
  ids = r: map (s: s.id) r.scopes;

  # Q5: an arg nobody answers; the component may emit on `errors`
  q5 = arg: sven.eval ({ sven, ... }: {
    imports = [ (fleet { addr = "a"; }) ];
    sven.kinds.cluster = { };
    sven.aspects.k3s = { at = sven.kinds.host; nixos = arg; };
    sven.aspects.warn = { at = sven.kinds.host; cycle = { tree, ... }: {
      tree = [ { category = "c"; nearest = sven.kinds.cluster; } ];
      errors = if tree.select "c" == [ ] then [ "no cluster: k3s off" ] else [ ];
    }; };
  });

  # imports nest; `_module.args` flow down to them
  argsDown = sven.eval { _module.args.greeting = "hi"; imports = [ { imports = [ ({ sven, greeting, ... }: { imports = [ (fleet { addr = greeting; }) ]; }) ]; } ]; };
  argsMissing = sven.eval { imports = [ ({ nope, ... }: { }) ]; };

  # stack safety: a chain 3000 deep, a fan-out of 3000
  deep = n: sven.eval ({ sven, ... }: {
    sven.kinds.node.spawns.node = s: let i = b.fromJSON (b.substring 5 9 s.key); in if i < n then { "${toString (i + 1)}" = { }; } else { };
    sven.kinds.top.spawns.node = _: { "0" = { }; };
    sven.top.t = { };
  });
  wide = n: sven.eval ({ sven, ... }: {
    sven.kinds.root.spawns.leaf = _: b.listToAttrs (b.genList (i: { name = toString i; value = { }; }) n);
    sven.kinds.leaf = { };
    sven.root.r = { };
  });

  # tree driver, positive: a node reads its nearest cluster
  treeHit = sven.eval ({ sven, ... }: {
    sven.kinds.top.spawns.cluster = _: sven.cluster;
    sven.kinds.cluster.spawns.node = _: { n1 = { }; };
    sven.kinds.node.sinks.seen = { };
    sven.top.t = { };
    sven.cluster.c1 = { };
    sven.aspects.see = { at = sven.kinds.node; cycle = { tree, ... }: {
      tree = [ { category = "c"; nearest = sven.kinds.cluster; } ];
      seen = map (c: c.name) (tree.select "c");
    }; };
  });
  # structure from presence (Den #525): a child exists only where an aspect holds at its parent
  presence = sven.eval ({ sven, ... }: {
    sven.kinds.top.spawns.host = _: sven.host;
    sven.kinds.host.spawns.svc = p: if sven.lib.holds sven.aspects.server p then { web = { }; } else { };
    sven.kinds.svc = { };
    sven.top.t = { };
    sven.host = { a = { }; b = { }; };
    sven.aspects.server.at = sven.host.a;
  });
  # Den CI gaps closed: derived defaults, bad `at`, one key from many files, static once per receiver
  gaps = sven.eval ({ sven, ... }: {
    imports = [ { sven.aspects.multi.nixos = { scope, ... }: [ "a-${scope.name}" ]; } { sven.aspects.multi.nixos = { scope, ... }: [ "b-${scope.name}" ]; } ];
    sven.kinds.fleet = { spawns.host = _: sven.host; };
    sven.kinds.host = {
      fields.vpn = sven.lib.derive (sven.lib.is b.isString) (self: "vpn-${self.name}");
      spawns.user = _: { u1 = { }; u2 = { }; };
      sinks.nixos = { };
    };
    sven.kinds.user = { };
    sven.fleet.main = { };
    sven.host = { h1 = { }; h2.vpn = "custom"; };
    sven.aspects.multi.at = sven.kinds.host;
    sven.aspects.shared = { at = [ sven.kinds.host sven.kinds.user ]; nixos = "marker"; };
    sven.aspects.typo.at = "host";
  });
  checks = {
    good-no-errors = msgs good == [ ];
    good-persist = good.reduced.persist."fleet:main/host:lb" == [ "/var/lib/motd" ];
    good-flake = good.flake.nixosConfigurations.lb == [ { environment.etc.motd.text = "/var/lib/motd"; } ];
    neg-missing-addr = has noAddr "missing addr";
    neg-missing-addr-no-flake-break = noAddr.reduced.persist."fleet:main/host:lb" == [ "/var/lib/motd" ];
    neg-unknown-field = has (sven.eval (fleet { addr = "a"; adr = "b"; })) "unknown field adr";
    neg-bad-check = has (sven.eval (fleet { addr = 1; })) "addr fails its check";
    bad-check-reads-null = (hostOf (sven.eval (fleet { addr = 1; }))).addr == null;
    two-answers = has (sven.eval { imports = [ (fleet { addr = "a"; }) { sven.host.lb.addr = "b"; } ]; }) "two answers for host.lb.addr";
    same-answer-twice-ok = msgs (sven.eval { imports = [ (fleet { addr = "a"; }) { sven.host.lb.addr = "a"; } ]; }) == [ ];
    settings-value = (hostOf (feat { settings.zfs.arcMax = 8; })).settings.zfs.arcMax == 8;
    settings-default = (hostOf (feat { })).settings.k3s.role == "agent";
    settings-maybe-null = (hostOf (feat { })).settings.zfs.arcMax == null;
    settings-lazy = (hostOf featLazy).settings.k3s.role == "agent";   # reading zfs never forces settings.lazy's default
    settings-unknown = has (feat { settings.zfz = 1; }) "unknown field settings.zfz";
    order-default = ids (ordered 0) == [ "fleet:main" "fleet:main/host:a" "fleet:main/host:b" "fleet:main/host:c" ];
    order-first = ids (ordered (-1)) == [ "fleet:main" "fleet:main/host:c" "fleet:main/host:a" "fleet:main/host:b" ];
    order-bad = has (ordered "x") "order is not a number";
    q5-required = has (q5 ({ cluster, ... }: { })) "aspect k3s: arg `cluster` has no answer";
    q5-optional = !(b.any (m: b.match ".*arg `cluster`.*" m != null) (msgs (q5 ({ cluster ? null, ... }: { }))));
    q5-emitted = has (q5 ({ cluster ? null, ... }: { })) "no cluster: k3s off";
    cycle-many-elements = (sven.eval ({ sven, ... }: { sven.kinds.top = { spawns = { }; sinks.many.reduce = sven.lib.reduce.list; }; sven.top.t = { }; sven.aspects.m = { at = sven.kinds.top; cycle = _: { many = [ "a" "b" "c" ]; }; }; })).reduced.many."top:t" == [ "a" "b" "c" ];
    tree-nearest = treeHit.reduced.seen."top:t/cluster:c1/node:n1" or null == [ "c1" ] && map (e: e.error) treeHit.errors == [ ];
    unread-sink-no-error = msgs (sven.eval { imports = [ (fleet { addr = "a"; }) { sven.aspects.motd.nixso = { }; } ]; }) == [ ];
    args-flow-down = (hostOf argsDown).addr == "hi" && msgs argsDown == [ ];
    args-missing = has argsMissing "module root/0: arg `nope` has no answer";
    presence-spawns = ids presence == [ "top:t" "top:t/host:a" "top:t/host:a/svc:web" "top:t/host:b" ] && msgs presence == [ ];
    gap-derived-default = (b.head (b.filter (s: s.name == "h1") gaps.scopes)).vpn == "vpn-h1" && (b.head (b.filter (s: s.name == "h2") gaps.scopes)).vpn == "custom";
    gap-multi-file-functions = gaps.reduced.nixos."fleet:main/host:h1" == [ [ "a-h1" ] [ "b-h1" ] "marker" ] && !(has gaps "two answers for aspects.multi.nixos");
    gap-static-once-per-receiver = b.length (b.filter (v: v == "marker") gaps.reduced.nixos."fleet:main/host:h1") == 1;
    gap-bad-at = has gaps "`at` holds a string, not a predicate";
    graph-edges = b.elem { sink = "persist"; from = "fleet:main/host:lb"; to = "fleet:main/host:lb"; origin = "aspect motd"; } good.graph.edges;
    deep-1000 = b.length (deep 1000).scopes == 1002;
    wide-3000 = b.length (wide 3000).scopes == 3001;
  };
in
{
  inherit checks;
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
