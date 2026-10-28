# swarsel (after oddlama): distributed config. One machine writes NixOS config into another (old `nodes.<name>`),
# and every machine adds fragments to fleet-wide `globals` that any scope reads.
{ sven, lib, ... }:
{
  sven.kinds.fleet.sinks.nodes.reduce = sven.lib.reduce.entries;
  sven.kinds.fleet.sinks.globals.reduce = sven.lib.reduce.merge;
  sven.aspects.lb-writes-backends = {
    at = sven.host.lb;
    nodes = { host, ... }: lib.genAttrs [ "web-1" "web-2" ] (_: { networking.extraHosts = "${host.addr} lb.internal"; });
  };
  sven.aspects.nodes = {
    at = sven.kinds.host;
    nixos = { host, nodes, ... }: { imports = lib.concatMap (e: lib.optional (e.value ? ${host.name}) e.value.${host.name}) nodes; };
  };
  sven.aspects.globals-addr = { at = sven.lib.all [ sven.helpers.machines (s: !s.minimal) ]; globals = { scope, ... }: { hosts.${scope.name}.addr = scope.addr; }; };
  sven.aspects.globals-hosts = {
    at = sven.helpers.linux;
    nixos = { globals, ... }: { networking.hosts = lib.mapAttrs' (n: h: lib.nameValuePair h.addr [ "${n}.fleet" ]) globals.hosts; };
  };
}
