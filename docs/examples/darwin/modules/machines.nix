{ sven, ... }:
{
  sven.host.server = { };
  sven.mac.studio = { };

  sven.aspects.server = {
    at = sven.host.server;
    nixos = {
      boot.loader.grub.device = "nodev";
      fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
  sven.aspects.studio = {
    at = sven.mac.studio;
    darwin = { nixpkgs.hostPlatform = "aarch64-darwin"; system.stateVersion = 6; };
  };
}
