# Fleet oracles: one check per row of Ren's expected-results table, sini's patterns and Den's.
# Run: nix eval --offline --impure --file tests.nix failed        (expect [ ])
#      nix eval --offline --impure --file tests.nix e2e.failed    (real NixOS / darwin / home-manager evals)
let
  inputs = (builtins.getFlake "path:${toString ../..}?dir=templates/fleet").inputs;
  inherit (inputs.nixpkgs) lib;
  sven = (import inputs.sven).lib;
  fleet = extra: {
    imports = [ (inputs.import-tree ./modules) ] ++ extra;
    _module.args = { inherit inputs lib; };
  };
  r = sven.eval (fleet [ ]);
  with' = m: sven.eval (fleet [ m ]);
  msgs = q: map (e: e.error) q.errors;
  hasMsg = q: re: lib.any (m: builtins.match re m != null) (msgs q);
  out = r.flake;

  P = "fleet:main/environment:prod";
  S = "fleet:main/environment:staging";
  lb = "${P}/host:lb";
  web1 = "${P}/host:web-1";
  web2 = "${P}/host:web-2";
  stage = "${S}/host:stage";
  ci = "${stage}/guest:ci";
  studio = "${S}/mac:studio";
  laptop = "fleet:main/home:alice-laptop";
  red = sink: id: r.reduced.${sink}.${id} or null;
  list = v: if lib.isList v then v else [ ];
  first = xs: if xs == [ ] then null else lib.head xs;
  names = xs: let v = first xs; in if lib.isAttrs v then lib.attrNames v else [ ];
  on = a: lib.filter (id: r.active.${a}.${id}) (lib.attrNames r.active.${a});
  edge = sink: from: to: lib.elem { inherit sink from to; } r.graph.edges;
  scope = id: lib.findFirst (s: s.id == id) null r.scopes;
  at = path: v: lib.attrByPath path null v;
  nixosAt = id: path: lib.filter (v: v != null) (map (at path) (list (red "nixos" id)));
  hmAt = id: path: lib.filter (v: v != null) (map (at path) (list (red "homeManager" id)));
  upTo = kinds: s: lib.findFirst (x: lib.elem x.kind kinds) null (lib.reverseList s.up);

  checks = {
    # ── Ren expected-results ──
    no-errors = msgs r == [ ];
    docs-mermaid = lib.hasInfix "-->|nixos|" out.docs.mermaid && edge "nixos" ci stage;
    fold-one = out.deploy.nodes.lb.hostname == "10.0.1.1";
    fold-one-two-emitters = hasMsg (with' ({ sven, ... }: { sven.aspects.deploy2 = { at = sven.host.lb; deploy = { address = "x"; user = "y"; }; }; })) "one: got 2 elements";
    fold-list-order = red "backends" P == [ "10.0.1.10" "10.0.1.11" ];
    guest-channel-stable = (scope ci).channel.name == "stable" && (scope stage).channel.name == "edge";
    guest-pkgs-stable = (first (nixosAt stage [ "microvm" "vms" "ci" "pkgs" ])).path == inputs.nixpkgs.legacyPackages.x86_64-linux.path;
    chained-forward = edge "os" "${ci}/user:bob" ci && edge "nixos" ci stage && !(lib.any (u: u ? bob) (nixosAt stage [ "home-manager" "users" ]));
    darwin-not-nixos = out ? darwinConfigurations.studio && !(out.nixosConfigurations ? studio) && !(out.nixosConfigurations ? ci);
    kernel-not-on-studio = !r.active.kernel.${studio} && r.active.kernel.${lb};
    ssh-agent-not-standalone = !r.active.ssh-agent."${laptop}/user:alice" && r.active.ssh-agent."${lb}/user:alice";
    host-qualified-htop = on "htop" == [ "${web1}/user:alice" ];
    substitute-web2 = !r.active.motd.${web2} && r.active.motd-short.${web2} && r.active.motd.${web1};
    has-docker = lib.sort (a: b: a < b) (on "docker") == [ stage ci ];
    parent-devices = names (hmAt "${lb}/user:alice" [ "services" "syncthing" "settings" "devices" ])
      == lib.sort (a: b: a < b) [ "web-1" "web-2" "stage" "ci" "studio" "pixel" "alice-laptop" ];
    per-system = lib.attrNames out.packages == [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] && lib.all (p: p ? hello) (lib.attrValues out.packages);
    overlays-once = lib.length (red "overlays" "fleet:main") == 1;
    persist-stage = lib.sort (a: b: a < b) (red "persist" stage) == [ "/home/alice/.local/state/syncthing" "/home/bob/.local/state/syncthing" "/var/lib/docker" "/var/lib/nginx" ];
    persist-ci-own = lib.elem "/var/lib/docker" (red "persist" ci);
    output-merge-equal = msgs (with' ({ sven, ... }: { sven.aspects.same-hello = { at = sven.system.x86_64-linux; packages.greeting = "hi"; }; sven.aspects.same-hello2 = { at = sven.system.x86_64-linux; packages.greeting = "hi"; }; })) == [ ];
    output-merge-conflict = hasMsg (with' ({ sven, ... }: { sven.aspects.c1 = { at = sven.system.x86_64-linux; packages.greeting = "a"; }; sven.aspects.c2 = { at = sven.system.x86_64-linux; packages.greeting = "b"; }; })) "merge conflict at greeting";
    bare-overlay-refused = hasMsg (with' ({ sven, ... }: { sven.aspects.bare = { at = sven.fleet.main; overlays = final: prev: { }; }; })) ".*bare function.*";
    home-darwin-only-studio = lib.attrNames r.reduced.homeDarwin == [ "${studio}/user:alice" "${studio}/user:bob" ];
    tags-stage-web = lib.elem "web" (red "tags" stage);
    flake-file-inputs = lib.attrNames out.flake-file.inputs == [ "agenix" "microvm" "nixpkgs" ];
    flake-file-conflict = hasMsg (with' ({ sven, ... }: { sven.aspects.agenix2 = { at = sven.fleet.main; flake-file.inputs.agenix.url = "github:other/agenix"; }; })) "merge conflict at inputs.agenix.url";
    recursive-attrs-deploy = lib.attrNames out.deploy.nodes == [ "lb" "stage" "web-1" "web-2" ];
    recursive-attrs-colmena = lib.attrNames r.reduced.colmena."fleet:main" == [ "lb" "stage" "web-1" "web-2" ];
    root-emission = out.flake-file.inputs.nixpkgs.url == "github:nixos/nixpkgs/nixos-25.05";
    spawn-pixel-only-alice = lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes != [ ] && map (s: s.name) (lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes) == [ "alice" ];
    spawn-lb-only-alice = map (s: s.name) (lib.filter (s: s.parent != null && s.parent.id == lb && s.kind == "user") r.scopes) == [ "alice" ];
    data-kinds-no-scopes = !(lib.any (s: lib.elem s.kind [ "group" "machine" "channel" "db" "region" ]) r.scopes);
    tray-stage-not-lb = hmAt "${stage}/user:alice" [ "services" "syncthing" "tray" "enable" ] == [ true ] && hmAt "${lb}/user:alice" [ "services" "syncthing" "tray" "enable" ] == [ false ];
    into-outputs = out ? colmenaHive && out ? ageManifest && out ? packages && out ? terraformConfigurations;
    inventory-json = (scope web1) != null && (scope web2).buildHost == "10.0.1.1";
    inventory-string-ref-refused = hasMsg (with' { sven.host.bad = { environment = "prod"; addr = "x"; }; }) ".*environment wants a environment ref.*";
    vars = out.vars.shared.ca.files == [ "ca.crt" "ca.key" ] && lib.attrNames out.vars.per-machine == [ "lb" "stage" "web-1" "web-2" ];
    checks-names = lib.attrNames out.checks.x86_64-linux == [ "lb-no-gui" "pre-commit" "web" ] && !(out.checks.aarch64-linux ? web) && out.checks.aarch64-linux ? pre-commit;
    buildhost = (red "deploy" web2).buildHost == "10.0.1.1" && (red "deploy" lb).buildHost == null && red "deploy" ci == null;
    facter-metal = on "facter" == [ lb web1 web2 stage ];
    typed-scrape = red "scrape" "fleet:main" == [ { job = "r1"; target = "eu.eu:9090"; } ];
    typed-scrape-bad = hasMsg (with' ({ sven, ... }: { sven.aspects.bad-scrape = { at = sven.host.lb; scrape.job = 1; }; })) ".*fails `of`.*";
    diamond-nginx-once = lib.length (nixosAt web1 [ "services" "nginx" "enable" ]) == 1 && lib.length (nixosAt stage [ "services" "nginx" "enable" ]) == 1;
    merge-across-files = r.active.base.${lb} && lib.attrNames (red "records" "fleet:main") == [ "ci" "lb" "stage" "studio" "web-1" "web-2" ];
    recursive-kinds = scope "fleet:main/domain:example.org/domain:api.example.org/domain:v1.api.example.org" != null;
    twice-on-path = hasMsg (with' ({ sven, ... }: { sven.kinds.fleet.spawns.ring = _: { r = { }; }; sven.kinds.ring.spawns.ring = s: { r = { }; }; })) ".*instance ring:r twice on path.*";
    nearest-bob-ci = (upTo [ "host" "guest" "mac" ] (scope "${ci}/user:bob")).id == ci && (upTo [ "environment" ] (scope "${ci}/user:bob")).name == "staging" && upTo [ "environment" ] (scope "fleet:main") == null;
    graph-query = lib.length r.graph.scopes == lib.length r.scopes;

    # ── sini ──
    k3s-cluster-only = lib.sort (a: b: a < b) (on "k3s") == [ web1 web2 ];
    k3s-discovery = out.k8sManifests.axon.applications.k3s.nodes == [ "10.0.1.10" "10.0.1.11" ] && out.k8sManifests.axon.target.branch == "main";
    ingest-across-envs = nixosAt web1 [ "environment" "etc" "alloy/endpoints" "text" ] == [ "https://ingest.example.org\n" ] && nixosAt stage [ "environment" "etc" "alloy/endpoints" "text" ] == [ "" ];
    domains-records = map (e: e.value.name) (red "dns-records" "fleet:main") == [ "example.org" ] && lib.length (red "certificate-domains" "fleet:main") == 3;
    terranix-conditional = out ? terranixConfigurations.dns-prod && !(out.terranixConfigurations ? dns-staging);
    unifi-forwards = out.unifiTerranixModules.prod != [ ] && lib.length (red "port-forwards" P) == 1;
    home-linux = r.reduced.homeLinux ? "${lb}/user:alice" && !(r.reduced.homeLinux ? "${studio}/user:alice") && !(r.reduced.homeLinux ? "${laptop}/user:alice");
    primary-user = on "primary-user" == [ "${lb}/user:alice" ];
    syncthing-hub = on "syncthing-hub" == [ stage ] && names (nixosAt stage [ "services" "syncthing" "settings" "folders" ]) == [ "alice-home" "bob-home" ];
    syncthing-peers = first (hmAt "${lb}/user:alice" [ "home" "file" ".syncthing-peers" "text" ]) == builtins.toJSON [ "web-1" "web-2" "ci" "stage" ]; # path order: guest:ci sorts before user:alice
    unpersist-web2 = let d = id: first (nixosAt id [ "environment" "persistence" "/persist" "directories" ]); in !(lib.elem "/var/lib/nginx" (d web2)) && lib.elem "/var/lib/nginx" (d web1) && lib.elem "/var/lib/nginx" (red "persist" web2);
    tags-from-roles = r.reduced.colmena."fleet:main".stage.deployment.tags == [ "staging" "web" "workstation" "laptop" ] && r.reduced.colmena."fleet:main".lb.deployment.tags == [ "prod" "server" ];
    profile-not-guests = r.active.desktop.${stage} && !r.active.desktop.${ci} && r.active.thermald.${stage};
    unfree-set = red "unfree" stage == [ "terraform" ];
    xmsg-trust = hmAt "${lb}/user:alice" [ "home" "file" ".xmsg-peers" "text" ] == [ (builtins.toJSON [ "bob" ]) ];
    flake-level = out ? devShells.x86_64-linux.default && out ? formatter.x86_64-linux && out.packages.x86_64-linux ? greet && out.packages.x86_64-linux ? k8s-all && out ? overlays.default;
    settings-cascade = nixosAt web1 [ "boot" "kernelParams" ] == [ [ "zfs.zfs_arc_max=8589934592" ] ] && nixosAt stage [ "boot" "kernelParams" ] == [ [ "zfs.zfs_arc_max=4294967296" ] ] && nixosAt lb [ "boot" "kernelParams" ] == [ [ "zfs.zfs_arc_max=4294967296" ] ];
    relation-kind = scope "fleet:main/replica:r1" != null && scope "fleet:main/replica:r2" == null;

    # ── Den ──
    den-specialisation = edge "nixos" "${lb}/variant:debug" lb && nixosAt lb [ "specialisation" "debug" "configuration" "imports" ] != [ ];
    den-ids = nixosAt lb [ "services" "openssh" "ports" ] == [ [ 2200 ] ] && nixosAt web2 [ "services" "openssh" "ports" ] == [ [ 2203 ] ];
    den-module-outside = lib.isList (red "nixos" lb) && lib.length (red "nixos" lb) > 10; # moduleOf: a query gives the module list
    den-nested-groups = lib.length (lib.filter (s: s.kind == "user" && s.name == "alice") r.scopes) == 8;
  };

  e2e = rec {
    lbCfg = out.nixosConfigurations.lb.config;
    checks = {
      lb-toplevel = lib.hasSuffix ".drv" lbCfg.system.build.toplevel.drvPath;
      lb-haproxy-order = lib.hasInfix "10.0.1.10:80 check\n  server 10.0.1.11" lbCfg.services.haproxy.config;
      lb-motd = lbCfg.environment.etc.motd.text == "managed by sven" && lbCfg.networking.hostName == "lb";
      lb-overlay = lib.length lbCfg.nixpkgs.overlays == 1;
      lb-flatten-class-lib = lbCfg.users.users.alice.description == "Alice" && lbCfg.users.users.alice.isNormalUser;
      lb-hm-alice = lbCfg.home-manager.users.alice.programs.git.enable && lbCfg.home-manager.users.alice.services.ssh-agent.enable;
      lb-age-manifest = out.ageManifest.lb == [ "attic-env" ] && lbCfg.age.secrets.attic-env.path == "/run/agenix/lb-attic";
      lb-specialisation = lbCfg.specialisation ? debug;
      lb-no-gui-passes = out.checks.x86_64-linux.lb-no-gui.drvAttrs.buildCommand == "touch $out";
      lb-no-gui-firefox-fails = lib.hasInfix "exit 1" (with' ({ pkgs ? null, ... }: { sven.aspects.firefox = { at = { kind = "host"; name = "lb"; }; nixos = { pkgs, ... }: { environment.systemPackages = [ pkgs.firefox ]; }; }; })).flake.checks.x86_64-linux.lb-no-gui.drvAttrs.buildCommand;
      studio-darwin = let c = out.darwinConfigurations.studio.config; in c.system.defaults.dock.autohide && c.networking.hostName == "studio" && c.home-manager.users.bob.programs.aerospace.enable;
      home-edge = let c = out.homeConfigurations.alice-laptop.config; in c.programs.git.enable && !c.services.ssh-agent.enable && c.home.username == "alice";
    };
    failed = lib.filter (n: !checks.${n}) (lib.attrNames checks);
  };
in
{
  inherit checks e2e;
  failed = lib.filter (n: !checks.${n}) (lib.attrNames checks);
}
