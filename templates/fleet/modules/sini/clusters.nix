# Clusters under an environment. Discovery (den collect): k3s nodes reduce at the environment; the reader filters.
{ sven, lib, ... }:
let
  inherit (sven.lib) maybe same;
  inherit (sven.lib.reduce) entries;
  clusterOf = h: lib.findFirst (c: lib.any (same h) c.hosts) null (lib.attrValues sven.cluster);
  members = c: lib.filter (e: lib.any (same e.from) c.hosts);
in
{
  sven.kinds.environment.spawns.cluster = s: lib.filterAttrs (_: c: same c.environment s) sven.cluster;
  sven.kinds.cluster = {
    fields = { environment = sven.kinds.environment; hosts = sven.helpers.listOf sven.kinds.host; ingestUrl = maybe lib.types.str; };
    sinks.k8s-manifests.out = { cluster, k8s-manifests, ... }: {
      k8sManifests.${cluster.name} = (lib.evalModules { modules = [ { freeformType = lib.types.attrsOf lib.types.anything; } ] ++ k8s-manifests; }).config;
    };
  };
  sven.cluster.axon = { environment = sven.environment.prod; hosts = [ sven.host.web-1 sven.host.web-2 ]; ingestUrl = "https://ingest.example.org"; };
  sven.aspects.axon = { at = sven.cluster.axon; k8s-manifests.target.branch = "main"; };

  sven.kinds.environment.sinks.k3s-nodes.reduce = entries;
  sven.aspects.k3s = {
    at = s: clusterOf s != null;
    k3s-nodes = { host, ... }: host.addr;
    nixos = { k3s-nodes, host, ... }: { services.k3s.enable = true; services.k3s.serverAddr = "https://${(lib.head (members (clusterOf host) k3s-nodes)).value}:6443"; };
  };
  sven.aspects.k3s-registries = {
    at = sven.kinds.cluster;
    k8s-manifests = { cluster, k3s-nodes, ... }: { applications.k3s.nodes = map (e: e.value) (members cluster k3s-nodes); };
  };

  # Across environments: reduce at the fleet, filter by a ref field.
  sven.kinds.environment.fields.monitoring = maybe sven.kinds.cluster;
  sven.environment.prod.monitoring = sven.cluster.axon;
  sven.kinds.fleet.sinks.monitoring-ingest.reduce = entries;
  sven.aspects.ingest = { at = sven.lib.all [ sven.kinds.cluster (s: s.ingestUrl != null) ]; monitoring-ingest = { cluster, ... }: cluster.ingestUrl; };
  sven.aspects.alloy = {
    at = sven.helpers.linux;
    nixos = { monitoring-ingest, environment, ... }: {
      environment.etc."alloy/endpoints".text = lib.concatLines (map (e: e.value) (lib.filter (e: environment.monitoring != null && same e.from environment.monitoring) monitoring-ingest));
    };
  };
}
