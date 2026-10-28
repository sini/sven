# Fleet invariants: Datalog rules over the fleet's facts (`kind:K:ID`, `has:ASPECT:ID`, `edge:SINK:FROM:TO`,
# `error:CODE:FROM`). A true `bad:` atom is a violation, an undefined one an incomplete answer. An agent reads
# `check` (nix eval --file query.nix check) before and after a change; `stage` refuses a change that adds a violation.
{ lib, ... }:
let
  machines = s: lib.elem s.kind [ "host" "mac" "guest" ];
in
{
  sven.invariants = {
    # every machine has the base aspect (hostname, overlays)
    base = { scopes, ... }: map (s: { head = "bad:no-base:${s.id}"; pos = [ "kind:${s.kind}:${s.id}" ]; neg = [ "has:base:${s.id}" ]; }) (lib.filter machines scopes);
    # every machine is reachable for management: it runs sshd through the clan sshd instance
    ssh = { scopes, ... }: map (s: { head = "bad:no-sshd:${s.id}"; pos = [ "kind:${s.kind}:${s.id}" ]; neg = [ "has:clan-sshd:${s.id}" ]; })
      (lib.filter (s: lib.elem s.kind [ "host" "mac" ] && !(lib.hasInfix "/host:lb/host:" s.id)) scopes);
    # a host with a binary cache secret (attic) is never a mac: secrets stay on NixOS servers
    attic = { scopes, ... }: map (s: { head = "bad:attic-on-mac:${s.id}"; pos = [ "has:attic:${s.id}" ]; }) (lib.filter (s: s.kind == "mac") scopes);
  };
}
