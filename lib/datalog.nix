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
  # facts: atoms with no body
  facts = map (a: { head = a; });
}
