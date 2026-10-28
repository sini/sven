# sven shacl oracles. Run: nix-instantiate --eval --strict tests/shacl.nix -A failed   (expect [ ])
let
  sven = (import ../default.nix).lib;
  rdf = sven.rdf;
  b = builtins;

  fix =
    { sven, ... }:
    {
      sven.kinds.fleet = {
        spawns.host = _: sven.host;
      };
      sven.kinds.host = {
        fields = {
          port = sven.lib.is b.isInt;
          rack = sven.kinds.fleet;
        };
      };
      sven.fleet.main = { };
      sven.host.web = {
        port = 80;
        rack = sven.fleet.main;
      };
    };
  fleet = ms: sven.eval { imports = ms; };
  r = fleet [ fix ];
  r2 = fleet [ fix ];
  rRev = fleet (
    b.genList (
      i:
      b.elemAt [
        fix
        (
          { sven, ... }:
          {
            sven.host.db.port = 1;
          }
        )
      ] (1 - i)
    ) 2
  );
  rFwd = fleet [
    (
      { sven, ... }:
      {
        sven.host.db.port = 1;
      }
    )
    fix
  ];

  ttl = rdf.shacl r;
  tr = rdf.triples r;
  has = s: l: b.any (x: x == s) l;
  contains = needle: s: b.match ".*${needle}.*" s != null;
  shapeCount =
    s:
    b.length (
      b.filter (x: x == "a sh:NodeShape ;" || b.match ".* a sh:NodeShape ;" x != null) (
        b.filter b.isString (b.split "\n" s)
      )
    );
  f = "<https://sven.dev/fleet/";
in
rec {
  checks = {
    node-shape-per-spawned-kind =
      shapeCount ttl == 2
      && contains "kind/host> a sh:NodeShape" ttl
      && contains "kind/fleet> a sh:NodeShape" ttl;
    no-shape-for-kind-without-scopes =
      !(contains "kind/ghost>" (
        rdf.shacl (fleet [
          fix
          (
            { sven, ... }:
            {
              sven.kinds.ghost = { };
            }
          )
        ])
      ));
    ref-field-has-class = contains "field/rack> ; sh:maxCount 1 ; sh:class ${f}kind/fleet>" ttl;
    int-field-no-class = contains "field/port> ; sh:maxCount 1 ; . ;" ttl;
    parent-class-from-spawner = contains "sven/parent> ; sh:class ${f}kind/fleet>" ttl;
    int-triple-typed = has "${f}scope/fleet:main/host:web> ${f}field/port> \"80\"^^<http://www.w3.org/2001/XMLSchema#integer> ." tr;
    ref-triple-iri = has "${f}scope/fleet:main/host:web> ${f}field/rack> ${f}instance/fleet/main> ." tr;
    no-engine-key-triples = !(b.any (x: contains "field/(kind|name|key|parent|path|id|up|rup)>" x) tr);
    deterministic-two-evals = ttl == rdf.shacl r2 && tr == rdf.triples r2;
    stable-under-module-order =
      rdf.shacl rRev == rdf.shacl rFwd && rdf.triples rRev == rdf.triples rFwd;
  };
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
