# sven: Nix fleets you can query, and prove things about, before you deploy

<!-- Generated from docs/examples/one-page-fleet/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->

**sven is a query language for Nix configurations**: one file of Nix builtins, no dependencies, no module system,
no fixpoint, and no `throw`. You describe a fleet as data and behavior. sven answers queries on it: the systems to build,
the errors, the graph of who gives what to whom, and whether your rules hold across machines.

sven has no batteries and no vocabulary. It does not know what a host, a user or NixOS is. You name your own nouns,
so it configures NixOS, nix-darwin, home-manager, clusters, terraform or anything else you can model as Nix values.

[Documentation](https://sven.oeiuwq.com/) · [Getting started](https://sven.oeiuwq.com/start/getting-started/) · [Reference fully-featured fleet](https://github.com/vic/sven/tree/main/templates/fleet) · [vic/vix on sven](https://github.com/vic/vix/tree/sven) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)

## Four words

- **Kinds**: your nouns, typed. `sven.kinds.host.fields.addr = lib.types.str;`
- **Scopes**: where things live. `spawns` builds a tree from your data: a user under each host it is on.
- **Aspects**: behavior, active where a predicate holds: a kind, an instance, another aspect, or any fact.
- **Sinks**: where elements go. An element goes up to the nearest scope that collects it, and the sink reduces them.

Data is queried, not merged: each read is a query on the files that answer it, so content in many files never
overwrites itself, and an error is a record you can read.

## A fleet on one page

Two environments, three NixOS hosts, a user on two of them, postgres placed by a fact (some host names it as its
database), and a rule that holds across machines. Every line runs: these files are a tested template
(plus a `hardware.nix` stub so NixOS evaluates).


```nix title="modules/kinds.nix"
# Kinds are your nouns. `spawns` builds the tree from data. Sinks collect what aspects give.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib) same is maybe;
in
{
  sven.kinds.fleet.spawns.env = _: sven.env;
  sven.kinds.fleet.sinks.out.reduce = sven.lib.reduce.merge;
  sven.kinds.env.fields.domain = lib.types.str;
  sven.kinds.env.spawns.host = s: lib.filterAttrs (_: h: same h.env s) sven.host;
  sven.kinds.host.fields = {
    env = sven.kinds.env;
    db = maybe sven.kinds.host;
  };
  sven.kinds.host.spawns.user = s: lib.filterAttrs (_: u: lib.any (same s) u.on) sven.user;
  sven.kinds.host.sinks.os.nixos =
    { os, ... }:
    {
      imports = os;
    }; # os feeds nixos
  sven.kinds.host.sinks.nixos.out =
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };
  sven.kinds.user.fields.on = is lib.isList;
  sven.flake = { out, ... }: out;
}
```

```nix title="modules/data.nix"
# Instances: plain data, refs between them.
{ sven, ... }:
{
  sven.fleet.main = { };
  sven.env.prod.domain = "example.com";
  sven.env.lab.domain = "lab.example.com";
  sven.host.web = {
    env = sven.env.prod;
    db = sven.host.db;
  };
  sven.host.db.env = sven.env.prod;
  sven.host.box.env = sven.env.lab;
  sven.user.ana.on = [
    sven.host.web
    sven.host.box
  ];
}
```

```nix title="modules/behavior.nix"
# Aspects are active where a predicate holds; each element goes up to the nearest `os` sink.
{ sven, lib, ... }:
let
  inherit (sven.lib) same;
in
{
  sven.aspects.names = {
    at = sven.kinds.host;
    os =
      { host, env, ... }:
      {
        networking = {
          hostName = host.name;
          domain = env.domain;
        };
      };
  };
  sven.aspects.account = {
    at = sven.kinds.user; # no `os` sink on a user: the account lands on each host ana is on
    os =
      { user, ... }:
      {
        users.users.${user.name}.isNormalUser = true;
      };
  };
  sven.aspects.postgres = {
    at = s: lib.any (h: same h.db s) (lib.attrValues sven.host); # a fact: some host uses me as its db
    os.services.postgresql.enable = true;
  };
  # a rule across machines, checked before deploy: a host's db lives in its environment
  sven.invariants.db-same-env =
    { scopes, ... }:
    map (s: {
      head = "bad:db-other-env:${s.name}";
      pos = [ "ref:db:${s.id}:host:${s.db.name}" ];
    }) (lib.filter (s: s.kind == "host" && s.db != null && !(same s.db.env s.env)) scopes);
}
```

Ask it. The tree comes from the data:


```nix title="result"
[
  "fleet:main"
  "fleet:main/env:lab"
  "fleet:main/env:lab/host:box"
  "fleet:main/env:lab/host:box/user:ana"
  "fleet:main/env:prod"
  "fleet:main/env:prod/host:db"
  "fleet:main/env:prod/host:web"
  "fleet:main/env:prod/host:web/user:ana"
]
```

## Change it safely

An agent proposes a host in `lab` that uses the prod database. `sven.lib.stage` evaluates the fleet without and with
the change, applies nothing, and refuses it with the rule it breaks:


```nix title="changes/api-in-lab.nix"
# A change, as an agent proposes it: a lab host that uses the prod database.
{ sven, ... }:
{
  sven.host.api = {
    env = sven.env.lab;
    addr = "10.0.1.2";
    db = sven.host.db;
  };
}
```

```nix title="result"
{
  added = [
    "fleet:main/env:lab/host:api"
  ];
  ok = false;
  violations = [
    "bad:db-other-env:api"
  ];
}
```

## What else it does

- **Graphs, Datalog and µKanren, in pure Nix**: deploy waves, well-founded models with proofs and why-not, and values
  synthesized under constraints (a free port, guest memory that fits). [Ask and prove](https://sven.oeiuwq.com/query/queries/)
- **Agents as team members**: every answer is JSON-safe data. Changes are staged, checked by invariants, limited by
  grants that only narrow, and written as change programs. An MCP server answers agents. [For agents](https://sven.oeiuwq.com/agents/agent-surface/)
- **Errors with fixes**: `code`, `path`, `got`, `want`, `fix`, and `near` for typos. [Errors as data](https://sven.oeiuwq.com/concepts/errors/)
- **Fast where it counts**: one nixpkgs per system across hosts, and trimmed NixOS module lists, with drvPath oracles
  that prove the systems are the same. [Performance](https://sven.oeiuwq.com/perf/shared-pkgs/)
- **Every capability of Den, den-hoag and clan**, and the patterns of real fleets, each with a check, in the
  [reference fleet](https://github.com/vic/sven/tree/main/templates/fleet). [From Den](https://sven.oeiuwq.com/migrate/from-den/)

## Start


```sh frame="terminal"
nix flake init -t github:vic/sven#one-page-fleet
```

Then read the [documentation](https://sven.oeiuwq.com/): every page is a tested example. Coming from `configuration.nix`, a flake or Den?
The [migration guides](https://sven.oeiuwq.com/migrate/from-configuration-nix/) build the same systems before and after.

sven is made by [vic](https://github.com/vic), with love, as part of the [Dendritic ecosystem](https://dendritic.oeiuwq.com).
If it helps you, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull requests are welcome:
see [CONTRIBUTING.md](CONTRIBUTING.md).

