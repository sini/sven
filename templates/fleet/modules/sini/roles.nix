# Tags from active role aspects (hasAspect = `holds`). A host profile does not reach the host's guests (#67).
{ sven, lib, ... }:
let
  inherit (sven.lib) holds;
in
{
  sven.kinds.host.sinks.tags = {
    of = lib.types.str;
    reduce = sven.lib.reduce.set;
    colmena = { host, scope, tags, ... }: {
      ${host.name}.deployment.tags = [ host.environment.name ] ++ tags ++ lib.filter (n: holds sven.aspects."role-${n}" scope) [ "server" "workstation" "laptop" ];
    };
  };
  sven.aspects.role-server = { at = [ sven.host.lb sven.host.web-1 sven.host.web-2 ]; tags = "server"; };
  sven.aspects.role-workstation.at = sven.host.stage;
  sven.aspects.role-laptop.at = sven.host.stage;
  sven.aspects.thermald = { at = sven.aspects.role-laptop; nixos.services.thermald.enable = true; };
  sven.aspects.profile-workstation.at = sven.host.stage;
  sven.aspects.desktop.at = [ sven.aspects.profile-workstation ]; # `at` from two files is a union; ci, stage's guest, gets nothing
}
