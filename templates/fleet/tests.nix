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
  edge = sink: from: to: lib.any (e: e.sink == sink && e.from == from && e.to == to) r.graph.edges;
  gave = origin: sink: to: lib.any (e: e.origin == origin && e.sink == sink && e.to == to) r.graph.edges; # projected hasAspect: what an aspect delivered where
  scope = id: lib.findFirst (s: s.id == id) null r.scopes;
  at = path: v: lib.attrByPath path null v;
  nixosAt = id: path: lib.filter (v: v != null) (map (at path) (list (red "nixos" id)));
  osAt = id: path: lib.filter (v: v != null) (map (at path) (list (red "os" id)));
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
      == [ "alice-laptop" "alice@stage" "ci" "lb-minimal" "pixel" "stage" "studio" "web-1" "web-2" ];
    per-system = lib.attrNames out.packages == [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] && lib.all (p: p ? hello) (lib.attrValues out.packages);
    overlays-once = lib.length (red "overlays" "fleet:main") == 1;
    persist-stage = lib.sort (a: b: a < b) (red "persist" stage) == [ "/home/alice/.local/state/syncthing" "/home/bob/.local/state/syncthing" "/var/lib/docker" "/var/lib/nginx" ];
    persist-ci-own = lib.elem "/var/lib/docker" (red "persist" ci);
    output-merge-equal = msgs (with' ({ sven, ... }: { sven.aspects.same-hello = { at = sven.system.x86_64-linux; packages.greeting = "hi"; }; sven.aspects.same-hello2 = { at = sven.system.x86_64-linux; packages.greeting = "hi"; }; })) == [ ];
    output-merge-conflict = hasMsg (with' ({ sven, ... }: { sven.aspects.c1 = { at = sven.system.x86_64-linux; packages.greeting = "a"; }; sven.aspects.c2 = { at = sven.system.x86_64-linux; packages.greeting = "b"; }; })) "merge conflict at greeting";
    bare-overlay-refused = hasMsg (with' ({ sven, ... }: { sven.aspects.bare = { at = sven.fleet.main; overlays = final: prev: { }; }; })) ".*bare function.*";
    home-darwin-only-studio = lib.attrNames r.reduced.homeDarwin == [ "${studio}/user:alice" "${studio}/user:bob" ];
    tags-stage-web = lib.elem "web" (red "tags" stage);
    flake-file-inputs = lib.attrNames (red "flake-file" "fleet:main").inputs == lib.attrNames (import ./flake.nix).inputs; # the generated flake.nix has exactly the declared inputs
    flake-file-conflict = hasMsg (with' ({ sven, ... }: { sven.aspects.agenix2 = { at = sven.fleet.main; flake-file.inputs.agenix.url = "github:other/agenix"; }; })) "merge conflict at inputs.agenix.url";
    recursive-attrs-deploy = lib.attrNames out.deploy.nodes == [ "lb" "lb-minimal" "stage" "web-1" "web-2" ];
    recursive-attrs-colmena = lib.attrNames r.reduced.colmena."fleet:main" == [ "lb" "lb-minimal" "stage" "web-1" "web-2" ];
    root-emission = (red "flake-file" "fleet:main").inputs.nixpkgs.url == "github:nixos/nixpkgs/nixos-25.05";
    spawn-pixel-only-alice = lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes != [ ] && map (s: s.name) (lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes) == [ "alice" ];
    spawn-lb-only-alice = map (s: s.name) (lib.filter (s: s.parent != null && s.parent.id == lb && s.kind == "user") r.scopes) == [ "alice" ];
    data-kinds-no-scopes = !(lib.any (s: lib.elem s.kind [ "group" "machine" "channel" "db" "region" ]) r.scopes);
    tray-stage-not-lb = hmAt "${stage}/user:alice" [ "services" "syncthing" "tray" "enable" ] == [ true ] && hmAt "${lb}/user:alice" [ "services" "syncthing" "tray" "enable" ] == [ false ];
    into-outputs = out ? colmenaHive && out ? ageManifest && out ? packages && out ? terraformConfigurations;
    inventory-json = (scope web1) != null && (scope web2).buildHost == "10.0.1.1";
    inventory-string-ref-refused = hasMsg (with' { sven.host.bad = { environment = "prod"; addr = "x"; }; }) ".*environment wants a environment ref.*";
    vars = out.vars.shared.ca.files == [ "ca.crt" "ca.key" ] && lib.attrNames out.vars.per-machine == [ "lb" "lb-minimal" "stage" "web-1" "web-2" ];
    checks-names = lib.attrNames out.checks.x86_64-linux == [ "files/README.md" "files/ci.json" "flake-file" "guard-pod" "infra-lb" "infra-stage" "infra-web-1" "infra-web-2" "lb-no-gui" "pre-commit" "web" ] && !(out.checks.aarch64-linux ? web) && out.checks.aarch64-linux ? pre-commit;
    buildhost = (red "deploy" web2).buildHost == "10.0.1.1" && (red "deploy" lb).buildHost == null && red "deploy" ci == null;
    facter-metal = on "facter" == [ lb "${lb}/host:lb-minimal" web1 web2 stage ];
    typed-scrape = red "scrape" "fleet:main" == [ { job = "r1"; target = "eu.eu:9090"; } ];
    typed-scrape-bad = hasMsg (with' ({ sven, ... }: { sven.aspects.bad-scrape = { at = sven.host.lb; scrape.job = 1; }; })) ".*fails `of`.*";
    diamond-nginx-once = lib.length (nixosAt web1 [ "services" "nginx" "enable" ]) == 1 && lib.length (nixosAt stage [ "services" "nginx" "enable" ]) == 1;
    merge-across-files = r.active.base.${lb} && lib.attrNames (red "records" "fleet:main") == [ "ci" "lb" "lb-minimal" "stage" "studio" "web-1" "web-2" ];
    recursive-kinds = scope "fleet:main/domain:example.org/domain:api.example.org/domain:v1.api.example.org" != null;
    twice-on-path = hasMsg (with' ({ sven, ... }: { sven.kinds.fleet.spawns.ring = _: { r = { }; }; sven.kinds.ring.spawns.ring = s: { r = { }; }; })) ".*instance ring:r twice on path.*";
    nearest-bob-ci = (upTo [ "host" "guest" "mac" ] (scope "${ci}/user:bob")).id == ci && (upTo [ "environment" ] (scope "${ci}/user:bob")).name == "staging" && upTo [ "environment" ] (scope "fleet:main") == null;
    graph-query = lib.length r.graph.scopes == lib.length r.scopes;

    # ── sini ──
    k3s-cluster-only = lib.sort (a: b: a < b) (on "k3s") == [ web1 web2 ];
    k3s-discovery = out.k8sManifests.axon.applications.k3s.nodes == [ "10.0.1.10" "10.0.1.11" ] && out.k8sManifests.axon.target.branch == "main";
    k3s-bootstrap = nixosAt web1 [ "services" "k3s" "clusterInit" ] == [ true ] && nixosAt web1 [ "services" "k3s" "serverAddr" ] == [ ]
      && nixosAt web2 [ "services" "k3s" "serverAddr" ] == [ "https://10.0.1.10:6443" ];
    acl-sso-only = red "idm-users" P == [ "dana" ] && !lib.any (s: s.kind == "user" && s.name == "dana") r.scopes;
    acl-host-grants = scope "${web2}/user:bob" == null
      && lib.any (s: s.id == "${web2}/user:bob") (with' ({ sven, ... }: { sven.host.web-2.grants = [ sven.group.deploy ]; })).scopes;
    acl-host-gates = scope "${lb}/user:alice" != null
      && !lib.any (s: s.id == "${lb}/user:alice") (with' ({ sven, ... }: { sven.host.lb.gates = [ sven.group.deploy ]; })).scopes;
    inference-allow = nixosAt lb [ "environment" "etc" "inference/allow" "text" ] == [ "10.0.1.10\n10.0.2.10\n" ];
    inference-no-address = hasMsg (with' ({ sven, ... }: { sven.host.web-2.settings.inference.clients = [ "ghost" ]; })) ".*client ghost has no address.*";
    guard-named-host = out.k8sManifests.axon.applications.guard.hub == "alice@lb";
    join-upstreams = out.k8sManifests.axon.applications.gateway.listeners == [ "web-1.example.org" ];
    join-env-scoped = (with' ({ sven, ... }: { sven.aspects.stage-up = { at = sven.host.stage; served-domains = [ "stage.example.org" ];
      gateway-upstreams = { address = "10.0.2.10"; exclude = [ ]; }; }; })).flake.k8sManifests.axon.applications.gateway.listeners == [ "web-1.example.org" ];
    guest-intent-parent = nixosAt stage [ "environment" "etc" "vfio/ids" "text" ] == [ "10de:2203" ] && !r.active.vfio.${lb}
      && (let r2 = with' ({ sven, ... }: { sven.guest.gpu = { environment = sven.environment.prod; channel = sven.channel.stable; system = sven.system.x86_64-linux;
        addr = "10.0.1.30"; on = sven.host.lb; passthrough = [ "1002:744c" ]; }; });
        vf = id: lib.filter (v: v != null) (map (lib.attrByPath [ "environment" "etc" "vfio/ids" "text" ] null) (list (r2.reduced.nixos.${id} or null)));
      in vf stage == [ "10de:2203" ] && vf lb == [ "1002:744c" ]);
    factories = map (z: "${z.account}:${z.zone}") (red "dns-zones" "fleet:main") == [ "api:api.example.org" "json64:example.org" ]
      || map (z: "${z.account}:${z.zone}") (red "dns-zones" "fleet:main") == [ "json64:example.org" "api:api.example.org" ];
    unit-check-stand-in = out.checks.x86_64-linux ? guard-pod && red "unit-checks" "fleet:main" == { guard-pod = true; };
    one-edge = hasMsg (with' ({ sven, ... }: { sven.environment.staging.dns.publicIPv4 = "198.51.100.1"; })) "dns: 2 environments set dns.publicIPv4.*";
    ingest-across-envs = nixosAt web1 [ "environment" "etc" "alloy/endpoints" "text" ] == [ "https://ingest.example.org\n" ] && nixosAt stage [ "environment" "etc" "alloy/endpoints" "text" ] == [ "" ];
    domains-records = map (e: e.value.name) (red "dns-records" "fleet:main") == [ "example.org" ] && lib.length (red "certificate-domains" "fleet:main") == 3;
    terranix-conditional = out ? terranixConfigurations.dns-prod && !(out.terranixConfigurations ? dns-staging);
    unifi-forwards = out.unifiTerranixModules.prod != [ ] && lib.length (red "port-forwards" P) == 1;
    home-linux = r.reduced.homeLinux ? "${lb}/user:alice" && !(r.reduced.homeLinux ? "${studio}/user:alice") && !(r.reduced.homeLinux ? "${laptop}/user:alice");
    primary-user = on "primary-user" == [ "${lb}/host:lb-minimal/user:alice" "${lb}/user:alice" ];
    syncthing-hub = on "syncthing-hub" == [ stage ] && names (nixosAt stage [ "services" "syncthing" "settings" "folders" ]) == [ "alice-home" "bob-home" ];
    syncthing-peers = first (hmAt "${lb}/user:alice" [ "home" "file" ".syncthing-peers" "text" ]) == builtins.toJSON [ "lb-minimal" "web-1" "web-2" "ci" "alice@stage" "stage" ]; # scope order: guest:ci and home:alice@stage sort before user:alice
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
    den-ids = nixosAt lb [ "services" "openssh" "ports" ] == [ [ 2200 ] ] && nixosAt web2 [ "services" "openssh" "ports" ] == [ [ 2204 ] ];
    den-module-outside = lib.isList (red "nixos" lb) && lib.length (red "nixos" lb) > 10; # moduleOf: a query gives the module list
    den-nested-groups = lib.length (lib.filter (s: s.kind == "user" && s.name == "alice") r.scopes) == 10;
    den-739-home-on-host = edge "homeManager" "${stage}/home:alice@stage/user:alice" "${stage}/home:alice@stage"
      && hmAt "${stage}/home:alice@stage" [ "home" "sessionVariables" "MONITORRES" ] == [ "2560x1440" ]
      && hmAt "${stage}/user:alice" [ "home" "sessionVariables" "MONITORRES" ] == [ ];
    den-739-not-in-host-hm = !(edge "os" "${stage}/home:alice@stage/user:alice" stage);

    # ── swarsel ──
    swarsel-variant = scope "${lb}/host:lb-minimal" != null && !r.active.haproxy."${lb}/host:lb-minimal" && out.nixosConfigurations ? lb-minimal;
    swarsel-nodes = let xs = id: map (m: m.networking.extraHosts or null) (lib.concatLists (nixosAt id [ "imports" ])); in lib.elem "10.0.1.1 lb.internal" (xs web1) && !(lib.elem "10.0.1.1 lb.internal" (xs stage));
    swarsel-globals = (first (nixosAt lb [ "networking" "hosts" ])).${"10.0.1.10"} == [ "web-1.fleet" ];
    swarsel-export = lib.length out.nixosModules.base.imports == 2;

    # ── sini mesh, adda, vix ──
    sini-mesh-peers = map (p: p.endpoint) (first (nixosAt web1 [ "networking" "wireguard" "interfaces" "mesh" "peers" ])) == [ "10.0.1.1:51820" "10.0.1.11:51820" ];
    sini-nix-builders = first (nixosAt lb [ "nix" "buildMachines" ]) == [ { hostName = "10.0.1.10"; system = "x86_64-linux"; } ] && first (nixosAt web1 [ "nix" "buildMachines" ]) == [ ];
    adda-caddy = names (nixosAt lb [ "services" "caddy" "virtualHosts" ]) == [ "grafana.example.org" "status.example.org" ];
    adda-templates = out.templates.default.description == "A sven fleet";
    vix-vim-features = red "vim" "${"fleet:main/system:x86_64-linux"}/vim:dev" == [ "vim.o.number = true" "require('gitsigns').setup()" "vim.lsp.enable('nixd')" "vim.cmd.colorscheme('tokyonight')" ]
      && red "vim" "fleet:main/system:x86_64-linux/vim:min" == [ "vim.o.number = true" ] && out.packages.x86_64-linux ? vim-dev;
    vix-secrets = map (s: s.name) (red "secrets" "${stage}/user:bob") == [ "gh-token" "gpg-key" ] && map (s: s.name) (red "secrets" "${lb}/user:alice") == [ "gh-token" ];

    # ── checks derived from the infra ──
    ci-matrix = map (j: j.name) out.ci.matrix == [ "alice-laptop" "alice@stage" "devshell-aarch64-darwin" "devshell-aarch64-linux" "devshell-x86_64-linux" "lb" "stage" "studio" "web-1" "web-2" ];
    infra-facts = lib.attrNames (red "infra" "fleet:main").lb == [ "hostname" "persist /home/alice/.local/state/syncthing" ] && lib.attrNames (red "infra" "fleet:main").web-1 == [ "hostname" "nginx" "persist /home/alice/.local/state/syncthing" "persist /var/lib/nginx" "port80" ];

    # ── Den CI capabilities (templates/ci/modules) ──
    den-batteries = osAt stage [ "services" "getty" "autologinUser" ] == [ ] && osAt ci [ "services" "getty" "autologinUser" ] == [ "bob" ]
      && osAt stage [ "nixpkgs" "config" "permittedInsecurePackages" ] == [ [ "olm-3.2.16" ] ]
      && r.active.global-pkgs.${lb} && !r.active.global-pkgs."fleet:main/environment:prod/cluster:axon";
    den-chained-forward = edge "git" "${lb}/user:alice" "${lb}/user:alice" && gave "sink git" "homeManager" "${lb}/user:alice" && gave "sink homeManager" "os" lb;
    den-custom-class-no-hm = gave "sink maid" "os" "${stage}/user:bob" == false && gave "sink maid" "os" stage && !(gave "sink maid" "os" lb) && !(gave "sink maid" "os" studio); # maid: linux only, never darwin
    den-609-host-hm-no-leak = msgs (with' ({ sven, ... }: { sven.aspects.host-hm = { at = sven.host.lb; homeManager.programs.htop.enable = true; }; })) == []
      && !(lib.any (e: e.origin == "aspect host-hm") (with' ({ sven, ... }: { sven.aspects.host-hm = { at = sven.host.lb; homeManager.programs.htop.enable = true; }; })).graph.edges);
    den-projected-has-aspect = gave "aspect dev" "os" lb && gave "aspect dev" "homeManager" "${lb}/user:alice" && !(gave "aspect desktop" "nixos" ci);
    den-525-structure-from-presence = map (s: s.id) (lib.filter (s: s.kind == "backup") r.scopes) == [ "${lb}/backup:nightly" "${web1}/backup:nightly" "${web2}/backup:nightly" ]
      && nixosAt lb [ "services" "restic" "backups" "nightly" "paths" ] == [ [ "/persist" "/etc/lb" ] ];
    den-instance-side-include = r.active.desktop.${stage} && r.active.motd."fleet:main/export:base";
    den-permutation-stable = let
        rev = sven.eval { imports = lib.reverseList (import ./_modules-list.nix); _module.args = { inherit inputs lib; }; };
        j = q: builtins.toJSON (map (k: q.reduced.${k}) [ "persist" "backends" "records" "tags" "vim" "secrets" "ci" ]);
      in j rev == j r && map (s: s.id) rev.scopes == map (s: s.id) r.scopes;
    den-sibling-laziness = let p = with' ({ sven, ... }: { sven.aspects.poison = { at = sven.host.web-2; nixos = throw "poisoned web-2"; }; }); in
      lib.length p.reduced.nixos.${lb} > 0 && !(builtins.tryEval (builtins.deepSeq p.reduced.nixos.${web2} true)).success;

    # ── Den CI usage patterns (vic/den-patterns.md) ──
    den-cartesian-and-transitive = lib.sort (a: b: a < b) (red "pairs" stage) == [ "alice-fido" "alice-rex" "bob-fido" "bob-rex" "rex/ball" "rex/bone" ] && red "pairs" lb == null;
    den-user-classes = gave "sink maid" "os" stage && !(r.reduced.maid ? "${stage}/user:alice");
    den-enrichment-sinks = red "isNixos" lb == true && red "platform" lb == "linux" && nixosAt lb [ "environment" "variables" "PLATFORM" ] == [ "linux" ];
    den-user-packages-per-system = lib.all (n: out.packages.x86_64-linux ? ${n}) [ "sw-lb-alice" "sw-stage-bob" "sw-web-1-alice" ];
    den-opt-in-projection = hmAt "${stage}/user:alice" [ "home" "sessionVariables" "HMVALS" ] == [ "user" ] && hmAt "${stage}/user:alice" [ "home" "sessionVariables" "HOST_ENV" ] == [ "staging" ] && hmAt "${stage}/user:bob" [ "home" "sessionVariables" "HMVALS" ] == [ ];
    den-pipeline-stage = nixosAt lb [ "networking" "firewall" "allowedTCPPorts" ] == [ [ 80 ] ] && lib.length (red "fw" lb) == 2;
    den-one-class-two-systems = gave "sink both" "os" stage && gave "sink both" "homeManager" "${stage}/user:bob";
    den-broadcast = let p = first (nixosAt lb [ "environment" "etc" "peers" "text" ]); in lib.hasInfix "bob@stage" p && !(lib.hasInfix "alice@lb," p) && !(lib.hasSuffix "alice@lb" p);
    den-producer-own-config = hmAt "${stage}/user:alice" [ "home" "sessionVariables" "DEV" ] == [ "h:stage" ];
    # ── den-hoag (Den + Gen) capabilities ──
    hoag-settings-authority = (red "aspect-settings" web1).nginx == { gzip = true; workers = 8; } && (red "aspect-settings" web2).nginx.workers == 4
      && (red "aspect-settings" stage).nginx == { gzip = false; workers = 1; };
    hoag-settings-conflict = hasMsg (with' ({ sven, ... }: { sven.aspects.t2 = { at = sven.host.web-1; aspect-settings = { rank = 2; set.nginx.workers = 9; }; }; })) "aspect-settings: two layers of rank 2 disagree";
    hoag-ci-strategies = (red "tuning" lb).value == { ports = [ 22 80 443 ]; color = "blue"; accent = "blue"; }
      && (red "tuning" stage).value.ports == [ 22 ] && map (p: p.rank) (red "tuning" lb).provenance.ports == [ 0 1 2 ];
    hoag-ci-claim-dedup = red "token-claims" "fleet:main" == { apitoken.sharers = [ "web-1" "web-2" ]; metrics.sharers = [ "web-1" ]; };
    hoag-ci-lockdown = nixosAt lb [ "environment" "etc" "db/lockdown" "text" ] == [ "web-2" ] && nixosAt stage [ "environment" "etc" "db/lockdown" "text" ] == [ "" ];
    hoag-ci-route-split = red "secret-claims" "fleet:main" == { api.by = "web-1"; } && red "connect-claims" "fleet:main" == { api.by = "web-1"; };
    hoag-ci-demand-cascade = lib.sort (a: b: a < b) (map (s: s.id) (lib.filter (s: lib.elem s.kind [ "database" "secret" "connect" ]) r.scopes)) == [
      "fleet:main/database:audit" "fleet:main/database:audit/connect:audit-url" "fleet:main/database:audit/secret:audit-pw"
      "fleet:main/database:orders" "fleet:main/database:orders/connect:orders-url" "fleet:main/database:orders/secret:orders-pw"
      "fleet:main/database:users" "fleet:main/database:users/connect:users-url" "fleet:main/database:users/secret:users-pw" ]
      && (scope "fleet:main/database:orders").by == [ "web-1" "web-2" ];
    hoag-ci-visible = out.visibleMotd == { a = "w1"; b = "w2"; w = "w1"; };
    hoag-ci-suppress-chain = map (a: r.active.${a}.${lb}) [ "sup-a" "sup-b" "sup-c" "sup-d" ] == [ true false true false ];
    hoag-ci-class-share-per-class = out.classShare ? nixos && !(out.classShare ? homeManager);
    hoag-claims-reverse-read = first (nixosAt lb [ "services" "postgresql" "ensureDatabases" ]) == [ "app_web_1" "app_web_2" ]
      && first (nixosAt stage [ "services" "postgresql" "ensureDatabases" ]) == [ "app_stage" ] && first (nixosAt web1 [ "services" "postgresql" "ensureDatabases" ]) == null
      && first (nixosAt web1 [ "environment" "etc" "app/database-url" "text" ]) == "postgres://10.0.1.1/app_web_1";
    hoag-collectors = lib.attrNames out.colmenaHives.prod == [ "lb" "meta" "web-1" "web-2" ] && lib.attrNames out.colmenaHives.staging == [ "meta" "stage" ]
      && out.colmenaHives.staging.meta.allowApplyAll;
    hoag-query-layers = out.deployWaves == [ [ "lb" ] [ "web-1" "web-2" ] [ "stage" ] ] && out.dependents.lb == [ "web-1" "web-2" ] && out.dependents.stage == [ ];
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
      den-739-standalone-home = out.homeConfigurations."alice@stage".config.home.sessionVariables.MONITORRES == "2560x1440";
      infra-lb-passes = out.checks.x86_64-linux.infra-lb.drvAttrs.buildCommand == "touch $out";
      infra-lb-drift-fails = lib.hasInfix "networking.hostName" (with' { sven.aspects.drift = { at = { kind = "host"; name = "lb"; }; nixos = { lib, ... }: { networking.hostName = lib.mkForce "drifted"; }; }; }).flake.checks.x86_64-linux.infra-lb.drvAttrs.buildCommand;
      den-enrichment-built = lbCfg.environment.variables.PLATFORM == "linux" && lib.hasInfix "bob@stage" lbCfg.environment.etc.peers.text && lib.elem 80 lbCfg.networking.firewall.allowedTCPPorts && !(lib.elem 53 lbCfg.networking.firewall.allowedTCPPorts); # 2200 is ssh-port
      den-producer-own-config-built = out.homeConfigurations."alice@stage".config.home.sessionVariables.HOST_DESKTOP == "yes";
      hoag-class-share-gate = out.classShare.nixos.members.lb.gate && out.classShare.nixos.coreSize > 0 && out.classShare.nixos.members.lb.deltaSize < out.classShare.nixos.members.lb.fullSize;
      hoag-class-share-tampered-core-fails = let cs = out.classShare.nixos; bad = inputs.nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [ { imports = cs.core ++ [ { networking.domain = "tampered"; } ]; } ] ++ cs.members.lb.delta; }; in bad.config.system.build.toplevel.drvPath != lbCfg.system.build.toplevel.drvPath;
      den-713-home-reads-host-config = out.homeConfigurations."alice@stage".config.home.sessionVariables.HOST_DESKTOP == "yes";
      hoag-claims-built = lib.elem "app_web_1" out.nixosConfigurations.lb.config.services.postgresql.ensureDatabases;
      den-chained-forward-built = out.nixosConfigurations.lb.config.home-manager.users.alice.programs.git.extraConfig.init.defaultBranch == "main"; # lb: stable channel, HM 25.05
      lb-minimal-built = lib.hasSuffix ".drv" out.nixosConfigurations.lb-minimal.config.system.build.toplevel.drvPath && !out.nixosConfigurations.lb-minimal.config.services.haproxy.enable;
      export-module = (inputs.nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [ out.nixosModules.base { boot.loader.grub.device = "nodev"; fileSystems."/".device = "x"; system.stateVersion = "25.05"; } ]; }).config.environment.etc.motd.text == "managed by sven";
    };
    failed = lib.filter (n: !checks.${n}) (lib.attrNames checks);
  };
in
{
  inherit checks e2e;
  failed = lib.filter (n: !checks.${n}) (lib.attrNames checks);
}
