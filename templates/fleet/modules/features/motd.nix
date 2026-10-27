# substitute: motd-short replaces motd on web-2 through `not`.
{ sven, ... }:
let
  inherit (sven.lib) all not;
in
{
  sven.aspects.motd = { at = all [ sven.helpers.machines (not sven.aspects.motd-short) ]; os.environment.etc.motd.text = "managed by sven"; };
  sven.aspects.motd-short = { at = sven.host.web-2; os.environment.etc.motd.text = "sven"; };
}
