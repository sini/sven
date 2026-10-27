# Broadcast to the same user elsewhere, and to a hub, with a transform (syncthing-peers, replicateHome).
{ sven, lib, ... }:
let
  inherit (sven.lib) all within same;
in
{
  sven.kinds.fleet.sinks = { syncthing-peers.reduce = sven.lib.reduce.entries; replicate-home.reduce = sven.lib.reduce.entries; };
  sven.kinds.machine.fields.settings.syncthing.isHub = sven.lib.opt lib.types.bool false;
  sven.host.stage.settings.syncthing.isHub = true;
  sven.aspects.syncthing-peer = {
    at = all [ sven.kinds.user (within sven.helpers.linux) ];
    syncthing-peers = { scope, ... }: { id = builtins.hashString "sha256" scope.parent.name; };
    replicate-home = { user, ... }: { inherit user; directories = [ "Documents" ]; };
    homeManager = { syncthing-peers, user, scope, ... }: {
      home.file.".syncthing-peers".text = builtins.toJSON (map (e: e.from.parent.name) (lib.filter (e: same e.from user && e.from.path != scope.path) syncthing-peers));
    };
  };
  sven.aspects.syncthing-hub = {
    at = all [ sven.kinds.host (s: s.settings.syncthing.isHub) ];
    nixos = { replicate-home, ... }: { services.syncthing.settings.folders = lib.listToAttrs (map (e: lib.nameValuePair "${e.value.user.name}-home" { path = "/srv/${e.value.user.name}"; }) replicate-home); };
  };
}
