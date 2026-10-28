# sini services: SSO identities per environment, a provider allow-list joined from fleet pools,
# and a cluster aspect that reads a named host.
{ sven, lib, ... }:
let
  inherit (sven.lib) all opt;
  inherit (sven.lib.reduce) entries;
  named = n: lib.filter (e: e.value.name == n);
in
{
  # Users whose oauth groups meet the environment's grants: identities only, no unix account (helpers.usersOn).
  sven.kinds.environment.sinks.idm-users.reduce = sven.lib.reduce.one;
  sven.aspects.idm = {
    at = sven.kinds.environment;
    idm-users =
      { environment, ... }:
      lib.attrNames (
        lib.filterAttrs (
          _: u:
          sven.helpers.meets (lib.filter (g: g.label == "oauth") (
            sven.helpers.closure u.groups
          )) environment.grants
        ) sven.user
      );
  };

  # ninfer: the provider admits named hosts (by the fleet address pool) and every host whose aspects include the client.
  # A named host with no address is an error, not a silent gap.
  sven.kinds.machine.fields.settings.inference.clients = opt (sven.helpers.listOf lib.types.str) [ ];
  sven.host.lb.settings.inference.clients = [ "web-1" ];
  sven.kinds.fleet.sinks = {
    host-addrs.reduce = entries;
    inference-clients.reduce = entries;
  };
  sven.aspects.host-addrs = {
    at = sven.kinds.host;
    host-addrs =
      { host, ... }:
      {
        inherit (host) name addr;
      };
  };
  sven.aspects.inference-client = {
    at = sven.aspects.role-workstation;
    inference-clients = { host, ... }: host.addr;
  };
  sven.aspects.inference = {
    at = all [
      sven.kinds.host
      (s: s.settings.inference.clients != [ ])
    ];
    nixos =
      {
        host,
        host-addrs,
        inference-clients,
        ...
      }:
      {
        environment.etc."inference/allow".text = lib.concatLines (
          lib.unique (
            lib.concatMap (n: map (e: e.value.addr) (named n host-addrs)) host.settings.inference.clients
            ++ map (e: e.value) inference-clients
          )
        );
      };
    errors =
      { host, host-addrs, ... }:
      map (n: "inference: client ${n} has no address") (
        lib.filter (n: named n host-addrs == [ ]) host.settings.inference.clients
      );
  };

  # A cluster aspect reads a named host directly: the hub is lb's system owner.
  sven.aspects.guard = {
    at = sven.cluster.axon;
    k8s-manifests =
      { cluster, ... }:
      lib.optionalAttrs cluster.settings.guard.enable {
        applications.guard.hub = "${sven.host.lb.system-owner.name}@lb";
      };
  };
}
