# Tags: a set per host; nixos.colmena adds the environment and the active role aspects. A host profile does not reach the host's guests (#67).
{ sven, lib, ... }:
{
  sven.kinds.host.sinks.tags = { of = lib.types.str; reduce = sven.lib.reduce.set; };
  sven.aspects.role-server.at = [ sven.host.lb sven.host.web-1 sven.host.web-2 ];
  sven.aspects.role-workstation.at = sven.host.stage;
  sven.aspects.role-laptop.at = sven.host.stage;
  sven.aspects.thermald = { at = sven.aspects.role-laptop; nixos.services.thermald.enable = true; };
  sven.aspects.profile-workstation.at = sven.host.stage;
  sven.aspects.desktop.at = [ sven.aspects.profile-workstation ]; # `at` from two files is a union; ci, stage's guest, gets nothing
}
