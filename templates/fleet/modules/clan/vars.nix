# clan vars, the configuration half: services declare generators; generation itself is a tool, not sven.
# A shared generator is one for all machines; a per-machine one is keyed by machine. A dependency must name a
# generator the same machine has (or a shared one). Public values are read at eval time from the repo, with a default.
# Machines from directories: machines/<name>/configuration.nix joins that machine's config (clan autoincludes).
{ sven, lib, ... }:
let
  inherit (sven.lib) all has;
  machineOf = s: if s.kind == "member" then s.parent else s;
  keyOf = g: if g.share or false then g.name else "${g.name}@${g.machine}";
  publicValue = m: gen: file: default:
    let p = ../../vars/per-machine + "/${m}/${gen}/${file}/value"; in if builtins.pathExists p then lib.removeSuffix "\n" (builtins.readFile p) else default;
in
{
  sven.kinds.fleet.sinks.generators.reduce = es:
    let
      gs = map (e: e.value // { machine = (machineOf e.from).name; }) es;
      byKey = lib.listToAttrs (map (g: lib.nameValuePair (keyOf g) (removeAttrs g [ "machine" ] // lib.optionalAttrs (!(g.share or false)) { inherit (g) machine; })) gs);
      missing = lib.concatMap (g: map (d: { error = "vars: generator ${keyOf g} depends on ${d}, which ${g.machine} has not"; from = "fleet:main"; })
        (lib.filter (d: !(byKey ? ${d} || byKey ? "${d}@${g.machine}")) (g.dependencies or [ ]))) gs;
    in { value = byKey; errors = missing; };

  sven.aspects.vars-openssh = {
    at = all [ sven.helpers.machines (has (s: s.service or null == "sshd")) ];
    generators = { scope, ... }: { files = { "ssh.id_ed25519".secret = true; "ssh.id_ed25519.pub".secret = false; }; name = "openssh"; }; # a function: one per machine (static content goes once per receiver)
    os = { scope, ... }: { environment.etc."ssh/host-key.pub".text = publicValue scope.name "openssh" "ssh.id_ed25519.pub" "absent"; };
  };
  sven.aspects.vars-wifi = { at = all [ sven.kinds.member (s: s.service == "wifi") ]; generators = { name = "wifi.home"; share = true; files.password.secret = true; }; };
  sven.aspects.vars-borg = {
    at = all [ sven.kinds.member (s: s.service == "borg" && s.role == "client") ];
    generators = { member, ... }: { name = "borg-${member.instance}"; dependencies = [ "openssh" ]; files.passphrase.secret = true; };
  };

  sven.aspects.autoinclude = {
    at = all [ sven.kinds.host (s: builtins.pathExists (../../machines + "/${s.name}/configuration.nix")) ];
    nixos = { host, ... }: { imports = [ (../../machines + "/${host.name}/configuration.nix") ]; };
  };
}
