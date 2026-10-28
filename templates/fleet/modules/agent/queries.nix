# Stored queries, labels and valid time for agents.
# - `sven.queries.<name>`: named questions with parameters; an agent lists them (`queries`) and calls `ask name args`.
# - `sven.labels`: trust by file path prefix. Content declared under modules/agent/ is trust 1 (written by agents),
#   the rest trust 3. `floor 3` lists every routed element an agent-written aspect gives.
# - valid time: a machine can have `validTo`; `retire-notice` marks machines past it at the fleet's review date.
{ sven, lib, ... }:
{
  sven.queries = {
    hostsIn =
      { env, r }:
      map (s: s.name) (
        lib.filter (s: s.kind == "host" && lib.hasInfix "/environment:${env}/" s.id) r.scopes
      );
    aspectsOn =
      { host, r }:
      let
        s = lib.findFirst (x: x.kind == "host" && x.name == host) null r.scopes;
      in
      if s == null then [ ] else lib.filter (n: r.active.${n}.${s.id}) (lib.attrNames r.active);
    errorsBy =
      {
        code ? null,
        r,
      }:
      lib.filter (e: code == null || e.code == code) r.errors;
    # clan install order: in a service instance, each client machine waits for the servers (sven.lib.graphs.layers)
    installOrder =
      { instance, r }:
      let
        ms = lib.filter (s: s.kind == "member" && lib.hasPrefix "${instance}." s.name) r.scopes;
        role = rl: lib.unique (map (s: s.parent.name) (lib.filter (s: lib.hasSuffix ".${rl}" s.name) ms));
        servers = role "server";
      in
      sven.lib.graphs.layers (
        lib.genAttrs (role "client" ++ servers) (m: if lib.elem m servers then [ ] else servers)
      );
  };
  sven.labels = {
    "modules/" = {
      trust = 3;
    };
    "agent/" = {
      trust = 1;
    };
  };

  sven.kinds.machine.fields.validTo = sven.lib.opt (sven.helpers.listOf lib.types.str) [ ];
  sven.host.web-2.validTo = [ "2026-11-01" ];
  sven.aspects.retire-notice = {
    at = sven.lib.all [
      sven.kinds.host
      (s: s.validTo != [ ])
      (sven.lib.not (s: sven.lib.validAt "2026-11-15" (s // { validTo = lib.head s.validTo; })))
    ];
    nixos.environment.etc."sven/retired".text = "past validTo at the review date 2026-11-15";
  };
}
