{ sven, ... }:
{
  sven.host.box = { };
  sven.guest.web.on = sven.host.box;
  sven.guest.db.on = sven.host.box;

  sven.aspects.box = {
    at = sven.host.box;
    nixos = {
      boot.loader.grub.device = "nodev";
      fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
}
