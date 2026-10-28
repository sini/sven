# krn: µKanren (Hemann, Friedman 2013) in pure Nix. Logic variables, unification over Nix values (attrsets with
# the same keys, lists of the same length, scalars), goals that run forward and backward, interleaving search.
# Builtins only.
#
#   run 3 (q: fresh ({ a, b }: [ (appendo a b [ 1 2 ]) (eq q [ a b ]) ]))
#   # => [ [ [ ] [ 1 2 ] ] [ [ 1 ] [ 2 ] ] [ [ 1 2 ] [ ] ] ]
#
# A goal is a function from a state { s; c; } (substitution, next variable number) to a stream: null (empty),
# { h = state; t = stream; }, or a suspension { d = _: stream; }. Suspensions let infinite branches interleave.
# A goal list means conjunction. Lists are fixed-length Nix lists, not cons cells: a relation over a list of
# unknown length (appendo) needs the whole list or both parts known.
let
  b = builtins;
  isVar = x: b.isAttrs x && x ? __lvar;
  var = n: { __lvar = n; };
  isData = x: b.isAttrs x && !b.isFunction x && !(x ? __lvar);
  walk = s: x: if isVar x && s ? ${toString x.__lvar} then walk s s.${toString x.__lvar} else x;
  occurs = s: v: x: let y = walk s x; in
    if isVar y then y.__lvar == v.__lvar
    else if b.isList y then b.any (occurs s v) y
    else if isData y then b.any (k: occurs s v y.${k}) (b.attrNames y)
    else false;
  ext = s: v: x: if occurs s v x then null else s // { ${toString v.__lvar} = x; };
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

  mplus = s1: s2: if s1 == null then s2 else if s1 ? d then { d = _: mplus s2 (s1.d null); } else { h = s1.h; t = mplus s1.t s2; };
  bind = s: g: if s == null then null else if s ? d then { d = _: bind (s.d null) g; } else mplus (g s.h) (bind s.t g);
  take = n: s: if n == 0 || s == null then [ ] else if s ? d then take n (s.d null) else [ s.h ] ++ take (n - 1) s.t;
  takeAll = s: if s == null then [ ] else if s ? d then takeAll (s.d null) else [ s.h ] ++ takeAll s.t;
  unit = st: { h = st; t = null; };
  goal = g: if b.isList g then conj g else g;
  conj = gs: st: b.foldl' (acc: g: bind acc (goal g)) (unit st) gs;

  walkStar = s: x: let y = walk s x; in
    if b.isList y then map (walkStar s) y else if isData y then b.mapAttrs (_: walkStar s) y else y;
  varsOf = x: if isVar x then [ x.__lvar ] else if b.isList x then b.concatMap varsOf x
    else if isData x then b.concatMap (k: varsOf x.${k}) (b.attrNames x) else [ ];
  ground = x: varsOf x == [ ];
  # fresh variables print as _.0, _.1, … in order of appearance
  reify = x: let
    vs = b.foldl' (acc: v: if b.elem v acc then acc else acc ++ [ v ]) [ ] (varsOf x);
    names = b.listToAttrs (b.genList (i: { name = toString (b.elemAt vs i); value = "_.${toString i}"; }) (b.length vs));
    go = y: if isVar y then names.${toString y.__lvar} else if b.isList y then map go y else if isData y then b.mapAttrs (_: go) y else y;
  in go x;
  start = f: goal (f (var 0)) { s = { }; c = 1; };
  answer = st: reify (walkStar st.s (var 0));
in
rec {
  inherit var unify walkStar conj;
  eq = u: v: st: let s = unify st.s u v; in if s == null then null else unit (st // { inherit s; });
  succeed = unit;
  fail = _: null;
  # disj: any goal; each branch is suspended, so recursive relations interleave instead of looping
  disj = gs: st: { d = _: b.foldl' (acc: g: mplus acc (goal g st)) null gs; };
  conde = clauses: disj (map conj clauses);
  # fresh ({ a, b }: goals): one new variable per formal argument
  fresh = f: st: let
    ns = b.attrNames (b.functionArgs f);
    vs = b.listToAttrs (b.genList (i: { name = b.elemAt ns i; value = var (st.c + i); }) (b.length ns));
  in goal (f vs) (st // { c = st.c + b.length ns; });
  # freshNamed [ "grafana" "loki" ] (vs: goals): variables named by data, as an attrset
  freshNamed = names: f: st: let
    vs = b.listToAttrs (b.genList (i: { name = b.elemAt names i; value = var (st.c + i); }) (b.length names));
  in goal (f vs) (st // { c = st.c + b.length names; });
  # read a term's current value to build a goal (non-relational: use it on terms that earlier goals ground)
  project = x: f: st: goal (f (walkStar st.s x)) st;
  # x differs from y: decided once both are ground (no constraint store), so place it after the goals that ground them
  neq = u: v: st: let x = walkStar st.s u; y = walkStar st.s v; in if ground x && ground y && x == y then null else unit st;

  run = n: f: map answer (take n (start f));
  runAll = f: map answer (takeAll (start f));   # finite searches only

  # x is an element of the list l (l known)
  membero = x: l: project l (w: if b.isList w then disj (map (y: eq x y) w) else fail);
  # l ++ s == out, with out known (every split) or l and s known (their concatenation)
  appendo = l: s: out: project [ l s out ] (w: let L = b.elemAt w 0; S = b.elemAt w 1; O = b.elemAt w 2; n = b.length O; in
    if b.isList O && ground O then disj (b.genList (i: [ (eq l (b.genList (j: b.elemAt O j) i)) (eq s (b.genList (j: b.elemAt O (i + j)) (n - i))) ]) (n + 1))
    else if b.isList L && b.isList S then eq out (L ++ S)
    else fail);
  # a table: each row is a fact; the pattern unifies with a row (records or tuples)
  facto = rows: pattern: disj (map (r: eq pattern r) rows);
}
