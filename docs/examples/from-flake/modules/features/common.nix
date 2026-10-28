# The old common.nix and the mkHost helper, as aspects at every host.
{ sven, inputs, ... }:
{
  sven.aspects.common = {
    at = sven.kinds.host;
    nixos =
      { host, pkgs, ... }:
      {
        networking.hostName = host.name;
        boot.loader.systemd-boot.enable = true;
        time.timeZone = "UTC";
        services.openssh.enable = true;
        environment.systemPackages = [ pkgs.git ];
        system.stateVersion = "25.05";
      };
  };
  sven.aspects.home-manager = {
    at = sven.lib.has sven.kinds.user; # only hosts with users
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
    };
  };
}
