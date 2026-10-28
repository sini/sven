# sini joins and data-shaped aspects: two pools joined by host, a guest's intent read by its parent,
# aspect factories, an aspect checked alone with stand-in arguments, and one edge environment at most.
{ sven, lib, inputs, ... }:
let
  inherit (sven.lib) all opt same;
  inherit (sven.lib.reduce) entries;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  by = from: lib.filter (e: same e.from from);
  # a factory: an aspect with instance data (sini `dns.cloudflare "json64"`)
  cloudflare = account: at: { inherit at; dns-zones = { domain, ... }: { inherit account; zone = domain.name; }; };
in
{
  # served-domains ⋈ gateway-upstreams by host, in the cluster's environment; `exclude` drops names.
  sven.kinds.fleet.sinks = { served-domains.reduce = entries; gateway-upstreams.reduce = entries; dns-zones.reduce = sven.lib.reduce.list; };
  sven.aspects.served = { at = [ sven.host.web-1 sven.host.web-2 ]; served-domains = { host, ... }: [ "${host.name}.example.org" "admin.${host.name}.example.org" ]; };
  sven.aspects.gateway-upstream = { at = sven.host.web-1; gateway-upstreams = { host, ... }: { address = host.addr; exclude = [ "admin.web-1.example.org" ]; }; };
  sven.aspects.host-upstreams = {
    at = sven.kinds.cluster;
    k8s-manifests = { cluster, served-domains, gateway-upstreams, ... }: {
      applications.gateway.listeners = lib.concatMap
        (u: lib.subtractLists u.value.exclude (lib.concatMap (d: d.value) (by u.from served-domains)))
        (lib.filter (u: same u.from.environment cluster.environment) gateway-upstreams);
    };
  };

  # The guest states its passthrough devices; the parent host binds them to vfio.
  sven.kinds.guest.fields.passthrough = opt (sven.helpers.listOf lib.types.str) [ ];
  sven.guest.ci.passthrough = [ "10de:2203" ];
  sven.aspects.vfio = {
    at = all [ sven.kinds.host (s: lib.any (g: same g.on s && g.passthrough != [ ]) (lib.attrValues sven.guest)) ];
    nixos = { host, ... }: {
      environment.etc."vfio/ids".text = lib.concatStringsSep "," (lib.concatMap (g: g.passthrough) (lib.filter (g: same g.on host) (lib.attrValues sven.guest)));
    };
  };

  # Factories: one function, two instances.
  sven.aspects.cloudflare-json64 = cloudflare "json64" sven.domain."example.org";
  sven.aspects.cloudflare-api = cloudflare "api" sven.domain."api.example.org";

  # The aspect is a value: a check applies it to a stand-in cluster with the flag forced on, whatever axon sets.
  sven.kinds.cluster.fields.settings.guard.enable = opt lib.types.bool false;
  sven.cluster.axon.settings.guard.enable = true;
  sven.kinds.fleet.sinks.unit-checks = {
    reduce = sven.lib.reduce.merge;
    out = { unit-checks, ... }: {
      checks.x86_64-linux = lib.mapAttrs (n: ok: pkgs.runCommand n { } (if ok then "touch $out" else "echo ${n}: failed; exit 1")) unit-checks;
    };
  };
  sven.aspects.guard-pod = {
    at = sven.kinds.fleet;
    unit-checks.guard-pod = (sven.aspects.guard.k8s-manifests { cluster.settings.guard.enable = true; }).applications.guard.hub == "alice@lb";
  };

  # At most one environment is the DNS edge.
  sven.aspects.one-edge = {
    at = sven.kinds.fleet;
    errors = let n = lib.length (lib.filter (e: e.dns.publicIPv4 != null) (lib.attrValues sven.environment)); in
      lib.optional (n > 1) "dns: ${toString n} environments set dns.publicIPv4, at most one may";
  };
}
