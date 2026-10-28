# Ground Datalog with negation. A rule is { head; pos ? [ ]; neg ? [ ]; }: head holds when every pos atom holds and
# no neg atom holds. Atoms are strings; Nix grounds the rules (one rule per host, per user, … with map/concatMap).
# Semantics: the well-founded model (Van Gelder, Ross, Schlipf 1991), by the alternating fixpoint: three values,
# total, no strata needed. `stable` gives the stable models (Gelfond, Lifschitz 1988) for choice: 2^|undefined|.
# Builtins only.
let
  b = builtins;
  set = xs: b.listToAttrs (map (x: { name = x; value = true; }) xs);
  atomsOf = rules: b.attrNames (set (b.concatMap (r: [ r.head ] ++ r.pos or [ ] ++ r.neg or [ ]) rules));
  # least model of negation-free rules: a fixpoint, bounded by the number of rules
  lm = rules:
    let step = t: _: b.foldl' (t2: r: if t2 ? ${r.head} || !b.all (p: t2 ? ${p}) (r.pos or [ ]) then t2 else t2 // { ${r.head} = true; }) t rules;
    in b.foldl' step { } (b.genList (i: i) (b.length rules + 1));
  # Gelfond-Lifschitz reduct by the set i, then its least model
  gamma = rules: i: lm (b.filter (r: !b.any (n: i ? ${n}) (r.neg or [ ])) rules);
in
rec {
  wfs = rules:
    let
      atoms = atomsOf rules;
      t = b.foldl' (a: _: gamma rules (gamma rules a)) { } (b.genList (i: i) (b.length atoms + 1));   # lfp of gamma²
      g = gamma rules t;                                                                                 # what may hold
    in {
      true = b.filter (a: t ? ${a}) atoms;
      undefined = b.filter (a: g ? ${a} && !(t ? ${a})) atoms;
      false = b.filter (a: !(g ? ${a})) atoms;
      holds = a: t ? ${a};
    };
  # the stable models: the true atoms plus each subset of the undefined ones that reproduces itself
  stable = rules:
    let
      w = wfs rules;
      subsets = b.foldl' (acc: x: acc ++ map (s: s ++ [ x ]) acc) [ [ ] ] w.undefined;
      ok = m: let s = set m; in b.attrNames (gamma rules s) == b.attrNames s;
    in b.filter ok (map (s: b.sort b.lessThan (w.true ++ s)) subsets);
  # the rules that make an atom true in a model (one step of provenance)
  why = rules: model: atom: let t = set model.true; f = set model.false; in
    b.filter (r: r.head == atom && b.all (p: t ? ${p}) (r.pos or [ ]) && b.all (n: f ? ${n}) (r.neg or [ ])) rules;
  # proof tree of a true atom: its first supporting rule, recursively; a positive-support revisit is { cycle = true; };
  # a non-true atom is { status = "false" | "undefined"; }
  proof = rules: model: atom:
    let
      f = set model.false;
      go = seen: a:
        if !b.elem a model.true then { atom = a; status = if f ? ${a} then "false" else "undefined"; }
        else if b.elem a seen then { atom = a; cycle = true; }
        else
          let rs = why rules model a; in
          if rs == [ ] then { atom = a; rule = null; pos = [ ]; neg = [ ]; }
          else let r = b.head rs; in { atom = a; rule = r; pos = map (go (seen ++ [ a ])) (r.pos or [ ]); neg = r.neg or [ ]; };
    in go [ ] atom;
  # why an atom is not true: per rule with that head, the body atoms that stop it firing
  whyNot = rules: model: atom:
    let
      t = set model.true;
      u = set model.undefined;
      rs = b.filter (r: r.head == atom) rules;
    in
    if t ? ${atom} then [ ]
    else if rs == [ ] then [ { rule = null; reason = "no rule has this head"; } ]
    else map (r: {
      rule = r;
      missing = b.filter (p: !(t ? ${p})) (r.pos or [ ]);
      blocking = b.filter (n: t ? ${n}) (r.neg or [ ]);
      undefinedBody = b.filter (x: u ? ${x}) ((r.pos or [ ]) ++ (r.neg or [ ]));
    }) rs;
  # verdict on a pair of atoms (atomPos for, atomNeg against) in the well-founded model:
  #   "supported" atomPos true, atomNeg not true    "refuted" atomNeg true, atomPos not true
  #   "both"      both true                          "unknown" otherwise, if either is undefined
  #   "neither"   both false
  judge = rules: atomPos: atomNeg:
    let
      w = wfs rules;
      p = w.holds atomPos;
      n = w.holds atomNeg;
      und = a: b.elem a w.undefined;
    in
    if p && n then "both"
    else if p then "supported"
    else if n then "refuted"
    else if und atomPos || und atomNeg then "unknown"
    else "neither";
  # facts: atoms with no body
  facts = map (a: { head = a; });
}
