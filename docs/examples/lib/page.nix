{
  title = "Library index";
  description = "Every function of sven.lib, and every query of an eval result. Generated from the engine.";
  section = "reference";
  order = 1;

  body = { docs, engine, ... }:
    let
      code = xs: builtins.concatStringsSep ", " (map (x: "`${x}`") xs);
      # sven.lib as modules see it. A root kind needs `spawns`: `top` spawns `leaf`
      inner = (engine.eval ({ sven, ... }: { sven.kinds.top.spawns.leaf = _: { }; sven.kinds.leaf = { }; sven.top.t = { }; sven.flake = { ... }: builtins.attrNames sven.lib; })).flake;
      r = engine.eval { sven.kinds.top = { }; sven.top.t = { }; };
      outer = builtins.attrNames engine;
      sub = [ "reduce" "graphs" "datalog" "krn" "rdf" "program" "grants" "change" ];
    in [
      ''
        This page is computed from the engine when the docs are written. A function added to sven appears here
        without a docs edit.

        ## Outside a fleet: `(import sven).lib`
      ''
      (code (builtins.filter (n: !builtins.elem n sub) outer))
      ''
        ## Inside a fleet: `sven.lib`

        Modules get the same lib, plus predicates and queries bound to the fleet:
      ''
      (code (builtins.filter (n: !builtins.elem n outer) inner))
      ''
        ## Libraries
      ''
      (docs.table [ "Library" "Functions" ] (map (n: [ "`sven.lib.${n}`" (code (builtins.attrNames engine.${n})) ]) sub))
      ''
        ## Queries of an eval result: `r = sven.lib.eval module`
      ''
      (code (builtins.attrNames r))
      (docs.links [
        { title = "Queries"; href = "/query/queries/"; description = "What each query answers."; }
        { title = "Error codes"; href = "/reference/errors/"; description = "Every error record sven can give."; }
      ])
    ];

  checks = { engine, ... }: {
    has-eval = engine ? eval && engine ? stage && engine.reduce ? entries;
    inner = builtins.elem "holds" (engine.eval ({ sven, ... }: { sven.kinds.top.spawns.leaf = _: { }; sven.kinds.leaf = { }; sven.top.t = { }; sven.flake = { ... }: builtins.attrNames sven.lib; })).flake;
  };
}
