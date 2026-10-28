# sini mesh family (vault, thunderbolt, ollama, nix-builders): every host in an environment gives one record;
# each host reads its environment's records and drops its own. The filter lives with the reader.
{ sven, lib, ... }:
let
  peersOf = host: es: lib.filter (e: !(sven.lib.same e.from host)) es;
in
{
  sven.kinds.environment.sinks.mesh-peers.reduce = sven.lib.reduce.entries;
  sven.kinds.machine.fields.builder = sven.lib.opt lib.types.bool false;
  sven.host.web-1.builder = true;
  sven.aspects.mesh = {
    at = sven.lib.all [ sven.kinds.host (s: !s.minimal) ];
    mesh-peers = { host, ... }: { inherit (host) addr builder; };
    nixos = { host, mesh-peers, ... }:
      let peers = peersOf host mesh-peers; in
      {
        networking.wireguard.interfaces.mesh = {
          ips = [ "${host.addr}/32" ];
          privateKeyFile = "/run/agenix/wg-mesh"; # a path only: the key never enters the store
          peers = map (e: { publicKey = builtins.hashString "sha256" e.from.name; allowedIPs = [ "${e.value.addr}/32" ]; endpoint = "${e.value.addr}:51820"; }) peers;
        };
        nix.buildMachines = map (e: { hostName = e.value.addr; system = "x86_64-linux"; }) (lib.filter (e: e.value.builder) peers);
      };
  };
}
