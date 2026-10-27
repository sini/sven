# sven.nix: builtins only. A query language for configurations: a Cycle.js loop over nested scopes.
# No throws: an error is an emission. No merge, no module system: every read is a query on the files that answer it.
# Entry: `(import ./sven.nix).lib.eval module`. A module is a path, a function or an attrset; `imports` nest, `_module.args` flow down.
let
  b = builtins;
  inherit (b) all any attrNames concatMap concatStringsSep elem filter foldl' functionArgs genericClosure groupBy
    head intersectAttrs isAttrs isFunction isList isPath isString length listToAttrs mapAttrs;

  # ── tiny helpers (no nixpkgs) ──
  toList = v: if isList v then v else [ v ];
  reverse = xs: b.genList (i: b.elemAt xs (length xs - 1 - i)) (length xs);
  first = p: xs: foldl' (a: x: if a != null then a else if p x then x else null) null xs;
  uniq = foldl' (acc: x: if elem x acc then acc else acc ++ [ x ]) [ ];
  names = xs: attrNames (listToAttrs (map (n: { name = n; value = null; }) xs));
  uniqueBy = key: xs: map (i: i.x) (genericClosure { startSet = map (x: { key = key x; inherit x; }) xs; operator = _: [ ]; });
  err = from: msg: { error = msg; inherit from; };
  isLeaf = v: !isAttrs v || v ? check || v ? __kind || v ? __functor || (v.type or null) == "derivation";
  isType = t: isAttrs t && (t ? check || t ? __kind);
  checkOf = t: if t ? __kind then (v: isAttrs v && (v.kind or null) == t.__kind) else t.check;
  get = path: v: foldl' (r: n: if r ? ok && isAttrs r.ok && !isLeaf r.ok && r.ok ? ${n} then { ok = r.ok.${n}; } else { }) { ok = v; } path;
  attrsIn = xs: concatMap (x: if isAttrs x && !isLeaf x then attrNames x else [ ]) xs;

  # ── reduce strategies: elements in, { value; errors; } out ──
  mergeAt = path: a: bv:
    let
      common = filter (n: a ? ${n}) (attrNames bv);
      sub = n: if isLeaf a.${n} || isLeaf bv.${n}
        then { value = a.${n}; errors = if a.${n} == bv.${n} then [ ] else [ (err "merge" "merge conflict at ${concatStringsSep "." (path ++ [ n ])}") ]; }
        else mergeAt (path ++ [ n ]) a.${n} bv.${n};
    in { value = a // mapAttrs (n: v: if a ? ${n} then (sub n).value else v) bv; errors = concatMap (n: (sub n).errors) common; };
  reduce = {
    list = es: { value = map (e: e.value) es; errors = [ ]; };
    set = es: { value = uniq (map (e: e.value) es); errors = [ ]; };
    one = es: { value = if es == [ ] then null else (head es).value; errors = if length es == 1 then [ ] else [ (err "one" "one: got ${toString (length es)} elements") ]; };
    merge = es: foldl' (acc: e: let m = mergeAt [ ] acc.value e.value; in { value = m.value; errors = acc.errors ++ m.errors; }) { value = { }; errors = [ ]; } es;
    entries = es: { value = es; errors = [ ]; };
  };
  static = {
    inherit reduce;
    is = check: { inherit check; };                                   # any check is a type: `sven.lib.is builtins.isString`
    opt = t: d: t // { default = d; };
    maybe = t: { check = v: v == null || checkOf t v; default = null; };
  };

  eval = root:
    let
      # ── load: imports are nested modules; `_module.args` flow down to them, like sources ──
      node = args: key: m:
        let
          f = if isPath m || isString m then import m else m;
          fa = if isFunction f then functionArgs f else { };
          missing = filter (a: !fa.${a} && !(args ? ${a})) (attrNames fa);
          v = if isFunction f then f (intersectAttrs fa args) else f;
          k = if isPath m || isString m then toString m else key;
        in
        { key = k; } // (if missing != [ ] then { error = "module ${k}: arg `${head missing}` has no answer"; }
          else { mod = v; args = args // (v._module.args or { }) // { inherit sven; }; });
      loaded = genericClosure {
        startSet = [ (node { inherit sven; } "root" root) ];
        operator = n: let imps = n.mod.imports or [ ]; in
          if n ? mod then b.genList (i: node n.args "${n.key}/${toString i}" (b.elemAt imps i)) (length imps) else [ ];
      };
      defs = map (n: n.mod.sven or { }) (filter (n: n ? mod) loaded);
      loadErrors = map (n: err "module" n.error) (filter (n: n ? error) loaded);

      # ── declarations: queries on the files, in file order. A leaf is the first answer; `at` is all answers ──
      answers = path: concatMap (d: let r = get path d; in if r ? ok then [ r.ok ] else [ ]) defs;
      atKey = path: path != [ ] && b.elemAt path (length path - 1) == "at";
      decl = path: let hs = answers path; in
        if atKey path then concatMap toList hs
        else if hs == [ ] then null
        else if isAttrs (head hs) && !isLeaf (head hs) then listToAttrs (map (n: { name = n; value = decl (path ++ [ n ]); }) (names (attrsIn hs)))
        else head hs;
      declErrors = path: let hs = answers path; in
        if atKey path || length hs < 2 then [ ]
        else if all (x: isAttrs x && !isLeaf x) hs then concatMap (n: declErrors (path ++ [ n ])) (names (attrsIn hs))
        else if all (x: x == head hs) hs then [ ]
        else [ (err "declarations" "two answers for ${concatStringsSep "." path}") ];
      top = decl [ ];
      kindNames = attrNames (top.kinds or { });
      aspectNames = attrNames (top.aspects or { });
      kinds = listToAttrs (map (k: { name = k; value = top.kinds.${k} // { __kind = k; check = v: isAttrs v && (v.kind or null) == k; }; }) kindNames);   # a kind is a type: its instances pass
      aspects = listToAttrs (map (n: { name = n; value = top.aspects.${n} // { __aspect = n; }; }) aspectNames);

      # ── instance data: typed paths. Answers first, then the type defaults; a failed check reads as null ──
      typesAt = k: path: answers ([ "kinds" k "fields" ] ++ path);
      dataAt = k: n: path: let hits = answers ([ k n ] ++ path); d = first (t: isAttrs t && t ? default) (typesAt k path); in
        if hits != [ ] then { ok = head hits; } else if d != null then { ok = d.default; } else { };
      view = k: n: path:
        let ts = typesAt k path; tys = filter isType ts; r = dataAt k n path; in
        if tys != [ ] then (if r ? ok && all (t: checkOf t r.ok) tys then r.ok else null)
        else if path != [ ] && ts == [ ] then null
        else listToAttrs (map (f: { name = f; value = view k n (path ++ [ f ]); }) (names (attrsIn (answers ([ k n ] ++ path) ++ ts))));
      instErrors = k: n: path:
        let ts = typesAt k path; tys = filter isType ts; r = dataAt k n path; id = "${k}:${n}"; p = concatStringsSep "." path; in
        if tys != [ ] then (if !(r ? ok) then [ (err id "missing ${p}") ] else if all (t: checkOf t r.ok) tys then [ ]
          else [ (err id (let kr = first (t: t ? __kind) tys; in if kr != null then "${p} wants a ${kr.__kind} ref" else "${p} fails its check")) ])
        else if path != [ ] && ts == [ ] then [ (err id "unknown field ${p}") ]
        else concatMap (f: instErrors k n (path ++ [ f ])) (names (attrsIn (answers ([ k n ] ++ path) ++ ts)));
      instNames = k: attrNames (top.${k} or { });
      instances = mapAttrs (k: _: listToAttrs (map (n: { name = n; value = view k n [ ] // { kind = k; name = n; }; }) (instNames k))) kinds;
      sven = instances // { inherit kinds aspects lib; helpers = top.helpers or { }; };

      # ── the scope tree: nested cycles. key = what the parent spawned; identity = keys from the root ──
      mkScope = parent: kind: name: inst:
        let
          key = "${kind}:${name}";
          path = (if parent == null then [ ] else parent.path) ++ [ key ];
          s = inst // { inherit kind name key parent path; id = concatStringsSep "/" path; up = (if parent == null then [ ] else parent.up) ++ [ s ]; };
        in s;
      spawnsOf = k: kinds.${k}.spawns or { };
      spawned = concatMap (k: attrNames (spawnsOf k)) kindNames;
      roots = concatMap (k: map (n: mkScope null k n instances.${k}.${n}) (instNames k)) (filter (k: kinds.${k} ? spawns && !elem k spawned) kindNames);
      childrenOf = s: concatMap (c: let made = (spawnsOf s.kind).${c} s; in
        if !isAttrs made then [ (err s.id "spawns.${c} gives no attrset") ]
        else map (n: if any (x: x.key == "${c}:${n}") s.up then err s.id "instance ${c}:${n} twice on path"
          else if !isAttrs made.${n} then err s.id "spawns.${c}.${n} is no attrset" else mkScope s c n made.${n}) (attrNames made))
        (attrNames (spawnsOf s.kind));
      tree = genericClosure {                                         # C-level loop, breadth first: a parent comes before its children
        startSet = map (s: { key = s.id; inherit s; }) roots;
        operator = i: if i ? s then map (c: if c ? error then { key = "error:${c.from}:${c.error}"; e = c; } else { key = c.id; s = c; }) (childrenOf i.s) else [ ];
      };
      unsorted = map (i: i.s) (filter (i: i ? s) tree);
      treeErrors = map (i: i.e) (filter (i: i ? e) tree);
      byParent = groupBy (s: if s.parent == null then "" else s.parent.id) unsorted;

      # ── filter: every predicate is a function; refs and lists become functions ──
      holds = p: s:
        if isList p then any (q: holds q s) p
        else if isFunction p || p ? __functor then p s
        else if p ? __kind then s.kind == p.__kind
        else if p ? __aspect then active.${p.__aspect}.${s.id} or false
        else p ? kind && p ? name && s.kind == p.kind && s.name == p.name;
      active = mapAttrs (_: a: listToAttrs (map (s: { name = s.id; value = holds (a.at or [ ]) s; }) unsorted)) aspects;

      # ── components: one cycle per (aspect, scope). Its own tree requests feed its sources ──
      cycleOuts = mapAttrs (n: a: listToAttrs (map (s: { name = s.id; value = let o = a.cycle (sourcesAt s (o.tree or [ ])); in o; })
        (filter (s: active.${n}.${s.id}) unsorted))) (b.removeAttrs aspects (filter (n: !(aspects.${n} ? cycle)) aspectNames));
      outAt = n: s: cycleOuts.${n}.${s.id} or { };

      # ── order: a sink every scope has; first answer, else 0. Siblings sort by (order, key); a parent sorts first ──
      ordersAt = s: concatMap (n: if !active.${n}.${s.id} then [ ] else toList (aspects.${n}.order or [ ]) ++ toList ((outAt n s).order or [ ])) aspectNames;
      orderOf = s: let os = filter (o: b.isInt o || b.isFloat o) (ordersAt s); in if os == [ ] then 0 else head os;
      orderErrors = concatMap (s: if all (o: b.isInt o || b.isFloat o) (ordersAt s) then [ ] else [ (err s.id "order is not a number") ]) unsorted;
      sortKeys = listToAttrs (map (s: { name = s.id; value = (if s.parent == null then [ ] else sortKeys.${s.parent.id}) ++ [ [ (orderOf s) s.key ] ]; }) unsorted);
      scopes = b.seq (foldl' (_: s: sortKeys.${s.id}) null unsorted)  # force keys breadth first: no deep thunk chain
        (b.sort (x: y: sortKeys.${x.id} < sortKeys.${y.id}) unsorted);
      childrenAt = groupBy (s: if s.parent == null then "" else s.parent.id) scopes;

      # ── routing: nearest ancestor-or-self receiver (Cycle isolateSink tags the identity) ──
      sinkOf = s: k: (kinds.${s.kind}.sinks or { }).${k} or null;
      sinkKeys = d: filter (k: !elem k [ "at" "reduce" "of" ]) (attrNames d);
      sinkNames = uniq (concatMap (k: attrNames (k.sinks or { })) (b.attrValues kinds));
      nearestFirst = s: reverse s.up;
      above = s: if s.parent == null then [ ] else reverse s.parent.up;
      receiverIn = k: first (r: sinkOf r k != null && holds ((sinkOf r k).at or (_: true)) r);
      given = concatMap (s: concatMap (n: let a = aspects.${n}; o = outAt n s; in
          if !active.${n}.${s.id} then [ ]
          else map (k: { origin = "aspect ${n}"; key = k; from = s; value = a.${k}; }) (filter (k: !elem k [ "at" "cycle" "order" "__aspect" ]) (attrNames a))
            ++ concatMap (k: map (v: { origin = "aspect ${n}"; key = k; from = s; value = v; raw = true; }) (toList o.${k}))
              (filter (k: !elem k [ "tree" "order" ]) (attrNames o))) aspectNames) scopes;
      direct = concatMap (e: let to = receiverIn e.key (nearestFirst e.from); in if to == null then [ ] else [ (e // { inherit to; }) ])
        (filter (e: e.key != "errors") given);                       # nobody reads it: nothing happens
      fired = genericClosure {                                        # which (sink, receiver) pairs fire: existence only
        startSet = map (e: { key = "${e.key}@${e.to.id}"; sink = e.key; r = e.to; }) direct;
        operator = f: concatMap (k: let t = receiverIn k (if k == f.sink then above f.r else nearestFirst f.r); in
          if t == null then [ ] else [ { key = "${k}@${t.id}"; sink = k; r = t; } ]) (sinkKeys (sinkOf f.r f.sink));
      };
      fromSinks = concatMap (f: let d = sinkOf f.r f.sink; in concatMap (k: let to = receiverIn k (if k == f.sink then above f.r else nearestFirst f.r); in
        if to == null then [ ] else [ { origin = "sink ${f.sink}"; key = k; from = f.r; inherit to; value = d.${k}; } ]) (sinkKeys d)) fired;
      routed = direct ++ fromSinks;
      byTo = groupBy (e: "${e.key}@${e.to.id}") routed;

      # ── sources at a scope (Cycle isolateSource): the tree driver and one source per sink ──
      isRen = n: n == "scope" || n == "tree" || kinds ? ${n} || elem n sinkNames;
      nearest = k: s: first (x: x.kind == k) (nearestFirst s);
      answer = s: q:
        if q ? nearest then (let x = nearest q.nearest.__kind s; in if x == null then err s.id "no ${q.nearest.__kind} above" else { ok = x; })
        else if q ? parent then (if s.parent == null then err s.id "no parent" else { ok = s.parent; })
        else if q ? children then { ok = filter (holds q.children) (childrenAt.${s.id} or [ ]); }
        else if q ? scopesOf then { ok = filter (x: x.kind == q.scopesOf.kind && x.name == q.scopesOf.name) scopes; }
        else if q ? holds then { ok = holds q.holds s; }
        else err s.id "unknown tree request";
      sourcesAt = s: requests: { scope = s; tree.select = c: concatMap (q: let r = answer s q; in if q.category or null == c && r ? ok then [ r.ok ] else [ ]) requests; }
        // listToAttrs (map (n: { name = n; value = let r = receiverIn n (nearestFirst s); in if r == null then [ ] else [ (reduceAt n r).value ]; }) sinkNames);
      requestErrors = concatMap (s: concatMap (n: map (_: err s.id "aspect ${n}: unknown tree request")
        (filter (q: !(q ? nearest || q ? parent || q ? children || q ? scopesOf || q ? holds)) (toList ((outAt n s).tree or [ ])))) (attrNames cycleOuts)) unsorted;

      # ── map: fill the args sven answers; other args stay open (`__functionArgs`) ──
      argAt = s: n:
        if n == "scope" then [ s ]
        else if kinds ? ${n} then (let x = nearest n s; in if x == null then [ ] else [ x ])
        else (sourcesAt s [ ]).${n} or [ ];
      isAttrsFn = f: b.match ".*<attrspat.*" (b.toXML f) != null;
      fill = s: v:
        if !isFunction v then { ok = v; }
        else if !isAttrsFn v then err s.id "bare function: wrap it as `{ ... }:`"
        else
          let
            fa = functionArgs v;
            mine = filter isRen (attrNames fa);
            asked = listToAttrs (map (n: { name = n; value = argAt s n; }) mine);
            missing = filter (n: asked.${n} == [ ] && !fa.${n}) mine;
            got = listToAttrs (concatMap (n: if asked.${n} == [ ] then [ ] else [ { name = n; value = head asked.${n}; } ]) mine);
            rest = b.removeAttrs fa mine;
          in
          if missing != [ ] then err s.id "arg `${head missing}` has no answer"   # Cycle: no source, no emission
          else if rest == { } then { ok = v got; }
          else { ok = { __functor = _: m: v (m // got); __functionArgs = rest; }; };

      # ── the drivers ──
      idOf = e: if !isFunction e.value then "${e.origin}|${toString (e.raw or false)}|${e.from.id}"
        else "${e.origin}|" + concatStringsSep "," (map (n: if n == "scope" then e.from.id else if kinds ? ${n} then ((nearest n e.from).id or "") else "") (attrNames (functionArgs e.value)));
      reduceAt = k: r:
        let
          d = sinkOf r k;
          es = uniqueBy (e: "${idOf e}@${r.id}") (byTo."${k}@${r.id}" or [ ]);
          filled = map (e: fill e.from e.value // { inherit e; }) es;
          okOf = x: x ? ok && (!(d ? of) || checkOf d.of x.ok);
          red = (d.reduce or reduce.list) (map (x: { from = x.e.from; value = x.ok; }) (filter okOf filled));
          bad = map (x: if x ? error then err x.from "${x.e.origin}: ${x.error}" else err r.id "sink ${k}: element of ${x.e.origin} from ${x.e.from.id} fails `of`") (filter (x: !okOf x) filled);
        in { value = red.value; errors = bad ++ red.errors; };
      emitted = concatMap (e: let x = fill e.from e.value; in if x ? ok then map (m: err e.from.id m) (toList x.ok) else [ (err x.from "${e.origin}: ${x.error}") ])
        (filter (e: e.key == "errors") given);

      # ── run: sinks feed drivers, drivers feed sources, Nix laziness closes the loop. Every output is a query ──
      receivers = k: filter (s: byTo ? "${k}@${s.id}") scopes;
      reduced = listToAttrs (map (k: { name = k; value = listToAttrs (map (r: { name = r.id; value = (reduceAt k r).value; }) (receivers k)); }) sinkNames);
      reduceErrors = concatMap (k: concatMap (r: (reduceAt k r).errors) (receivers k)) sinkNames;
      lib = static // {
        inherit holds;
        all = ps: s: all (p: holds p s) ps;
        not = p: s: !holds p s;
        within = p: s: any (holds p) (above s);
        has = p: s: any (holds p) (byParent.${s.id} or [ ]);
        same = x: y: x.kind == y.kind && x.name == y.name;
        nearest = k: nearest k.__kind;
        scopesOf = x: filter (s: s.kind == x.kind && s.name == x.name) scopes;
        cascade = path: foldl' (a: x: if a != null then a else (get path x).ok or null) null;   # first answer along a list of scopes
      };
    in
    {
      inherit scopes active reduced;
      errors = loadErrors ++ declErrors [ ] ++ concatMap (k: concatMap (n: instErrors k n [ ]) (instNames k)) kindNames
        ++ treeErrors ++ orderErrors ++ requestErrors ++ reduceErrors ++ emitted;
      graph = { scopes = map (s: { inherit (s) id kind name; }) scopes; edges = map (e: { sink = e.key; from = e.from.id; to = e.to.id; }) routed; };
      flake = if top ? flake && scopes != [ ] then (fill (head scopes) top.flake).ok or null else null;
    };
in
{ lib = static // { inherit eval; mkFlake = m: (eval m).flake; }; }
