# Behavior: active at every host, gives one NixOS module to the `nixos` sink.
{ sven, ... }:
{
  sven.aspects.base = {
    at = sven.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name;
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      };
  };

  sven.aspects.motd = {
    at = sven.host.laptop;
    nixos.environment.etc.motd.text = "managed by sven";
  };
}
