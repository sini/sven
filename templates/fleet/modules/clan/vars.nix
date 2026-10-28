# clan vars, the configuration half: services declare generators; generation itself is a tool, not sven.
# A shared generator is one for all machines that use it; a per-machine one is keyed by machine. A dependency must
# name a generator the same machine has (or a shared one). A null element gives nothing. The plan per machine
# (paths by `neededFor`, generation order) is data. Public values are read at eval time from the repo, with a
# default; a read of a secret file is an error. Machines come from directories too (clan autoincludes).
{ sven, lib, ... }:
let
  inherit (sven.lib) all has opt maybe;
  machineOf = s: if s.kind == "member" then s.parent else s;
  keyOf = g: if g.share or false then g.name else "${g.name}@${g.machine}";
  publicValue = m: gen: file: default:
    let p = ../../vars/per-machine + "/${m}/${gen}/${file}/value"; in if builtins.pathExists p then lib.removeSuffix "\n" (builtins.readFile p) else default;
  pathOf = gen: file: f: "/run/${if f.neededFor or "services" == "users" then "secrets-for-users" else "secrets"}/vars/${gen}/${file}";
  machineNames = lib.attrNames sven.host ++ lib.attrNames sven.mac;
in
{
  sven.kinds.fleet.sinks.generators = {
    reduce = es:
      let
        gs = map (e: e.value // { machine = (machineOf e.from).name; }) (lib.filter (e: e.value != null) es);
        byKey = lib.mapAttrs (_: xs: removeAttrs (lib.head xs) [ "machine" ] // { machines = lib.unique (map (g: g.machine) xs); })
          (lib.groupBy keyOf gs);
        missing = lib.concatMap (g: map (d: { error = "vars: generator ${keyOf g} depends on ${d}, which ${g.machine} has not"; from = "fleet:main"; })
          (lib.filter (d: !(byKey ? ${d} || byKey ? "${d}@${g.machine}")) (g.dependencies or [ ]))) gs;
      in { value = byKey; errors = missing; };
    # the plan per machine: secret files with their path, and the order to generate in (dependencies first)
    out = { generators, ... }: {
      varsPlan = lib.genAttrs machineNames (m:
        let mine = lib.filterAttrs (_: g: lib.elem m g.machines) generators; in {
          files = lib.concatLists (lib.mapAttrsToList (_: g: lib.mapAttrsToList (f: d: { generator = g.name; file = f; path = pathOf g.name f d; neededForUsers = d.neededFor or null == "users"; })
            (lib.filterAttrs (_: d: (d.secret or true) && (d.deploy or true)) (g.files or { }))) mine);   # deploy = false: never on the machine (a root CA key)
          recipients = let r = sven.fleet.main.recipients; in r.hosts.${m} or r.default;   # a host list replaces the default, never adds to it
          order = (lib.toposort (a: b: lib.elem a.name (b.dependencies or [ ])) (lib.attrValues mine)).result or [ ];
        });
    };
  };
  sven.kinds.fleet.sinks.public-reads.reduce = sven.lib.reduce.entries;
  sven.kinds.fleet.fields.secretStore = opt (sven.helpers.enum [ "sops" "age" "password-store" ]) "sops";
  sven.kinds.fleet.fields.recipients = opt (sven.lib.is lib.isAttrs) { default = [ ]; hosts = { }; };
  sven.fleet.main.recipients = { default = [ "age1admin" ]; hosts.lb = [ "age1lb" "age1admin" ]; };
  sven.kinds.machine.fields.secretStore = maybe (sven.helpers.enum [ "sops" "age" "password-store" ]);
  sven.aspects.vars-guard = {
    at = sven.kinds.fleet;
    errors = { fleet, generators, public-reads, ... }:
      map (r: "vars: ${r.value.machine} reads ${r.value.generator}/${r.value.file}, a secret file") (lib.filter (r:
        lib.any (g: lib.elem r.value.machine g.machines && g.name == r.value.generator && (g.files.${r.value.file}.secret or true)) (lib.attrValues generators)) public-reads)
      ++ map (m: "vars: ${m.name} uses secret store ${m.secretStore}, the fleet uses ${fleet.secretStore}")
        (lib.filter (m: m.secretStore != null && m.secretStore != fleet.secretStore) (lib.attrValues sven.host ++ lib.attrValues sven.mac))
      ++ lib.concatMap (g: lib.optional (lib.any (m: sven.mac ? ${m}) g.machines && lib.any (d: d ? restartUnits) (lib.attrValues (g.files or { })))
        "vars: ${g.name}: restartUnits is NixOS only, a darwin machine uses it") (lib.attrValues generators);
  };

  sven.aspects.vars-openssh = {
    at = all [ sven.helpers.machines (has (s: s.service or null == "sshd")) ];
    generators = { scope, ... }: { files = { "ssh.id_ed25519".secret = true; "ssh.id_ed25519.pub".secret = false; }; name = "openssh"; }; # a function: one per machine (static content goes once per receiver)
    public-reads = { scope, ... }: { machine = scope.name; generator = "openssh"; file = "ssh.id_ed25519.pub"; };
    os = { scope, ... }: { environment.etc."ssh/host-key.pub".text = publicValue scope.name "openssh" "ssh.id_ed25519.pub" "absent"; };
  };
  sven.aspects.vars-wifi = { at = all [ sven.kinds.member (s: s.service == "wifi") ]; generators = { name = "wifi.home"; share = true; files = { password.secret = true; ca-key = { secret = true; deploy = false; }; }; }; };
  sven.aspects.vars-borg = {
    at = all [ sven.kinds.member (s: s.service == "borg" && s.role == "client") ];
    generators = { member, ... }: { name = "borg-${member.instance}"; dependencies = [ "openssh" ]; files.passphrase = { secret = true; neededFor = "users"; restartUnits = [ "borgbackup-job-${member.instance}.service" ]; }; };
  };
  # generators carried by an export: each machine in an export's `deploy` list gets them
  sven.aspects.vars-from-exports = {
    at = sven.helpers.machines;
    generators = { scope, exports, ... }:
      let gens = lib.concatMap (x: lib.filter (g: lib.elem scope.name g.deploy) (lib.attrValues (x.value.generators or { }))) exports; in
      if gens == [ ] then null else { name = "from-exports"; files = lib.foldl' (a: g: a // g.files) { } gens; };
  };

  # machines from directories: every directory under machines/ is a host; its configuration.nix joins the config
  sven.host = lib.mapAttrs (_: _: { labels = [ "from-dir" ]; }) (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../../machines));
  sven.aspects.autoinclude = {
    at = all [ sven.kinds.host (s: builtins.pathExists (../../machines + "/${s.name}/configuration.nix")) ];
    nixos = { host, ... }: { imports = [ (../../machines + "/${host.name}/configuration.nix") ]; };
  };
}
