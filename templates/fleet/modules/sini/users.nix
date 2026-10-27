# homeLinux: a user sink that only users on linux machines have. Primary user: a user element that goes up to the host.
{ sven, lib, ... }:
let
  inherit (sven.helpers) linux upTo;
in
{
  sven.kinds.user.sinks.homeLinux = { at = s: lib.hasSuffix "-linux" ((upTo linux s).system.name or ""); homeManager = { homeLinux, ... }: { imports = homeLinux; }; };
  sven.aspects.linux-home = { at = sven.kinds.user; homeLinux.home.sessionVariables.SVEN_LINUX = "1"; };
  sven.kinds.machine.fields.system-owner = sven.lib.maybe sven.kinds.user;
  sven.host.lb.system-owner = sven.user.alice;
  sven.aspects.primary-user = {
    at = sven.lib.all [ sven.kinds.user (s: let h = upTo linux s; in h != null && h.system-owner != null && sven.lib.same h.system-owner s) ];
    nixos = { user, ... }: { nix.settings.trusted-users = [ user.name ]; };
  };
}
