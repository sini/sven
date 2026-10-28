# The service: an aspect per role, at member scopes. Clients export their address; the server reads them.
{ sven, lib, ... }:
let
  role = r: sven.lib.all [ sven.kinds.member (s: s.instance == "backup" && s.role == r) ];
in
{
  sven.aspects.backup-client = {
    at = role "client";
    exports = { host, ... }: host.addr; # published by the member scope: the engine sets `from`
    config = { host, ... }: { backup.target = sven.host.nas.addr; backup.name = host.name; };
  };
  sven.aspects.backup-server = {
    at = role "server";
    config = { exports, ... }: { backup.allow = lib.sort (a: b: a < b) (map (e: e.value) (lib.filter (e: e.from.kind == "member") exports)); };
  };
  # once per machine that takes part in any role of the service
  sven.aspects.backup-tools = {
    at = sven.lib.has (s: s.kind == "member" && s.instance == "backup");
    config.packages = [ "borgbackup" ];
  };
}
