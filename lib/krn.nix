# krn: µKanren (Hemann, Friedman 2013) with constraints, in pure Nix. Builtins only.
#
# Terms: Nix values. A logic variable is { __lvar = n; }. Unification walks attrsets (same keys), Nix lists (same
# length) and scalars, with an occurs check. Relational lists are cons cells: `nil` and { head; tail; }, as in
# Scheme, so a list of unknown length can grow: `appendo` runs in every direction and enumerates without end.
#
# Constraints (miniKanren's =/= and cKanren's CLP(FD), Alvis et al. 2011):
#   neq u v        u and v never unify. Stored as the bindings that would make them equal; re-checked after each `eq`.
#   dom x [ ints ] x takes one of these integers. `infd xs lo hi` for a range.
#   lefd ltfd plusfd neqfd distinctfd   bounds propagation over domains, to a fixpoint after every change.
#   label xs       enumerate the values left in the domains (first-fail: the smallest domain first).
#
# A state is { s; c; neq; dom; fdc; }: substitution, next variable, disequality store, domains, FD propagators.
# A stream is null, { h = state; t = stream; } or a suspension { d = _: stream; }; suspensions interleave branches.
let
  b = builtins;
  isVar = x: b.isAttrs x && x ? __lvar;
  var = n: { __lvar = n; };
  isData = x: b.isAttrs x && !b.isFunction x && !(x ? __lvar);
  key = v: toString v.__lvar;
  walk = s: x: if isVar x && s ? ${key x} then walk s s.${key x} else x;
  occurs = s: v: x: let y = walk s x; in
    if isVar y then y.__lvar == v.__lvar
    else if b.isList y then b.any (occurs s v) y
    else if isData y then b.any (k: occurs s v y.${k}) (b.attrNames y)
    else false;
  ext = s: v: x: if occurs s v x then null else s // { ${key v} = x; };
  unify = s: u: v:
    let x = walk s u; y = walk s v; in
    if s == null then null
    else if isVar x && isVar y && x.__lvar == y.__lvar then s
    else if isVar x then ext s x y
    else if isVar y then ext s y x
    else if b.isList x && b.isList y then
      (if b.length x != b.length y then null else b.foldl' (acc: i: if acc == null then null else unify acc (b.elemAt x i) (b.elemAt y i)) s (b.genList (i: i) (b.length x)))
    else if isData x && isData y then
      (if b.attrNames x != b.attrNames y then null else b.foldl' (acc: k: if acc == null then null else unify acc x.${k} y.${k}) s (b.attrNames x))
    else if x == y then s else null;

  # ── constraint store ──
  andThen = st: f: if st == null then null else f st;
  # the bindings unify added: a disequality is violated exactly when all of them hold
  prefixOf = s: s2: removeAttrs s2 (b.attrNames s);
  recheckNeq = st: b.foldl' (acc: p: andThen acc (a:
    let s2 = b.foldl' (s: k: unify s (var (b.fromJSON k)) p.${k}) a.s (b.attrNames p); in
    if s2 == null then a                                  # can never be equal: drop it
    else let p2 = prefixOf a.s s2; in if p2 == { } then null else a // { neq = a.neq ++ [ p2 ]; }))
    (st // { neq = [ ]; }) st.neq;
  sortInts = b.sort b.lessThan;
  inter = d1: d2: b.filter (v: b.elem v d2) d1;
  # a variable's domain: [ v ] when it is bound to an integer, null when it has none
  domOf = st: x: let w = walk st.s x; in
    if b.isInt w then [ w ] else if isVar w then st.dom.${key w} or null else [ ];
  setDom = st: x: d: let w = walk st.s x; in
    if d == [ ] then null
    else if b.isInt w then (if b.elem w d then st else null)
    else if isVar w then
      (if b.length d == 1 then (let s2 = unify st.s w (b.head d); in if s2 == null then null else st // { s = s2; dom = removeAttrs st.dom [ (key w) ]; })
       else st // { dom = st.dom // { ${key w} = d; }; })
    else null;
  # bound variables leave the domain table; two domain variables unified meet
  recheckDom = st: b.foldl' (acc: n: andThen acc (a:
    if !(a.dom ? ${n}) then a else
    let d = a.dom.${n}; w = walk a.s (var (b.fromJSON n)); rest = a // { dom = removeAttrs a.dom [ n ]; }; in
    if b.isInt w then (if b.elem w d then rest else null)
    else if isVar w && key w != n then setDom rest w (if rest.dom ? ${key w} then inter d rest.dom.${key w} else d)
    else if isVar w then a else null)) st (b.attrNames st.dom);
  step = st: b.foldl' (acc: c: andThen acc c) (andThen (recheckNeq st) recheckDom) st.fdc;
  # run every check until nothing changes (bounded: each round removes a value or binds a variable)
  settle = st: let go = n: a: if a == null || n == 0 then a else let a2 = step a; in if a2 == null then null else if a2.s == a.s && a2.dom == a.dom && a2.neq == a.neq then a2 else go (n - 1) a2;
    in go 1000 st;
  unit = st: { h = st; t = null; };
  post = st: let r = settle st; in if r == null then null else unit r;

  mplus = s1: s2: if s1 == null then s2 else if s1 ? d then { d = _: mplus s2 (s1.d null); } else { h = s1.h; t = mplus s1.t s2; };
  bind = s: g: if s == null then null else if s ? d then { d = _: bind (s.d null) g; } else mplus (g s.h) (bind s.t g);
  take = n: s: if n == 0 || s == null then [ ] else if s ? d then take n (s.d null) else [ s.h ] ++ take (n - 1) s.t;
  takeAll = s: if s == null then [ ] else if s ? d then takeAll (s.d null) else [ s.h ] ++ takeAll s.t;
  goal = g: if b.isList g then conj g else g;
  conj = gs: st: b.foldl' (acc: g: bind acc (goal g)) (unit st) gs;

  walkStar = s: x: let y = walk s x; in
    if b.isList y then map (walkStar s) y else if isData y then b.mapAttrs (_: walkStar s) y else y;
  varsOf = x: if isVar x then [ x.__lvar ] else if b.isList x then b.concatMap varsOf x
    else if isData x then b.concatMap (k: varsOf x.${k}) (b.attrNames x) else [ ];
  namesFor = x: let vs = b.foldl' (acc: v: if b.elem v acc then acc else acc ++ [ v ]) [ ] (varsOf x); in
    b.listToAttrs (b.genList (i: { name = toString (b.elemAt vs i); value = "_.${toString i}"; }) (b.length vs));
  rename = names: y: if isVar y then names.${key y} or "_.?" else if b.isList y then map (rename names) y
    else if isData y then b.mapAttrs (_: rename names) y else y;
  reify = x: rename (namesFor x) x;
  start = f: goal (f (var 0)) { s = { }; c = 1; neq = [ ]; dom = { }; fdc = [ ]; };
  answer = st: reify (walkStar st.s (var 0));
  # the answer with the constraints left on its fresh variables
  answerC = st: let
    v = walkStar st.s (var 0); mine = n: (namesFor v) ? ${n};
    neqs = b.filter (p: b.all mine (b.attrNames p)) (map (p: b.mapAttrs (_: walkStar st.s) p) st.neq);
    names = namesFor [ v (map (p: map (k: [ (var (b.fromJSON k)) p.${k} ]) (b.attrNames p)) neqs) ];   # answer variables first, then the ones only constraints name
  in {
    value = rename names v;
    neq = map (p: map (k: [ names.${k} (rename names p.${k}) ]) (b.attrNames p)) neqs;
    dom = b.listToAttrs (map (n: { name = names.${n}; value = st.dom.${n}; }) (b.filter mine (b.attrNames st.dom)));
  };
in
rec {
  inherit var unify walkStar conj;
  eq = u: v: st: let s = unify st.s u v; in if s == null then null else post (st // { inherit s; });
  succeed = unit;
  fail = _: null;
  disj = gs: st: { d = _: b.foldl' (acc: g: mplus acc (goal g st)) null gs; };
  conde = clauses: disj (map conj clauses);
  # fresh ({ a, b }: goals): one variable per formal argument. freshNamed [ "x" "y" ] (vs: goals): names from data.
  fresh = f: freshNamed (b.attrNames (b.functionArgs f)) f;
  freshNamed = names: f: st: let
    vs = b.listToAttrs (b.genList (i: { name = b.elemAt names i; value = var (st.c + i); }) (b.length names));
  in goal (f vs) (st // { c = st.c + b.length names; });
  project = x: f: st: goal (f (walkStar st.s x)) st;

  # =/= : stored, so it holds whatever comes later
  neq = u: v: st: let s2 = unify st.s u v; in
    if s2 == null then unit st
    else let p = prefixOf st.s s2; in if p == { } then null else unit (st // { neq = st.neq ++ [ p ]; });

  # finite domains
  dom = x: ds: st: let cur = domOf st x; d = sortInts ds; in andThen (setDom st x (if cur == null then d else inter d cur)) post;
  infd = xs: lo: hi: conj (map (x: dom x (b.genList (i: lo + i) (hi - lo + 1))) xs);
  propagator = c: st: andThen (c (st // { fdc = st.fdc ++ [ c ]; })) post;
  fdBound = st: xs: f: let ds = map (domOf st) xs; in if b.any (d: d == null) ds then st else f ds;
  minOf = d: b.head d;
  maxOf = d: b.elemAt d (b.length d - 1);
  lefd = x: y: propagator (st: fdBound st [ x y ] (ds: let dx = b.elemAt ds 0; dy = b.elemAt ds 1; in
    andThen (setDom st x (b.filter (v: v <= maxOf dy) dx)) (st2: setDom st2 y (b.filter (v: v >= minOf dx) dy))));
  ltfd = x: y: propagator (st: fdBound st [ x y ] (ds: let dx = b.elemAt ds 0; dy = b.elemAt ds 1; in
    andThen (setDom st x (b.filter (v: v < maxOf dy) dx)) (st2: setDom st2 y (b.filter (v: v > minOf dx) dy))));
  plusfd = x: y: z: propagator (st: fdBound st [ x y z ] (ds: let dx = b.elemAt ds 0; dy = b.elemAt ds 1; dz = b.elemAt ds 2; in
    andThen (setDom st z (b.filter (v: v >= minOf dx + minOf dy && v <= maxOf dx + maxOf dy) dz)) (s1:
    andThen (setDom s1 x (b.filter (v: v >= minOf dz - maxOf dy && v <= maxOf dz - minOf dy) dx)) (s2:
    setDom s2 y (b.filter (v: v >= minOf dz - maxOf dx && v <= maxOf dz - minOf dx) dy)))));
  neqfd = x: y: propagator (st: fdBound st [ x y ] (ds: let dx = b.elemAt ds 0; dy = b.elemAt ds 1; in
    if b.length dx == 1 && b.length dy == 1 then (if dx == dy then null else st)
    else if b.length dx == 1 then setDom st y (b.filter (v: v != b.head dx) dy)
    else if b.length dy == 1 then setDom st x (b.filter (v: v != b.head dy) dx)
    else st));
  distinctfd = xs: conj (b.concatLists (b.genList (i: map (y: neqfd (b.elemAt xs i) y) (b.genList (j: b.elemAt xs (i + j + 1)) (b.length xs - i - 1))) (b.length xs)));
  # enumerate: the variable with the smallest domain first; a variable with no domain stays as it is
  label = xs: st: let
    open = b.filter (x: let d = domOf st x; in d != null && b.length d > 1) xs;
    pick = b.foldl' (a: x: if a == null || b.length (domOf st x) < b.length (domOf st a) then x else a) null open;
  in if open == [ ] then unit st else (disj (map (v: [ (eq pick v) (label xs) ]) (domOf st pick))) st;

  run = n: f: map answer (take n (start f));
  runAll = f: map answer (takeAll (start f));       # finite searches only
  # with the constraints left on the answer: { value; neq; dom; }
  runC = n: f: map answerC (take n (start f));

  # relational lists: nil and cons cells
  nil = null;
  cons = h: t: { head = h; tail = t; };
  fromList = xs: b.foldl' (acc: x: cons x acc) nil (b.genList (i: b.elemAt xs (b.length xs - 1 - i)) (b.length xs));
  toList = l: if l == null then [ ] else if isData l && l ? head then [ l.head ] ++ toList l.tail else [ l ];
  # l ++ s == out, in every direction (a list of unknown length enumerates without end)
  appendo = l: s: out: conde [
    [ (eq l nil) (eq s out) ]
    [ (fresh ({ a, d, r }: [ (eq l (cons a d)) (eq out (cons a r)) (appendo d s r) ])) ]
  ];
  # x is in the list l: a Nix list (known) or a cons list (relational)
  membero = x: l: st: let w = walk st.s l; in (if b.isList w then disj (map (y: eq x y) w) else conde [
    [ (fresh ({ d }: eq l (cons x d))) ]
    [ (fresh ({ a, d }: [ (eq l (cons a d)) (membero x d) ])) ]
  ]) st;
  # a table: each row is a fact; the pattern unifies with a row (records or tuples)
  facto = rows: pattern: disj (map (r: eq pattern r) rows);
}
