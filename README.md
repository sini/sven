# sven - **Nix configurations you can ask questions about, and prove things about, before you deploy.**

A cycle.js inspired pure-Nix language for advanced fleet configurations where everything is a query.

![sven](./sven.png)

sven is a small _~500loc_, dependency free _-Nix builtins only-_ query language over nix data, _inspired by [reactive-streams](https://cycle.js.org)_ for configuring fleets of machines: NixOS, nix-darwin, home-manager, terraform, clusters and anything else you can model as plain nix values. You write plain Nix data and behavior. sven answers queries on it: the systems to build, the errors, the graph of who gives what to whom, and whether your rules hold.

It is one file with no dependencies: Nix builtins only. No nixpkgs, no module system, no fixpoint. An error is data you can read, never a `throw`.

```nix
{ sven, lib, ... }:
{
  sven.kinds.host.fields.addr = lib.types.str;
  sven.host.lb.addr = "10.0.1.1";
  sven.aspects.motd = {
    at = sven.kinds.host;                                  # where it applies: a predicate
    nixos.environment.etc.motd.text = "managed by sven";   # what it gives: an element for the `nixos` sink
  };
}
```

## What it does

- **Data is queried, not merged.** Kinds, instances and typed fields are data. Each read is a query, so content in many files never overwrites itself. [More](templates/fleet/README.md#data-is-queried-not-merged)
- **Behavior lands where you say.** An aspect is active where its predicate holds, and its elements go to the nearest scope that collects them. [Aspects](templates/fleet/README.md#aspects-behavior-at-scopes) · [Sinks](templates/fleet/README.md#sinks-where-elements-go)
- **Questions have answers.** Graph algorithms, Datalog with a well-founded semantics, and µKanren with constraints, all in pure Nix. [Graphs, Datalog and krn](templates/fleet/README.md#graphs-datalog-and-krn)
- **Agents can work on it safely.** Rules across machines are checked before deploy. A change is staged, explained, and refused with its reason. An MCP server answers agents. [For agents](templates/fleet/README.md#for-agents-ask-prove-change)
- **It is fast where it counts.** It evaluates 10,000 modules in about 20 s. The fleet shares one nixpkgs per channel (-30% CPU) and can trim NixOS module lists, with the same built systems. [Shared pkgs](templates/fleet/README.md#shared-pkgs-one-nixpkgs-per-channel-and-system)

## It covers what you use today

The reference fleet shows every capability of [Den](https://github.com/denful/den), den-hoag and [clan](https://clan.lol), and the advanced usage patterns of several real world fleets (vic, sini, and others). Each one has a check. [sven, Den and den-hoag](templates/fleet/README.md#sven-den-and-den-on-gen) · [sven and clan](templates/fleet/README.md#sven-and-clan) · [Patterns](templates/fleet/README.md#patterns-in-this-fleet)

## Start

Read the [fleet guide](templates/fleet/README.md): start with [Start](templates/fleet/README.md#start). Then see [the fleet, live](templates/fleet/README.md#this-fleet-live), which has diagrams generated from its own queries, and the [capability index](templates/fleet/README.md#capability-index-generated), which lists everything sven can do.

Every test runs in GitHub Actions on each push: [.github/workflows/test.yml](.github/workflows/test.yml).
