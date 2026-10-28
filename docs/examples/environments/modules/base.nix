# Settings cascade: the host, then its environment, then the environment's base.
{ sven, ... }:
let
  setting = path: host: sven.lib.cascade path [ host host.environment (host.environment.base or null) ];
in
{
  sven.aspects.base = {
    at = sven.kinds.host;
    nixos = { host, environment, ... }: {
      networking = { hostName = host.name; domain = environment.domain; };
      time.timeZone = setting [ "settings" "timeZone" ] host;
      boot.loader.grub.device = "nodev";
      fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
  sven.aspects.time-zones = {
    at = sven.kinds.host;
    out = { host, ... }: { timeZones.${host.name} = setting [ "settings" "timeZone" ] host; }; # goes up to the fleet
  };
  sven.aspects.account = {
    at = sven.kinds.user;
    nixos = { user, ... }: { users.users.${user.name}.isNormalUser = true; };
  };
}
