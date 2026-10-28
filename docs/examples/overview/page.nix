{
  title = "Overview";
  description = "What sven is, in four words: kinds, scopes, aspects, sinks.";
  section = "start";
  order = 1;

  body = { docs, r, ... }: [
    ''
      sven is a query language for Nix configurations. You declare data and behavior in plain Nix files.
      sven answers queries on them: the systems to build, the errors, and the graph of who gives what to whom.

      sven is one small Nix file. It uses Nix builtins only: no nixpkgs, no module system, no flakes.
      It never calls `throw`. An error is data that you can query.
    ''
    (docs.cards [
      { title = "Kinds"; icon = "seti:json"; body = "Typed data. A `host`, a `user`, an `environment`: you declare what exists and which fields it has."; }
      { title = "Scopes"; icon = "list-format"; body = "Where things live. `spawns` places each instance in a tree: a user under a host, a host under an environment."; }
      { title = "Aspects"; icon = "puzzle"; body = "Behavior. An aspect is active where its `at` predicate holds, and gives elements by key."; }
      { title = "Sinks"; icon = "random"; body = "Where elements go. An element goes up to the nearest scope that collects it, and the sink reduces them."; }
    ])
    ''
      ## The four words in one example

      This example has no NixOS. An office has two machines. Each machine collects a set of package names.

      **Kinds and scopes.** `office` is the root kind, because nothing spawns it. It spawns every machine.
      A machine has an `owner` field and a `packages` sink.
    ''
    (docs.file "modules/kinds.nix")
    ''
      **Aspects.** `basics` is active at every machine. `design` is active at `studio` only.
      `versioned-assets` is active wherever `design` is active: an aspect can be a predicate.
    ''
    (docs.file "modules/aspects.nix")
    ''
      **Sinks.** Each aspect key gives one element to the sink of that name. The `packages` sink of each machine
      reduces its elements with `set`, so `git` arrives twice at `studio` and stays once:
    ''
    (docs.value r.reduced.packages)
    ''
      The scope tree and the routed elements, drawn from `r.graph`:
    ''
    (docs.tabs [
      { label = "Scopes"; body = docs.scopes r; }
      { label = "Routed elements"; body = docs.routes r; }
    ])
    ''
      ## Data is queried, not merged

      There is no `evalModules` fixpoint and no merge step. Each read of a declaration is a query on the files
      that answer it. A value is computed only when something reads it. sven follows
      [Cycle.js](https://cycle.js.org): a component reads sources and writes sinks, and Nix laziness closes the loop.
    ''
    (docs.note "Why another configuration language?" ''
      sven covers every capability of [Den](https://github.com/denful/den), den-hoag and [clan](https://clan.lol)
      with these four words. On top, it answers questions: graph queries, Datalog with a well-founded semantics,
      and µKanren with constraints, all in pure Nix. An agent can stage a change and get it refused with the reason,
      before you deploy.
    '')
    (docs.links [
      { title = "Getting started"; href = "/start/getting-started/"; description = "One NixOS host, in four files."; }
      { title = "The reference fleet"; href = "https://github.com/vic/sven/tree/main/templates/fleet"; description = "Every capability, in one running specification."; }
    ])
  ];

  checks = { r, ... }: {
    packages = r.reduced.packages == { "office:main/machine:reception" = [ "git" ]; "office:main/machine:studio" = [ "git" "gimp" ]; };
    inventory = r.flake.inventory.studio == [ "git" "gimp" ];
  };
}
