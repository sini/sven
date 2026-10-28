# Den CI usage patterns not shown elsewhere in the fleet (vic/den-patterns.md #22 #23 #26 #48 #63 #67 #77 #103 #115 #116).
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib) all within same;
  pkgs = s: inputs.nixpkgs.legacyPackages.${s};
in
{
  # #22 #23 pets and toys under hosts. A host-level cycle pairs every user with every pet (cartesian);
  # a toy-scope element reads its pet (nearest) and lands at the host (transitive).
  sven.kinds.host.spawns.pet = s: lib.filterAttrs (_: p: same p.of s) sven.pet;
  sven.kinds.pet = {
    fields.of = sven.kinds.host;
    spawns.toy = s: lib.filterAttrs (_: t: same t.of s) sven.toy;
  };
  sven.kinds.toy.fields.of = sven.kinds.pet;
  sven.pet = {
    rex.of = sven.host.stage;
    fido.of = sven.host.stage;
  };
  sven.toy = {
    ball.of = sven.pet.rex;
    bone.of = sven.pet.rex;
  };
  sven.kinds.host.sinks.pairs.reduce = sven.lib.reduce.set;
  sven.aspects.user-pet-pairs = {
    at = sven.kinds.host;
    cycle =
      { tree, ... }:
      {
        tree = [
          {
            category = "u";
            children = sven.kinds.user;
          }
          {
            category = "p";
            children = sven.kinds.pet;
          }
        ];
        pairs = lib.concatMap (u: map (p: "${u.name}-${p.name}") (lib.head (tree.select "p"))) (
          lib.head (tree.select "u")
        ); # one response per request
      };
  };
  sven.aspects.pet-toys = {
    at = sven.kinds.toy;
    pairs = { pet, toy, ... }: "${pet.name}/${toy.name}";
  };

  # #26 a user's `classes` choose its home systems
  sven.kinds.user.fields.classes = sven.lib.opt (sven.helpers.listOf (
    sven.helpers.enum [
      "homeManager"
      "maid"
    ]
  )) [ "homeManager" ];
  sven.user.bob.classes = [
    "homeManager"
    "maid"
  ];
  sven.aspects.maid-all = {
    at = sven.kinds.user;
    maid.".editorconfig" = "root = true";
  }; # given by every user; only users listing maid receive

  # #48 enrichment: a sink IS context. One aspect gives `isNixos`, another derives `platform` from it, content reads both.
  sven.kinds.host.sinks = {
    isNixos.reduce = sven.lib.reduce.one;
    platform.reduce = sven.lib.reduce.one;
  };
  sven.aspects.host-guards = {
    at = sven.kinds.host;
    isNixos = { host, ... }: host.system.name != "aarch64-darwin";
  };
  sven.aspects.platform-info = {
    at = sven.kinds.host;
    platform = { isNixos, ... }: if isNixos then "linux" else "other";
  };
  sven.aspects.platform-env = {
    at = sven.kinds.host;
    nixos =
      { platform, ... }:
      {
        environment.variables.PLATFORM = platform;
      };
  };

  # #63 per-host packages from USER content roll up into packages.<host system>
  sven.kinds.fleet.sinks.user-packages = {
    reduce = sven.lib.reduce.merge;
    out =
      { user-packages, ... }:
      {
        packages = lib.mapAttrs (_: ps: ps) user-packages;
      };
  };
  sven.aspects.nh-tool = {
    at = all [
      sven.kinds.user
      (within sven.kinds.host)
    ];
    user-packages =
      { host, user, ... }:
      {
        ${host.system.name}."sw-${host.name}-${user.name}" =
          (pkgs host.system.name).writeText "sw" host.name;
      };
  };

  # #67 #88 #127 host-written homeManager content for users who OPT IN; it runs at the user, with the user's own pool
  sven.kinds.user.sinks.hmvals = { };
  sven.aspects.host-aspects-opt-in.at = sven.user.alice;
  sven.aspects.user-emitter = {
    at = sven.user.alice;
    hmvals = "user";
  };
  sven.aspects.stage-home = {
    at = all [
      sven.kinds.user
      (within sven.host.stage)
      sven.aspects.host-aspects-opt-in
    ];
    homeManager =
      { hmvals, environment, ... }:
      {
        home.sessionVariables = {
          HMVALS = lib.concatStringsSep "-" hmvals;
          HOST_ENV = environment.name;
        };
      };
  };

  # #77 a pipeline stage between producers and consumers: `fw` is filtered into `fw-tcp` by a sink key
  sven.kinds.host.sinks.fw-tcp = { };
  sven.kinds.host.sinks.fw = {
    fw-tcp = { fw, ... }: lib.filter (e: e.proto == "tcp") fw;
  };
  sven.aspects.fw-ports = {
    at = sven.host.lb;
    fw = {
      port = 80;
      proto = "tcp";
    };
  };
  sven.aspects.fw-dns = {
    at = sven.host.lb;
    fw = {
      port = 53;
      proto = "udp";
    };
  };
  sven.aspects.fw-reader = {
    at = sven.host.lb;
    nixos =
      { fw-tcp, ... }:
      {
        networking.firewall.allowedTCPPorts = map (e: e.port) (lib.concatLists fw-tcp);
      };
  };

  # #103 one class forwarded into BOTH the machine's NixOS and the user's home-manager (an option both module systems have)
  sven.kinds.user.sinks.both = {
    at = within sven.helpers.linux;
    os =
      { both, ... }:
      {
        imports = both;
      };
    homeManager =
      { both, ... }:
      {
        imports = both;
      };
  };
  sven.aspects.htop-both = {
    at = sven.user.bob;
    both.programs.htop.enable = true;
  };

  # #115 broadcast: the SENDER tags who receives; readers keep what targets them, never their own
  sven.kinds.fleet.sinks.peer-dev.reduce = sven.lib.reduce.entries;
  sven.aspects.peer-dev = {
    at = all [
      sven.kinds.user
      (within sven.helpers.linux)
    ];
    peer-dev =
      { scope, ... }:
      {
        who = "${scope.name}@${scope.parent.name}";
        to = s: s.kind == "host";
      }; # to every host
  };
  sven.aspects.peer-dev-reader = {
    at = sven.kinds.host;
    nixos =
      { peer-dev, scope, ... }:
      {
        environment.etc."peers".text = lib.concatStringsSep "," (
          map (e: e.value.who) (lib.filter (e: e.value.to scope && e.from.parent.id != scope.id) peer-dev)
        );
      };
  };

  # #116 a host value that reads the host's OWN realized config, consumed in its users' homes
  sven.kinds.host.sinks.dev.reduce = sven.lib.reduce.one;
  sven.aspects.host-dev = {
    at = sven.host.stage;
    dev = { host, out, ... }: "h:${out.nixosConfigurations.${host.name}.config.networking.hostName}";
  };
  sven.aspects.home-dev = {
    at = all [
      sven.kinds.user
      (within sven.host.stage)
    ];
    homeManager =
      { dev, ... }:
      {
        home.sessionVariables.DEV = dev;
      };
  };
}
